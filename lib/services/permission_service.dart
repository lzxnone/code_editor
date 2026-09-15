import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 文件存储权限管理服务
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  static const String _keyBatteryOptimizationPrompted = 'battery_optimization_prompted';

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

  /// 检查电池优化状态（是否已忽略后台电池优化）。
  /// 若未关闭后台优化且尚未提示过，弹出提示对话框引导前往设置。
  /// [forcePrompt] 为 true 时忽略已提示过的记录强制检查。
  /// 返回 true 表示用户点击了“去设置”并触发了跳转；
  /// 返回 false 表示无需配置或用户点击了“取消”或已提示过。
  Future<bool> promptBatteryOptimizationIfNeeded(
    BuildContext context, {
    bool forcePrompt = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPrompted = prefs.getBool(_keyBatteryOptimizationPrompted) ?? false;
      if (!forcePrompt && hasPrompted) {
        return false;
      }

      final isIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
      if (isIgnored) return false;

      if (!context.mounted) return false;
      final l10n = AppLocalizations.of(context);
      final title = l10n?.batteryOptimizationTitle ?? '后台运行与电池优化';
      final message = l10n?.batteryOptimizationMessage ??
          '为了保证终端会话在后台不被系统强行终止，建议将本应用的电池优化设置为“无限制”或关闭电池优化。\n\n是否前往系统设置进行配置？';
      final confirmText = l10n?.goToSettings ?? '去设置';
      final cancelText = l10n?.cancel ?? '取消';

      final shouldGoToSettings = await DialogUtils.showConfirmDialog(
        context,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: const Icon(Icons.battery_alert_outlined, size: 28),
      );

      // 用户选择“去设置”或“取消”后，记录已提示，避免每次进入终端重复弹窗
      await prefs.setBool(_keyBatteryOptimizationPrompted, true);

      if (shouldGoToSettings) {
        final status = await Permission.ignoreBatteryOptimizations.request();
        if (!status.isGranted) {
          await openAppSettings();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('电池优化检测发生异常: $e');
      return false;
    }
  }

  /// 重置电池优化提示状态（供设置界面重新触发检测使用）
  Future<void> resetBatteryOptimizationPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBatteryOptimizationPrompted);
    } catch (_) {}
  }
}
