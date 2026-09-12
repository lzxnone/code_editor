import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件存储权限管理服务
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  /// 检查并确保拥有存储/工作区访问权限
  ///
  /// 如果未授权且传入了 [context]，会弹出友好说明对话框，引导用户前往系统设置开启“所有文件访问权限”。
  /// 返回 true 表示已获授权或无需该权限（非 Android 平台），false 表示用户拒绝或未授权。
  Future<bool> ensureStoragePermission({BuildContext? context}) async {
    // 桌面端（Windows / macOS / Linux）与 Web 端不需要此类移动端运行时权限
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    try {
      // 1. 优先检查并请求 Android 11+ (API 30+) 的管理所有文件权限
      var manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) {
        return true;
      }

      // 如果尚未请求过，直接发起系统级请求
      if (!manageStatus.isPermanentlyDenied) {
        manageStatus = await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          return true;
        }
      }

      // 2. 兼容 Android 10 及以下：检查普通 storage 权限
      var storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }
      if (!storageStatus.isPermanentlyDenied) {
        storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          return true;
        }
      }

      // 3. 用户拒绝或处于需要跳转设置的状态，如果有 context 则弹出引导弹窗
      if (context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        final title = l10n?.storagePermissionRequiredTitle ?? '需要存储访问权限';
        final message = l10n?.storagePermissionRequiredMessage ??
            '代码编辑器需要“管理所有文件”权限，以便在您的设备上读取、新建和保存项目文件。\n\n请在接下来的系统设置页面中开启该权限。';
        final confirmText = l10n?.goToSettings ?? '去设置';
        final cancelText = l10n?.cancel ?? '取消';

        final shouldOpenSettings = await DialogUtils.showConfirmDialog(
          context,
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          icon: const Icon(Icons.folder_special_outlined, size: 28),
        );

        if (shouldOpenSettings) {
          await openAppSettings();
        }
      }

      // 再次确认一次权限状态
      final recheck = await Permission.manageExternalStorage.status;
      return recheck.isGranted;
    } catch (e) {
      debugPrint('权限检测发生异常: $e');
      return false;
    }
  }

  /// 快速同步检查是否已经拥有管理所有文件权限（不弹窗）
  Future<bool> hasStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      return false;
    } catch (_) {
      return false;
    }
  }
}
