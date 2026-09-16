import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/distro_manifest.dart';
import '../widgets/distro_extract_dialog.dart';
import 'distro_installer.dart';
import 'distro_manager.dart';

/// 内部私有代码智能引擎服务 (files/internal_engine/alpine)
class InternalEngineService extends ChangeNotifier {
  static final InternalEngineService instance = InternalEngineService._();
  InternalEngineService._();

  /// 测试自定义引擎根目录
  @visibleForTesting
  Directory? customEngineDir;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  /// 获取引擎主目录: `<files>/internal_engine/alpine`
  Future<Directory> getEngineDir() async {
    if (customEngineDir != null) {
      return customEngineDir!;
    }
    final appDir = await getApplicationSupportDirectory();
    final rootPath = p.basename(appDir.path) == 'files'
        ? appDir.path
        : p.join(appDir.path, 'files');
    final engineDir = Directory(p.join(rootPath, 'internal_engine', 'alpine'));
    if (!engineDir.existsSync()) {
      engineDir.createSync(recursive: true);
    }
    return engineDir;
  }

  /// 获取 rootfs 目录: `<files>/internal_engine/alpine/rootfs`
  Future<Directory> getRootfsDir() async {
    final engineDir = await getEngineDir();
    return Directory(p.join(engineDir.path, 'rootfs'));
  }

  /// 检查内置 Alpine 引擎是否已完整安装
  Future<bool> isEngineInstalled() async {
    try {
      final engineDir = await getEngineDir();
      final marker = File(p.join(engineDir.path, '.installed'));
      if (!marker.existsSync()) return false;

      final rootfs = await getRootfsDir();
      if (!rootfs.existsSync()) return false;

      final binDir = Directory(p.join(rootfs.path, 'bin'));
      final etcDir = Directory(p.join(rootfs.path, 'etc'));
      return binDir.existsSync() && etcDir.existsSync();
    } catch (e) {
      debugPrint('检查内置引擎异常: $e');
      return false;
    }
  }

  /// 确保内置引擎已准备完毕；若未安装，弹出模态解压弹窗进行解压
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
        systemName: l10n?.internalEngineTitle ?? '内部代码智能引擎 (Alpine)',
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
      debugPrint('解压内部引擎失败: $e');
      return false;
    }
  }

  /// 解压 Asset 中的 Alpine minirootfs 到私有引擎目录
  Future<void> extractEngine({
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final assetPath = DistroRepository.builtinAlpineAssetPath;
    onProgress?.call(0.02, '正在读取应用内置 Alpine 系统资源包...');

    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final rootfsDir = await getRootfsDir();
    if (!rootfsDir.existsSync()) {
      rootfsDir.createSync(recursive: true);
    }

    await DistroInstaller.installFromBytes(
      tarGzBytes: bytes,
      targetDir: rootfsDir,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    // 写入安装完成标记文件
    final engineDir = await getEngineDir();
    final marker = File(p.join(engineDir.path, '.installed'));
    await marker.writeAsString('ready');
  }

  /// 检查某命令（如 clangd, rust-analyzer）是否在内置 Alpine 中已安装
  Future<bool> isCommandInstalled(String command) async {
    if (!await isEngineInstalled() || command.trim().isEmpty) {
      return false;
    }

    try {
      final rootfs = await getRootfsDir();
      final res = await DistroManager().runHeadlessCommand(
        systemName: 'alpine_internal',
        customRootDir: rootfs,
        command: 'command -v ${command.trim()} >/dev/null 2>&1 && echo CE_OK',
        timeout: const Duration(seconds: 15),
      );
      return res?.stdout.toString().contains('CE_OK') ?? false;
    } catch (e) {
      debugPrint('检查内置引擎命令异常: $e');
      return false;
    }
  }

  /// 在内置 Alpine 中安装指定 apk 软件包
  Future<bool> installPackage(
    String apkPackage, {
    void Function(String chunk)? onOutput,
  }) async {
    if (!await isEngineInstalled() || apkPackage.trim().isEmpty) {
      return false;
    }

    try {
      final rootfs = await getRootfsDir();
      final res = await DistroManager().runHeadlessCommand(
        systemName: 'alpine_internal',
        customRootDir: rootfs,
        command: 'apk add --no-cache ${apkPackage.trim()}',
        timeout: const Duration(minutes: 5),
        onStdout: onOutput,
      );
      return res != null && res.exitCode == 0;
    } catch (e) {
      debugPrint('安装内置引擎软件包异常: $e');
      return false;
    }
  }
}
