import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

/// 设备 Root 权限探测与授权管理服务
class RootService {
  static final RootService instance = RootService._();
  RootService._();

  /// 测试桩：用于单测中模拟设备是否具备 Root 能力
  @visibleForTesting
  bool? mockRootCapable;

  /// 测试桩：用于单测中模拟 Root 授权状态
  @visibleForTesting
  bool? mockRootGranted;

  /// 常见 Linux/Android su 二进制搜索路径（包含现代 KernelSU / APatch / Magisk 扩展路径）
  static const List<String> _commonSuPaths = [
    '/system/bin/su',
    '/system/xbin/su',
    '/sbin/su',
    '/system/xbin/daemonsu',
    '/su/bin/su',
    '/system/sd/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/data/adb/ksu/bin/su',
    '/data/adb/ap/bin/su',
    '/data/adb/magisk/su',
    '/data/adb/magisk/busybox',
    '/apex/com.android.runtime/bin/su',
    '/system_ext/bin/su',
    '/product/bin/su',
    '/odm/bin/su',
    '/vendor/bin/su',
    '/system/bin/.ext/.su',
    '/system/usr/we-need-root/su',
    '/system/xbin/ku.sud',
  ];

  /// 常见现代 Root 框架特征目录 (KernelSU / APatch / Magisk)
  static const List<String> _commonRootIndicatorDirs = [
    '/data/adb/ksu',
    '/data/adb/ap',
    '/data/adb/magisk',
    '/data/adb/modules',
  ];

  /// 静态检测当前设备是否具备 Root 能力（文件系统存在 su 二进制或现代 Root 管理器特征）
  ///
  /// 该方法纯粹检查静态文件路径与环境变量，绝不调用外部进程命令，因此不会触发授权弹窗。
  bool isDeviceRootCapable() {
    if (mockRootCapable != null) {
      return mockRootCapable!;
    }

    if (!kIsWeb && Platform.isAndroid) {
      // 1. 遍历已知 su 二进制路径
      for (final path in _commonSuPaths) {
        try {
          if (File(path).existsSync()) {
            return true;
          }
        } catch (_) {}
      }

      // 2. 遍历 PATH 环境变量中的所有目录进行动态检索
      final pathEnv = Platform.environment['PATH'];
      if (pathEnv != null && pathEnv.isNotEmpty) {
        final dirs = pathEnv.split(':');
        for (final dir in dirs) {
          if (dir.isEmpty) continue;
          try {
            if (File('$dir/su').existsSync()) {
              return true;
            }
          } catch (_) {}
        }
      }

      // 3. 探测现代 Root 框架特征目录 (KernelSU / APatch / Magisk)
      for (final dir in _commonRootIndicatorDirs) {
        try {
          if (Directory(dir).existsSync()) {
            return true;
          }
        } catch (_) {}
      }
    }

    return false;
  }

  /// 全局入口单次防打扰 Root 授权申请
  ///
  /// 规则：
  /// 1. 如果设备本身没有 Root 能力，完全不申请权限；
  /// 2. 如果具备 Root 能力，仅在首次启动时主动执行一次 `su` 触发系统授权弹窗；
  /// 3. 记录标记 `hasPromptedRootRequest = true`，无论用户同意还是拒绝，之后永不再主动弹出。
  Future<bool> requestRootPermissionOnce(SettingsProvider settings) async {
    if (settings.hasPromptedRootRequest) {
      return false;
    }

    if (!isDeviceRootCapable()) {
      await settings.setHasPromptedRootRequest(true);
      return false;
    }

    // 标记为已主动申请过，防止后续反复打扰
    await settings.setHasPromptedRootRequest(true);

    // 触发单次授权探测
    return await isRootAvailablePassive();
  }

  /// 被动检测当前是否已获得真实 Root 权限 (uid=0)
  ///
  /// 直接执行最小命令探针 `su -c 'id -u'`，不受静态文件可见性（Root 隐藏/SELinux 隔离）限制。
  Future<bool> isRootAvailablePassive({Duration timeout = const Duration(seconds: 4)}) async {
    if (mockRootGranted != null) {
      return mockRootGranted!;
    }

    try {
      final result = await Process.run(
        'su',
        ['-c', 'id -u'],
      ).timeout(timeout);

      if (result.exitCode == 0) {
        final out = result.stdout.toString().trim();
        return out == '0';
      }
    } catch (e) {
      debugPrint('[RootService] 被动 Root 检查失败: $e');
    }

    return false;
  }

  /// 显式尝试申请 Root 权限（执行一次 `su` 唤起系统的授权 dialog）
  Future<bool> promptRequestRootExplicit({Duration timeout = const Duration(seconds: 8)}) async {
    return await isRootAvailablePassive(timeout: timeout);
  }
}
