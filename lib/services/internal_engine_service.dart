import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/distro_manifest.dart';
import '../providers/terminal_provider.dart';
import '../widgets/distro_extract_dialog.dart';
import 'distro_installer.dart';
import 'distro_manager.dart';
import 'lsp/lsp_manager.dart';
import 'toolchain_service.dart';

/// 代码智能与运行时引擎服务（基于统一主系统 Ubuntu 24.04）
class InternalEngineService extends ChangeNotifier {
  static final InternalEngineService instance = InternalEngineService._();
  InternalEngineService._();

  /// 测试自定义引擎根目录
  @visibleForTesting
  Directory? customEngineDir;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// 获取主系统 Ubuntu rootfs 目录
  Future<Directory> getRootfsDir() async {
    if (customEngineDir != null) {
      return customEngineDir!;
    }
    return DistroManager().getSystemRootDir(DistroRepository.defaultSystemName);
  }

  /// 兼容旧方法命名
  Future<Directory> getEngineDir() => getRootfsDir();

  /// 检查主系统 Ubuntu 是否已完整安装
  Future<bool> isEngineInstalled() async {
    try {
      if (customEngineDir != null) {
        final marker = File(p.join(customEngineDir!.path, '.installed'));
        if (marker.existsSync()) return true;
        final binDir = Directory(p.join(customEngineDir!.path, 'bin'));
        final etcDir = Directory(p.join(customEngineDir!.path, 'etc'));
        return binDir.existsSync() && etcDir.existsSync();
      }

      return await DistroManager().isSystemInstalled(DistroRepository.defaultSystemName);
    } catch (e) {
      debugPrint('检查代码智能运行引擎异常: $e');
      return false;
    }
  }

  /// 确保内置 Ubuntu 引擎已准备完毕；若未安装，弹出模态解压弹窗进行解压
  Future<bool> ensureEngineReady(BuildContext context) async {
    if (await isEngineInstalled()) {
      return true;
    }

    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context);

    _isChecking = true;
    notifyListeners();

    try {
      final success = await DistroExtractDialog.show(
        context: context,
        systemName: l10n?.internalEngineTitle ?? '代码运行与智能补全引擎 (Ubuntu)',
        task: (onProgress, isCancelled) async {
          await extractEngine(
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        },
      );

      _isChecking = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      debugPrint('解压 Ubuntu 引擎失败: $e');
      return false;
    }
  }

  /// 彻底销毁并重建内置 Ubuntu 容器
  Future<bool> rebuildEngine(BuildContext context) async {
    _isChecking = true;
    notifyListeners();

    TerminalProvider? terminalProvider;
    try {
      terminalProvider = Provider.of<TerminalProvider>(context, listen: false);
    } catch (_) {}

    try {
      // 1. 关闭所有运行中的后台语言服务会话
      await LspManager.instance.disposeAll();

      // 2. 清理终端中属于 ubuntu 的活跃会话
      terminalProvider?.removeSessionsForDistro(DistroRepository.defaultSystemName);

      // 3. 保护 .l2s 目录，避免外部工程中已建立的 PRoot 硬链接替身文件随容器重装被误删
      Directory? preservedL2s;
      try {
        final currentRootfs = await DistroManager().getSystemRootDir(DistroRepository.defaultSystemName);
        final oldL2s = Directory(p.join(currentRootfs.path, '.l2s'));
        if (oldL2s.existsSync()) {
          final tempDir = await getTemporaryDirectory();
          final backupDir = Directory(p.join(tempDir.path, 'preserved_l2s_${DateTime.now().millisecondsSinceEpoch}'));
          backupDir.createSync(recursive: true);
          final entries = oldL2s.listSync();
          for (final entry in entries) {
            if (entry is File) {
              entry.copySync(p.join(backupDir.path, p.basename(entry.path)));
            }
          }
          preservedL2s = backupDir;
        }
      } catch (e) {
        debugPrint('备份 .l2s 异常 (非阻塞): $e');
      }

      // 彻底删除 ubuntu 容器目录
      if (customEngineDir != null) {
        if (customEngineDir!.existsSync()) {
          customEngineDir!.deleteSync(recursive: true);
        }
      } else {
        await DistroManager().deleteSystem(DistroRepository.defaultSystemName);
      }

      if (!context.mounted) {
        _isChecking = false;
        notifyListeners();
        return false;
      }

      final l10n = AppLocalizations.of(context);

      // 4. 唤起解压弹窗重新从内置资源解压 Ubuntu
      final success = await DistroExtractDialog.show(
        context: context,
        systemName: l10n?.internalEngineTitle ?? '代码运行与智能补全引擎 (Ubuntu)',
        task: (onProgress, isCancelled) async {
          await extractEngine(
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        },
      );

      // 5. 还原被保护的 .l2s 替身目录到新解压的容器中
      if (success && preservedL2s != null && preservedL2s.existsSync()) {
        try {
          final newRootfs = await DistroManager().getSystemRootDir(DistroRepository.defaultSystemName);
          final newL2s = Directory(p.join(newRootfs.path, '.l2s'));
          if (!newL2s.existsSync()) {
            newL2s.createSync(recursive: true);
          }
          for (final entity in preservedL2s.listSync()) {
            if (entity is File) {
              final target = p.join(newL2s.path, p.basename(entity.path));
              if (!File(target).existsSync()) {
                entity.copySync(target);
              }
            }
          }
          preservedL2s.deleteSync(recursive: true);
          debugPrint('成功恢复 .l2s 替身目录到新容器');
        } catch (e) {
          debugPrint('恢复 .l2s 目录异常: $e');
        }
      }

      _isChecking = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      debugPrint('重建 Ubuntu 引擎失败: $e');
      return false;
    }
  }

  /// 解压 Asset 中的 Ubuntu 到主系统目录
  Future<void> extractEngine({
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (customEngineDir != null) {
      // 测试模式下解压或标记
      final marker = File(p.join(customEngineDir!.path, '.installed'));
      await marker.writeAsString('ready');
      return;
    }

    await DistroManager().importBuiltinUbuntu(
      systemName: DistroRepository.defaultSystemName,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// 检查某命令（如 clangd, rust-analyzer, pylsp）是否在系统已安装
  Future<bool> isCommandInstalled(String command) async {
    if (!await isEngineInstalled() || command.trim().isEmpty) {
      return false;
    }

    try {
      final rootfs = await getRootfsDir();
      final res = await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: 'command -v ${command.trim()} >/dev/null 2>&1 && echo CE_OK',
        timeout: const Duration(seconds: 15),
      );
      return res?.stdout.toString().contains('CE_OK') ?? false;
    } catch (e) {
      debugPrint('检查引擎命令异常: $e');
      return false;
    }
  }

  /// 在 Ubuntu 系统中安装指定 apt 软件包
  Future<bool> installPackage(
    String packageName, {
    void Function(String chunk)? onOutput,
  }) async {
    if (!await isEngineInstalled() || packageName.trim().isEmpty) {
      return false;
    }

    try {
      final rootfs = await getRootfsDir();
      final installCmd =
          '${ToolchainService.dpkgAutoHealPrefix} '
          'apt-get update && '
          'apt-get install -y --no-install-recommends ${packageName.trim()}';

      final res = await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: installCmd,
        timeout: const Duration(minutes: 10),
        onStdout: onOutput,
      );
      return res != null && res.exitCode == 0;
    } catch (e) {
      debugPrint('安装引擎软件包异常: $e');
      return false;
    }
  }

  /// 自动诊断与修复 dpkg 锁及半安装 (reinstreq/half-installed) 死锁状态
  Future<bool> repairDpkgStatus({void Function(String chunk)? onOutput}) async {
    if (!await isEngineInstalled()) return false;
    try {
      final rootfs = await getRootfsDir();
      final repairCmd =
          '${ToolchainService.dpkgAutoHealPrefix} '
          'apt-get update && '
          'apt-get -f install -y 2>/dev/null || true;';

      final res = await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: repairCmd,
        timeout: const Duration(minutes: 3),
        onStdout: onOutput,
      );
      return res != null && res.exitCode == 0;
    } catch (e) {
      debugPrint('修复 dpkg 状态异常: $e');
      return false;
    }
  }

  /// 在 Ubuntu 系统中彻底卸载指定 apt 软件包及清理对应命令
  Future<bool> uninstallPackage(
    String packageName, {
    String? serverCommand,
    void Function(String chunk)? onOutput,
  }) async {
    final cleanPkg = packageName.trim();
    if (!await isEngineInstalled() || cleanPkg.isEmpty) {
      return false;
    }

    try {
      final rootfs = await getRootfsDir();
      final cleanCmd = serverCommand?.trim();

      // 1. 若指定了服务命令，先在容器内强杀残留进程，避免文件占用导致卸载失败
      final killSection = (cleanCmd != null && cleanCmd.isNotEmpty)
          ? 'pkill -9 -f "$cleanCmd" 2>/dev/null || true; '
          : '';

      // 2. 针对特定虚包/版本衍生包进行包名扩展 purge
      // 例如 clangd 会衍生出 clangd-15, clang-tools-15 等
      final String targetsToPurge;
      if (cleanPkg == 'clangd') {
        targetsToPurge = 'clangd clangd* clang-tools*';
      } else {
        targetsToPurge = cleanPkg;
      }

      // 3. 二次兜底检测：如果命令仍残留，尝试通过 dpkg -S 查询实际宿主包并 purge，或清理残留可执行文件
      final cmdCleanupSection = (cleanCmd != null && cleanCmd.isNotEmpty)
          ? '''
BIN_PATH=\$(command -v "$cleanCmd" 2>/dev/null || true)
if [ -n "\$BIN_PATH" ]; then
  OWNER_PKG=\$(dpkg -S "\$BIN_PATH" 2>/dev/null | cut -d: -f1 | head -n 1 || true)
  if [ -n "\$OWNER_PKG" ]; then
    apt-get remove --purge -y "\$OWNER_PKG" 2>/dev/null || true
  fi
  rm -f "\$BIN_PATH" 2>/dev/null || true
fi
'''
          : '';

      final uninstallCmd = '''
${ToolchainService.dpkgAutoHealPrefix}
$killSection
apt-get remove --purge -y $targetsToPurge
apt-get autoremove --purge -y
$cmdCleanupSection
''';

      final res = await DistroManager().runHeadlessCommand(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        command: uninstallCmd,
        timeout: const Duration(minutes: 5),
        onStdout: onOutput,
      );

      final success = res != null && res.exitCode == 0;
      if (!success) {
        return false;
      }

      // 4. 若提供了 serverCommand，确凿验证该命令在系统中是否已不存在
      if (cleanCmd != null && cleanCmd.isNotEmpty) {
        final stillExists = await isCommandInstalled(cleanCmd);
        if (stillExists) {
          debugPrint('[InternalEngineService] 警告: 卸载脚本完成后命令 $cleanCmd 仍残留');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('卸载引擎软件包异常: $e');
      return false;
    }
  }
}
