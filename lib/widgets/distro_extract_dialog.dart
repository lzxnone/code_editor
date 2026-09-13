import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/services/distro_installer.dart';
import 'package:code_editor/utils/dialog_utils.dart';
import 'package:flutter/material.dart';

/// 同步前台解压进度弹窗（模态不可遮罩忽略，关闭或取消直接导致导入失败并回滚）
class DistroExtractDialog extends StatefulWidget {
  final String systemName;
  final Future<void> Function(InstallProgressCallback onProgress, bool Function() isCancelled) task;

  const DistroExtractDialog({
    super.key,
    required this.systemName,
    required this.task,
  });

  /// 快速拉起解压进程模态弹窗
  /// 返回 true 表示导入成功，false 表示取消或失败
  static Future<bool> show({
    required BuildContext context,
    required String systemName,
    required Future<void> Function(InstallProgressCallback onProgress, bool Function() isCancelled) task,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DistroExtractDialog(
        systemName: systemName,
        task: task,
      ),
    );
    return result ?? false;
  }

  @override
  State<DistroExtractDialog> createState() => _DistroExtractDialogState();
}

class _DistroExtractDialogState extends State<DistroExtractDialog> {
  double _progress = 0.0;
  String? _message;
  bool _isCancelled = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _startTask();
  }

  Future<void> _startTask() async {
    try {
      await widget.task(
        (prog, msg) {
          if (mounted && !_isCancelled) {
            setState(() {
              _progress = prog;
              _message = msg;
            });
          }
        },
        () => _isCancelled,
      );

      if (mounted && !_isCancelled) {
        _isFinished = true;
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (e is DistroInstallCancelledException || _isCancelled) {
          DialogUtils.showToast(context, l10n.cancelledImportSystem(widget.systemName));
        } else {
          DialogUtils.showErrorToast(context, l10n.importFailed(e.toString()));
        }
        Navigator.of(context).pop(false);
      }
    }
  }

  void _handleCancel() {
    if (_isFinished) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isCancelled = true;
      _message = l10n.cancellingAndCleaning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final percentInt = (_progress * 100).clamp(0, 100).toInt();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleCancel();
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Row(
          children: [
            const Icon(Icons.archive_outlined, size: 22, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.importingSystemTitle(widget.systemName),
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _message ?? l10n.preparingInitialization,
              style: TextStyle(
                fontSize: 13.0,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$percentInt%',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isCancelled ? null : _handleCancel,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(_isCancelled ? l10n.interrupting : l10n.cancelImport),
          ),
        ],
      ),
    );
  }
}
