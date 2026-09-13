import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'virtual_keyboard_sink.dart';
import 'terminal_modifier_state.dart';

/// 编辑器下方的虚拟辅助小键盘组件
class VirtualKeyboardWidget extends StatefulWidget {
  final CodeLineEditingController? controller;
  final FocusNode? focusNode;

  /// 输入汇聚实现。为空时按 [controller] 自动构造编辑区实现；
  /// 终端作用域传入 `TerminalKeyboardSink`。
  final VirtualKeyboardSink? sink;

  /// 终端修饰键运行时状态。终端作用域由外部注入，使终端也能读到同一份状态
  /// （把修饰符叠加到软键盘/硬件键盘的输入上）；为空时组件内部自建一份。
  final TerminalModifierState? modifierState;

  final VirtualKeyboardConfig config;
  final Color? backgroundColor;

  const VirtualKeyboardWidget({
    super.key,
    required this.controller,
    this.focusNode,
    this.sink,
    this.modifierState,
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

  /// 输入汇聚实现（终端作用域由外部注入，否则按 controller 构造编辑区实现）
  VirtualKeyboardSink? _sink;

  /// 修饰键运行时状态（终端作用域由外部注入，使终端能共用同一份状态）
  late TerminalModifierState _modifiers;

  /// 是否由本组件创建了 [_modifiers]（自建时才负责释放）
  bool _ownsModifiers = false;

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
    _resolveSink();
    _resolveModifiers();
  }

  @override
  void didUpdateWidget(covariant VirtualKeyboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sink != widget.sink || oldWidget.controller != widget.controller) {
      _resolveSink();
    }
    if (oldWidget.modifierState != widget.modifierState) {
      _releaseModifiers();
      _resolveModifiers();
    }
  }

  /// 终端作用域由外部注入 sink；编辑区按 controller 自动构造
  void _resolveSink() {
    _sink = widget.sink ??
        (widget.controller != null
            ? EditorKeyboardSink(controller: widget.controller!, focusNode: widget.focusNode)
            : null);
  }

  void _resolveModifiers() {
    final injected = widget.modifierState;
    if (injected != null) {
      _modifiers = injected;
      _ownsModifiers = false;
    } else {
      _modifiers = TerminalModifierState();
      _ownsModifiers = true;
    }
    _modifiers.addListener(_onModifiersChanged);
  }

  void _releaseModifiers() {
    _modifiers.removeListener(_onModifiersChanged);
    if (_ownsModifiers) {
      _modifiers.dispose();
    }
  }

  void _onModifiersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _releaseModifiers();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleKeyTap(KeyboardKeyItem keyItem) {
    final sink = _sink;
    if (sink == null) return;

    // 轻微触觉反馈提升敲击手感
    HapticFeedback.lightImpact();

    // 如果提供了 focusNode 且当前未聚焦，或者为了确保软键盘不掉，请求聚焦
    if (widget.focusNode != null && !widget.focusNode!.hasFocus) {
      widget.focusNode!.requestFocus();
    }

    // 修饰键只切换运行时状态，不产生输出
    if (keyItem.action == 'modifier') {
      _modifiers.toggle(keyItem.value);
      return;
    }

    final mods = _effectiveMods(keyItem.mods);

    switch (keyItem.action) {
      case 'command':
        sink.sendCommand(keyItem.value);
        break;
      case 'pair':
        sink.sendPair(keyItem.value, keyItem.cursorOffset);
        break;
      case 'key':
        sink.sendNamedKey(keyItem.value, mods: mods);
        break;
      case 'input':
      default:
        sink.sendText(
          keyItem.value.isNotEmpty ? keyItem.value : keyItem.label,
          appendEnter: keyItem.autoEnter,
        );
        break;
    }

    // 一次性修饰键被"下一次任意按键"消耗（含 Esc、方向键这类不产生字符的键）
    _modifiers.consume();
  }

  /// 合并按键自身配置的修饰符与运行时激活的修饰符
  KeyboardKeyMods _effectiveMods(KeyboardKeyMods own) {
    final active = _modifiers.mods;
    return KeyboardKeyMods(
      ctrl: own.ctrl || active.ctrl,
      alt: own.alt || active.alt,
      shift: own.shift || active.shift,
    );
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

    // 修饰键处于激活（一次性或锁定）状态时高亮，让用户看清当前修饰状态
    final isModifierActive = keyItem.action == 'modifier' && _modifiers.isActive(keyItem.value);

    final btnBgColor = isModifierActive
        ? (isDark ? const Color(0xFF2F4F6F) : const Color(0xFFD6E6FF))
        : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF));
    final btnTextColor = isModifierActive
        ? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0B57D0))
        : (isDark ? const Color(0xFFE0E0E0) : const Color(0xFF303133));
    final borderColor = isModifierActive
        ? const Color(0xFF0B57D0)
        : (isDark ? const Color(0xFF383838) : const Color(0xFFE4E7ED));

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
