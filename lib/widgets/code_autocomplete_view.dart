import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../services/code_completion/smart_prompts_builder.dart';

/// 移动端友好的现代化代码智能补全悬浮面板
class CodeAutocompleteView extends StatefulWidget implements PreferredSizeWidget {
  const CodeAutocompleteView({
    super.key,
    required this.notifier,
    required this.onSelected,
    this.width = 270.0,
    this.height = 196.0,
  });

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;
  final double width;
  final double height;

  static const double itemHeight = 36.0;
  static const double verticalPadding = 8.0;
  static const double borderWidth = 2.0;

  @override
  Size get preferredSize {
    final prompts = notifier.value.prompts;
    if (prompts.isEmpty) return Size(width, 0.0);
    final contentHeight = prompts.length * itemHeight + verticalPadding + borderWidth;
    final effectiveHeight = contentHeight.clamp(itemHeight + verticalPadding + borderWidth, height);
    return Size(width, effectiveHeight);
  }

  @override
  State<CodeAutocompleteView> createState() => _CodeAutocompleteViewState();
}

class _CodeAutocompleteViewState extends State<CodeAutocompleteView> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_handleValueChanged);
  }

  @override
  void didUpdateWidget(covariant CodeAutocompleteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_handleValueChanged);
      widget.notifier.addListener(_handleValueChanged);
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_handleValueChanged);
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handleValueChanged() {
    if (!mounted) return;
    final value = widget.notifier.value;
    final targetOffset = value.index * CodeAutocompleteView.itemHeight;
    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      final currentOffset = _scrollController.offset;
      final viewportDimension = _scrollController.position.viewportDimension;
      final maxView = currentOffset + viewportDimension - CodeAutocompleteView.itemHeight - CodeAutocompleteView.verticalPadding;
      if (targetOffset < currentOffset) {
        _scrollController.jumpTo(targetOffset);
      } else if (targetOffset > maxView) {
        _scrollController.jumpTo(math.max(0.0, targetOffset - viewportDimension + CodeAutocompleteView.itemHeight + CodeAutocompleteView.verticalPadding));
      }
    }
    if (value.index == 0 && _horizontalScrollController.hasClients) {
      _horizontalScrollController.jumpTo(0.0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final value = widget.notifier.value;
    final prompts = value.prompts;

    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      width: widget.width,
      constraints: BoxConstraints(maxHeight: widget.height),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scrollController,
        notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
        child: Scrollbar(
          controller: _horizontalScrollController,
          notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(0.0, widget.width - 2.0),
              ),
              child: IntrinsicWidth(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.vertical,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int index = 0; index < prompts.length; index++)
                        _buildPromptItem(context, prompts[index], index == value.index, index, theme, isDark),
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

  Widget _buildPromptItem(
    BuildContext context,
    CodePrompt prompt,
    bool isSelected,
    int index,
    ThemeData theme,
    bool isDark,
  ) {
    final smart = prompt is SmartPrompt ? prompt : null;
    final kind = smart?.kind ?? SmartPromptKind.word;
    final typeText = smart?.type ?? '';
    final matchedIndices = smart?.matchedIndices ?? const [];

    final highlightBg = theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15);
    final defaultBg = Colors.transparent;

    return InkWell(
      onTap: () {
        widget.notifier.value = widget.notifier.value.copyWith(index: index);
        widget.onSelected(widget.notifier.value.autocomplete);
      },
      child: Container(
        height: CodeAutocompleteView.itemHeight,
        color: isSelected ? highlightBg : defaultBg,
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKindIcon(kind, theme),
            const SizedBox(width: 8.0),
            _buildHighlightedText(prompt.word, matchedIndices, theme, isSelected),
            if (typeText.isNotEmpty) ...[
              const SizedBox(width: 8.0),
              Text(
                typeText,
                style: TextStyle(
                  fontSize: 11.0,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKindIcon(SmartPromptKind kind, ThemeData theme) {
    IconData icon;
    Color color;

    switch (kind) {
      case SmartPromptKind.keyword:
        icon = Icons.vpn_key_rounded;
        color = const Color(0xFFC586C0); // 类似 VS Code 关键字粉紫色
        break;
      case SmartPromptKind.function:
        icon = Icons.functions_rounded;
        color = const Color(0xFFDCDCAA); // 函数黄色
        break;
      case SmartPromptKind.field:
        icon = Icons.data_object_rounded;
        color = const Color(0xFF9CDCFE); // 变量浅蓝色
        break;
      case SmartPromptKind.type:
        icon = Icons.category_rounded;
        color = const Color(0xFF4EC9B0); // 类型青绿色
        break;
      case SmartPromptKind.constant:
        icon = Icons.tag_rounded;
        color = const Color(0xFF4FC1FF); // 常量亮天蓝色
        break;
      case SmartPromptKind.word:
        icon = Icons.text_snippet_outlined;
        color = Colors.grey;
        break;
    }

    return Icon(icon, size: 15.0, color: color);
  }

  Widget _buildHighlightedText(
    String word,
    List<int> matchedIndices,
    ThemeData theme,
    bool isSelected,
  ) {
    if (matchedIndices.isEmpty) {
      return Text(
        word,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontFamily: 'monospace',
        ),
        maxLines: 1,
        softWrap: false,
      );
    }

    final matchedSet = matchedIndices.toSet();
    final List<TextSpan> spans = [];

    for (int i = 0; i < word.length; i++) {
      final isHit = matchedSet.contains(i);
      spans.add(
        TextSpan(
          text: word[i],
          style: TextStyle(
            color: isHit ? theme.colorScheme.primary : null,
            fontWeight: isHit ? FontWeight.bold : (isSelected ? FontWeight.w600 : FontWeight.normal),
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13.0,
          color: theme.textTheme.bodyMedium?.color,
          fontFamily: 'monospace',
        ),
        children: spans,
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}
