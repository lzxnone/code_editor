import 'package:code_editor/models/file_directory_history.dart';
import 'package:code_editor/services/file_directory_history_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileDirectoryHistoryWidget extends StatefulWidget {
  final ValueChanged<FileDirectoryHistory>? onSelectHistory;

  const FileDirectoryHistoryWidget({
    super.key,
    this.onSelectHistory,
  });

  /// 打开历史弹窗（不关闭后方的 Drawer）
  static Future<void> show(
    BuildContext context, {
    ValueChanged<FileDirectoryHistory>? onSelectHistory,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return FileDirectoryHistoryWidget(
          onSelectHistory: onSelectHistory,
        );
      },
    );
  }

  @override
  State<FileDirectoryHistoryWidget> createState() =>
      _FileDirectoryHistoryWidgetState();
}

class _FileDirectoryHistoryWidgetState
    extends State<FileDirectoryHistoryWidget> {
  List<FileDirectoryHistory> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await FileDirectoryHistoryService.instance.getFullHistory();
    if (mounted) {
      setState(() {
        _historyList = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteHistory(FileDirectoryHistory item) async {
    final root = item.rootPath;
    if (root != null && root.isNotEmpty) {
      await FileDirectoryHistoryService.instance.removeHistory(root);
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          maxHeight: 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Title 区域：加粗、与 AppBar 相同背景颜色、右上角 X 关闭
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: theme.colorScheme.primaryContainer,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '历史文件目录',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    tooltip: '关闭',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. 列表区域
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _historyList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              '暂无历史记录',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: _historyList.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final item = _historyList[index];
                            final lastFile = item.lastOpenedFilePath;
                            final fileName = (lastFile != null &&
                                    lastFile.trim().isNotEmpty)
                                ? p.basename(lastFile)
                                : '未打开文件';
                            final rootDir = item.rootPath ?? '未知目录';

                            return InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelectHistory?.call(item);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    // 左边：历史图标
                                    Icon(
                                      Icons.history,
                                      size: 24,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),

                                    // 中间：撑开，占据最大空间，两行字
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 上面：大的上一次打开的文件名称
                                          Text(
                                            fileName,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          // 下面：一行小字表示根目录
                                          Text(
                                            rootDir,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 右边：删除历史记录的图标，点击后删除
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: theme.colorScheme.error,
                                      ),
                                      tooltip: '删除此记录',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteHistory(item),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}