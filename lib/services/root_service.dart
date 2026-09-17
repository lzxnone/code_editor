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

  /// 常见 Linux/Android su 二进制搜索路径
  static const List<String> _commonSuPaths = [
    '/system/bin/su',
    '/system/xbin/su',
    '/sbin/su',
    '/system/xbin/daemonsu',
    '/su/bin/su',
    '/system/sd/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
  ];

  /// 静态检测当前设备是否具备 Root 能力（文件系统存在 su 二进制）
  ///
  /// 该方法纯粹检查静态文件路径，绝不调用任何命令，因此绝对不会触发 Magisk / KernelSU / APatch 授权弹窗。
  bool isDeviceRootCapable() {
    if (mockRootCapable != null) {
      return mockRootCapable!;
    }

    if (!kIsWeb && Platform.isAndroid) {
      for (final path in _commonSuPaths) {
        try {
          if (File(path).existsSync()) {
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
  /// 仅在用户主动触发 Chroot 操作、或 Auto 模式下准备启动容器时被动调用。
  Future<bool> isRootAvailablePassive({Duration timeout = const Duration(seconds: 4)}) async {
    if (mockRootGranted != null) {
      return mockRootGranted!;
    }

    if (!isDeviceRootCapable()) {
      return false;
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
