import 'dart:math' as math;
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

class CodeEditorTabBar extends StatelessWidget {
  const CodeEditorTabBar({super.key});

  static TabProvider _getTabProvider(BuildContext context, {bool listen = true}) {
    return listen ? context.watch<TabProvider>() : context.read<TabProvider>();
  }

  static ProjectProvider? _getProjectProvider(BuildContext context, {bool listen = true}) {
    try {
      return listen ? context.watch<ProjectProvider>() : context.read<ProjectProvider>();
    } catch (_) {
      return null;
    }
  }

  double _calculateTabNaturalWidth(
    BuildContext context, {
    required String displayName,
    required bool isModified,
  }) {
    final textScaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final theme = Theme.of(context);
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamilyFallback: theme.textTheme.bodyMedium?.fontFamilyFallback,
        ),
      ),
      textScaler: textScaler,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    // 实际所需完整宽度（向上取整避免浮点精度缺失）：
    // 文本宽度 + 脏标记 (10.0) + 内外间距与关闭按钮 (26.0) + 安全缓冲空间 (10.0)
    final textWidth = textPainter.width.ceilToDouble();
    final dirtyWidth = isModified ? 10.0 : 0.0;
    const fixedElementsWidth = 26.0; // 容器内边距(8) + 关闭按钮(18)
    const safetyBuffer = 10.0;       // 安全呼吸空间

    return textWidth + dirtyWidth + fixedElementsWidth + safetyBuffer;
  }

  @override
  Widget build(BuildContext context) {
    final tabProvider = _getTabProvider(context);
    final projectProvider = _getProjectProvider(context);
    final tabs = tabProvider.openTabs;
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final activePath = tabProvider.currentFilePath;
    final rootPath = projectProvider?.rootPath;

    return CodeEditorTapRegion(
      child: Container(
        height: 28.0,
        width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabCount = tabs.length;
          // 下限需容纳内边距(8) + 关闭按钮(18) + 脏标记(10)，否则标签内 Row 会右溢出
          final equalShare = math.max(40.0, totalWidth / tabCount);

          return Theme(
            data: theme.copyWith(
              canvasColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: tabs.length,
              onReorderItem: (oldIndex, newIndex) {
                int targetIndex = newIndex;
                if (oldIndex < newIndex) {
                  targetIndex -= 1;
                }
                tabProvider.reorderTabs(oldIndex, targetIndex);
              },
              itemBuilder: (context, index) {
                if (index < 0 || index >= tabs.length) {
                  return const SizedBox.shrink(key: ValueKey('empty_tab_placeholder'));
                }
                final tab = tabs[index];
                final isSelected = activePath != null && tab.path == activePath;
                final displayName = tab.getDisplayName(tabs, rootPath);
                final naturalWidth = _calculateTabNaturalWidth(
                  context,
                  displayName: displayName,
                  isModified: tab.isModified,
                );
                // 单个 tab 最大宽度为内容宽度（名称宽度+默认间距+按钮宽度），不足时等比例压缩划分
                final itemWidth = math.min(naturalWidth, equalShare);

                return _buildTabItem(
                  context,
                  tabProvider: tabProvider,
                  tab: tab,
                  index: index,
                  isSelected: isSelected,
                  displayName: displayName,
                  width: itemWidth,
                );
              },
            ),
          );
        },
      ),
    ),
  );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required TabProvider tabProvider,
    required EditorTabItem tab,
    required int index,
    required bool isSelected,
    required String displayName,
    required double width,
  }) {
    final theme = Theme.of(context);

    return ReorderableDelayedDragStartListener(
      key: ValueKey(tab.path),
      index: index,
      child: Container(
        width: width,
        height: 28.0,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.0,
          ),
          bottom: isSelected
               ? BorderSide(
                   color: theme.colorScheme.primary,
                   width: 2.0,
                 )
               : BorderSide.none,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            tabProvider.openFile(tab.path);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 6.0, right: 2.0),
            child: Row(
              children: [
                Expanded(
                  // 脏标记并入同一个 Text.rich，避免它在极窄标签里单独撑破 Row
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (tab.isModified)
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.0,
                            ),
                          ),
                        TextSpan(
                          text: displayName,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkResponse(
                  radius: 10,
                  borderRadius: BorderRadius.circular(4.0),
                  hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                  onTap: () {
                    tabProvider.closeTabByPath(context, tab.path);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.close,
                      size: 13.0,
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
