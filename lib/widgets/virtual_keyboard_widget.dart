import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

/// 编辑器下方的虚拟辅助小键盘组件
class VirtualKeyboardWidget extends StatefulWidget {
  final CodeLineEditingController? controller;
  final FocusNode? focusNode;
  final VirtualKeyboardConfig config;
  final Color? backgroundColor;

  const VirtualKeyboardWidget({
    super.key,
    required this.controller,
    this.focusNode,
    required this.config,
    this.backgroundColor,
  });

  @override
  State<VirtualKeyboardWidget> createState() => _VirtualKeyboardWidgetState();
}

class _VirtualKeyboardWidgetState extends State<VirtualKeyboardWidget>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;

  static const double _rowHeight = 30.0;
  static const double _indicatorHeight = 12.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0.0, // 默认折叠（0.0 表示仅显示第一行，1.0 表示完全展开）
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleKeyTap(KeyboardKeyItem keyItem) {
    final controller = widget.controller;
    if (controller == null) return;

    // 轻微触觉反馈提升敲击手感
    HapticFeedback.lightImpact();

    // 如果提供了 focusNode 且当前未聚焦，或者为了确保软键盘不掉，请求聚焦
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
      widget.focusNode!.requestFocus();
    }

    switch (keyItem.action) {
      case 'command':
        _handleCommand(controller, keyItem.value);
        break;
      case 'pair':
        _handlePair(controller, keyItem.value, keyItem.cursorOffset);
        break;
      case 'input':
      default:
        _handleInput(controller, keyItem.value.isNotEmpty ? keyItem.value : keyItem.label);
        break;
    }
  }

  void _handleInput(CodeLineEditingController controller, String text) {
    if (text.isEmpty) return;
    controller.replaceSelection(text);
  }

  void _handlePair(CodeLineEditingController controller, String pairText, int offset) {
    final hasSelection = !controller.selection.isCollapsed &&
        controller.selection.baseOffset != -1 &&
        controller.selection.extentOffset != -1;

    if (hasSelection) {
      final selected = controller.selectedText;
      if (pairText.length >= 2) {
        final left = pairText.substring(0, pairText.length ~/ 2);
        final right = pairText.substring(pairText.length ~/ 2);
        final wrapped = left + selected + right;
        controller.replaceSelection(wrapped);
      } else {
        controller.replaceSelection(pairText + selected + pairText);
      }
    } else {
      controller.replaceSelection(pairText);
      if (offset != 0) {
        final curSel = controller.selection;
        final targetOffset = (curSel.extentOffset + offset).clamp(0, controller.extentLine.length);
        controller.selection = CodeLineSelection.collapsed(
          index: curSel.extentIndex,
          offset: targetOffset,
        );
      }
    }
  }

  void _handleCommand(CodeLineEditingController controller, String command) {
    final cmd = command.toLowerCase().trim();
    switch (cmd) {
      case 'tab':
        controller.applyIndent();
        break;
      case 'untab':
      case 'outdent':
        controller.applyOutdent();
        break;
      case 'cursor_left':
      case 'left':
        controller.moveCursor(AxisDirection.left);
        break;
      case 'cursor_right':
      case 'right':
        controller.moveCursor(AxisDirection.right);
        break;
      case 'cursor_up':
      case 'up':
        controller.moveCursor(AxisDirection.up);
        break;
      case 'cursor_down':
      case 'down':
        controller.moveCursor(AxisDirection.down);
        break;
      case 'line_start':
      case 'home':
        controller.moveCursorToLineStart();
        break;
      case 'line_end':
      case 'end':
        controller.moveCursorToLineEnd();
        break;
      case 'page_start':
        controller.moveCursorToPageStart();
        break;
      case 'page_end':
        controller.moveCursorToPageEnd();
        break;
      case 'undo':
        if (controller.canUndo) {
          controller.undo();
        }
        break;
      case 'redo':
        if (controller.canRedo) {
          controller.redo();
        }
        break;
      case 'copy':
        controller.copy();
        break;
      case 'cut':
        controller.cut();
        break;
      case 'paste':
        controller.paste();
        break;
      case 'backspace':
      case 'delete_backward':
        controller.deleteBackward();
        break;
      case 'delete':
      case 'delete_forward':
        controller.deleteForward();
        break;
      case 'select_all':
        controller.selectAll();
        break;
      case 'keyboard_hide':
      case 'hide_keyboard':
        widget.focusNode?.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        break;
      default:
        // 未知命令安全降级为直接输入其命令名称或原文本
        controller.replaceSelection(command);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.hasKeys) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F3F5));
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFDCDFE6);

    final pages = widget.config.pages;

    int maxRows = 1;
    for (final p in pages) {
      if (p.keys.length > maxRows) {
        maxRows = p.keys.length;
      }
    }

    final hasMultiplePages = pages.length > 1;
    final double indicatorTargetHeight = hasMultiplePages ? _indicatorHeight : 0.0;
    // 多出的行高 + 多页指示器高度
    final double totalExpandableHeight = (maxRows - 1) * _rowHeight + indicatorTargetHeight;

    return CodeEditorTapRegion(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _animationController.value;
          final currentIndicatorHeight = indicatorTargetHeight * progress;
          final currentPageViewHeight = _rowHeight + ((maxRows - 1) * _rowHeight * progress);

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (details) {
              _animationController.stop();
            },
            onVerticalDragUpdate: (details) {
              if (totalExpandableHeight > 0) {
                // 上拉 (delta.dy < 0) 增加展开进度，下拉 (delta.dy > 0) 减少展开进度
                final deltaProgress = -details.delta.dy / totalExpandableHeight;
                _animationController.value =
                    (_animationController.value + deltaProgress).clamp(0.0, 1.0);
              }
            },
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250) {
                _animationController.forward();
              } else if (velocity > 250) {
                _animationController.reverse();
              } else if (_animationController.value > 0.5) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(color: borderColor, width: 0.8),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasMultiplePages)
                      _buildPageIndicator(
                        pages.length,
                        theme,
                        progress,
                        currentIndicatorHeight,
                      ),
                    SizedBox(
                      height: currentPageViewHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: pages.length,
                        onPageChanged: (idx) {
                          setState(() {
                            _currentPage = idx;
                          });
                        },
                        itemBuilder: (context, pageIndex) {
                          return _buildPage(pages[pageIndex], isDark);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 顶部分页指示圆点：
  /// - 只有在有多页且上拉展开时动态显示，默认单行完全不显示
  /// - 纯圆点展示，不添加任何背景条/把手条
  /// - 点击圆点可在展开与折叠之间快速切换
  Widget _buildPageIndicator(
    int pageCount,
    ThemeData theme,
    double progress,
    double height,
  ) {
    if (pageCount <= 1 || progress <= 0.001 || height <= 0.5) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_animationController.value > 0.5) {
          _animationController.reverse();
        } else {
          _animationController.forward();
        }
      },
      child: SizedBox(
        height: height,
        child: Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (index) {
                final isSelected = index == _currentPage;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isSelected ? 12 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(KeyboardPageItem page, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = page.count > 0 ? page.count : 6;
        final cellWidth = constraints.maxWidth / count;
        final rows = page.keys;

        return ClipRect(
          child: OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows.map((row) {
                return SizedBox(
                  height: _rowHeight,
                  child: Row(
                    children: List.generate(count, (colIndex) {
                      if (colIndex < row.length) {
                        final keyItem = row[colIndex];
                        return SizedBox(
                          width: cellWidth,
                          height: _rowHeight,
                          child: _buildKeyButton(keyItem, isDark),
                        );
                      } else {
                        return SizedBox(
                          width: cellWidth,
                          height: _rowHeight,
                        );
                      }
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyButton(KeyboardKeyItem keyItem, bool isDark) {
    final iconData = KeyboardIconHelper.getIcon(keyItem.icon);

    final btnBgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);
    final btnTextColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF303133);
    final borderColor = isDark ? const Color(0xFF383838) : const Color(0xFFE4E7ED);

    Widget content;
    if (iconData != null) {
      content = Icon(
        iconData,
        size: 15,
        color: btnTextColor,
      );
    } else {
      content = Text(
        keyItem.label,
        style: TextStyle(
          fontSize: keyItem.label.length > 3 ? 11 : 13,
          fontWeight: FontWeight.w500,
          color: btnTextColor,
          fontFamily: 'Consolas, Monaco, monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.75, vertical: 0.75),
      child: Material(
        color: btnBgColor,
        borderRadius: BorderRadius.circular(4),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _handleKeyTap(keyItem),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 0.6),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
