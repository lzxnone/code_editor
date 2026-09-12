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

class _VirtualKeyboardWidgetState extends State<VirtualKeyboardWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F3F5));
    final borderColor = isDark ? const Color(0xFF333333) : const Color(0xFFDCDFE6);

    final pages = widget.config.pages;
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }

    return CodeEditorTapRegion(
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
              SizedBox(
                height: 84, // 两行按键的高度
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
              if (pages.length > 1) _buildPageIndicator(pages.length, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int pageCount, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
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
    );
  }

  Widget _buildPage(KeyboardPageItem page, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = page.count > 0 ? page.count : 6;
        final cellWidth = constraints.maxWidth / count;
        final rows = page.keys;

        return Column(
          children: rows.take(2).map((row) {
            return SizedBox(
              height: 42,
              child: Row(
                children: List.generate(count, (colIndex) {
                  if (colIndex < row.length) {
                    final keyItem = row[colIndex];
                    return SizedBox(
                      width: cellWidth,
                      height: 42,
                      child: _buildKeyButton(keyItem, isDark),
                    );
                  } else {
                    // 多余未配置的格子，正常渲染背景占位
                    return SizedBox(
                      width: cellWidth,
                      height: 42,
                    );
                  }
                }),
              ),
            );
          }).toList(),
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
        size: 18,
        color: btnTextColor,
      );
    } else {
      content = Text(
        keyItem.label,
        style: TextStyle(
          fontSize: keyItem.label.length > 3 ? 12 : 15,
          fontWeight: FontWeight.w500,
          color: btnTextColor,
          fontFamily: 'Consolas, Monaco, monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
      child: Material(
        color: btnBgColor,
        borderRadius: BorderRadius.circular(6),
        elevation: 0.5,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _handleKeyTap(keyItem),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
