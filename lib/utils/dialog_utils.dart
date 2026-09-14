import 'package:code_editor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Toast 类型
enum ToastType {
  info,
  success,
  warning,
  error,
}

/// 保存未保存更改提示结果
enum SavePromptResult {
  save,
  discard,
  cancel,
}

/// 外部文件冲突提示结果
enum FileConflictResult {
  reloadFromDisk,
  keepLocal,
}

/// 集中封装 Dialog 与 Toast 的工具类
class DialogUtils {
  DialogUtils._();

  static OverlayEntry? _currentToastEntry;

  /// 显示浮动 Toast（自动避开软键盘及底部安全区）
  static void showToast(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (_currentToastEntry != null && _currentToastEntry!.mounted) {
      _currentToastEntry!.remove();
      _currentToastEntry = null;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 根据类型配置图标与色彩
    final (iconData, bgColor, textColor, borderColor) = switch (type) {
      ToastType.success => (
        Icons.check_circle_outline,
        Colors.green.shade800,
        Colors.white,
        Colors.green.shade600,
      ),
      ToastType.error => (
        Icons.error_outline,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        colorScheme.error,
      ),
      ToastType.warning => (
        Icons.warning_amber_rounded,
        Colors.amber.shade900,
        Colors.white,
        Colors.amber.shade700,
      ),
      ToastType.info => (
        Icons.info_outline,
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
        colorScheme.outlineVariant,
      ),
    };

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        iconData: iconData,
        bgColor: bgColor,
        textColor: textColor,
        borderColor: borderColor,
        duration: duration,
        onDismissed: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (_currentToastEntry == entry) {
            _currentToastEntry = null;
          }
        },
      ),
    );

    _currentToastEntry = entry;
    overlay.insert(entry);
  }

  static void showSuccessToast(BuildContext context, String message) {
    showToast(context, message, type: ToastType.success);
  }

  static void showErrorToast(BuildContext context, String message) {
    showToast(context, message, type: ToastType.error);
  }

  static void showWarningToast(BuildContext context, String message) {
    showToast(context, message, type: ToastType.warning);
  }

  static void showInfoToast(BuildContext context, String message) {
    showToast(context, message, type: ToastType.info);
  }

  // ==========================================
  // 2. 消息提示 Dialog (Info, Warning, Error)
  // ==========================================

  /// 信息提示弹窗 (Info)
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return _showMessageDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText ?? l10n?.confirm ?? '确定',
      icon: Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 28),
    );
  }

  /// 警告提示弹窗 (Warning)
  static Future<void> showWarningDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
  }) {
    final l10n = AppLocalizations.of(context);
    return _showMessageDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText ?? l10n?.gotIt ?? '知道了',
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
    );
  }

  /// 错误提示弹窗 (Error)
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return _showMessageDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText ?? l10n?.close ?? '关闭',
      icon: Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
    );
  }

  static Future<void> _showMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required Widget icon,
  }) {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          icon: icon,
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 同步居中转圈弹窗（任务执行过程中锁定，任务结束后自动 pop 关闭）
  static Future<T> showSyncLoadingDialog<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() task,
  }) async {
    final theme = Theme.of(context);
    bool dialogPopped = false;

    // 弹出不可取消的居中转圈模态框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1.0,
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      dialogPopped = true;
    });

    try {
      final result = await task();
      return result;
    } finally {
      if (!dialogPopped && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  // ==========================================
  // 3. 确认弹窗 (普通确认 vs 特殊/高危确认)
  // ==========================================

  /// 普通确认弹窗 (如：保存提示、重新载入等常规操作)
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Widget? icon,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effConfirmText = confirmText ?? l10n?.confirm ?? '确定';
    final effCancelText = cancelText ?? l10n?.cancel ?? '取消';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          icon: icon,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(effCancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(effConfirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 特殊/高危确认弹窗 (如：删除文件、清空历史等不可逆操作)
  static Future<bool> showDestructiveConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    IconData icon = Icons.delete_outline,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effConfirmText = confirmText ?? l10n?.delete ?? '删除';
    final effCancelText = cancelText ?? l10n?.cancel ?? '取消';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          icon: Icon(icon, color: theme.colorScheme.error, size: 28),
          title: Text(
            title,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(effCancelText),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(effConfirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 未保存更改提示弹窗 (保存、不保存、取消)
  static Future<SavePromptResult> showSavePromptDialog(
    BuildContext context, {
    required String fileName,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = l10n?.saveChangesTitle ?? '保存更改';
    final message = l10n?.saveChangesMessage(fileName) ?? '文件 "$fileName" 已被修改，是否保存更改？';
    final saveText = l10n?.save ?? '保存';
    final dontSaveText = l10n?.dontSave ?? '不保存';
    final cancelText = l10n?.cancel ?? '取消';

    final result = await showDialog<SavePromptResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          icon: Icon(
            Icons.help_outline,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(SavePromptResult.cancel),
              child: Text(cancelText),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(SavePromptResult.discard),
              child: Text(dontSaveText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(SavePromptResult.save),
              child: Text(saveText),
            ),
          ],
        );
      },
    );

    return result ?? SavePromptResult.cancel;
  }

  /// 未保存所有更改提示弹窗 (保存所有、不保存、取消)
  static Future<SavePromptResult> showSaveAllPromptDialog(
    BuildContext context,
  ) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = l10n?.saveAllPromptTitle ?? '保存所有更改？';
    final message = l10n?.saveAllPromptMessage ?? '当前项目中有未保存的修改，是否保存所有文件？';
    final saveText = l10n?.saveAll ?? '保存所有';
    final dontSaveText = l10n?.dontSave ?? '不保存';
    final cancelText = l10n?.cancel ?? '取消';

    final result = await showDialog<SavePromptResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          icon: Icon(
            Icons.help_outline,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(SavePromptResult.cancel),
              child: Text(cancelText),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(SavePromptResult.discard),
              child: Text(dontSaveText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(SavePromptResult.save),
              child: Text(saveText),
            ),
          ],
        );
      },
    );

    return result ?? SavePromptResult.cancel;
  }

  /// 外部文件冲突提示弹窗 (用磁盘内容覆盖、保留本地修改)
  static Future<FileConflictResult> showFileConflictDialog(
    BuildContext context, {
    required String fileName,
  }) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = l10n?.fileConflictTitle ?? '外部文件已被更改';
    final message = l10n?.fileConflictMessage(fileName) ?? '文件 "$fileName" 已在外部被更改。您希望如何处理？';
    final reloadText = l10n?.reloadFromDisk ?? '用磁盘内容覆盖';
    final keepText = l10n?.keepLocal ?? '保留本地修改';

    final result = await showDialog<FileConflictResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade800,
            size: 28,
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(FileConflictResult.keepLocal),
              child: Text(keepText),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(FileConflictResult.reloadFromDisk),
              child: Text(reloadText),
            ),
          ],
        );
      },
    );

    return result ?? FileConflictResult.keepLocal;
  }

  // ==========================================
  // 4. 输入弹窗 (Input Dialog)
  // ==========================================

  /// 通用文本输入弹窗，返回用户输入的内容；若取消或关闭则返回 null
  static Future<String?> showInputDialog(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effConfirmText = confirmText ?? l10n?.confirm ?? '确定';
    final effCancelText = cancelText ?? l10n?.cancel ?? '取消';

    // 默认校验：不可为空且不能包含常见系统非法字符
    String? defaultValidator(String? val) {
      if (val == null || val.trim().isEmpty) {
        return l10n?.nameCannotBeEmpty ?? '名称不能为空';
      }
      if (val.contains(RegExp(r'[\\/:*?"<>|]'))) {
        return l10n?.nameInvalidChars ?? '名称不能包含非法字符 (\\/:*?"<>|)';
      }
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
              validator: validator ?? defaultValidator,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(effCancelText),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text);
                }
              },
              child: Text(effConfirmText),
            ),
          ],
        );
      },
    );
  }
}

/// 视口感知与软键盘避让的动画 Toast 悬浮组件
class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData iconData;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onDismissed;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.iconData,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.onDismissed,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismissed();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final paddingBottom = mediaQuery.padding.bottom;

    // 动态适配视口：
    // 若系统键盘唤起（viewInsets.bottom > 0），则浮动于键盘与辅助小键盘上方（viewInsets.bottom + 72）
    // 若无键盘，则浮动于屏幕安全区上方（paddingBottom + 48）
    final bottomOffset = viewInsetsBottom > 0
        ? viewInsetsBottom + 72.0
        : paddingBottom + 48.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: bottomOffset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.borderColor, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.iconData, size: 18, color: widget.textColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

