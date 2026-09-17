part of re_editor;

class _DefaultCodeAutocompletePromptsBuilder implements DefaultCodeAutocompletePromptsBuilder {

  final Mode? language;
  final List<CodeKeywordPrompt> keywordPrompts;
  final List<CodePrompt> directPrompts;
  final Map<String, List<CodePrompt>> relatedPrompts;

  final Set<CodePrompt> _allKeywordPrompts = {};

  _DefaultCodeAutocompletePromptsBuilder({
    this.language,
    required this.keywordPrompts,
    required this.directPrompts,
    required this.relatedPrompts
  }) {
    _allKeywordPrompts.addAll(keywordPrompts);
    _allKeywordPrompts.addAll(directPrompts);
    final dynamic keywords = language?.keywords;
    if (keywords is Map) {
      final dynamic keywordList = keywords['keyword'];
      if (keywordList is List) {
        _allKeywordPrompts.addAll(keywordList.map(
          (keyword) => CodeKeywordPrompt(word: keyword))
        );
      }
      final dynamic builtInList = keywords['built_in'];
      if (builtInList is List) {
        _allKeywordPrompts.addAll(builtInList.map(
          (keyword) => CodeKeywordPrompt(word: keyword))
        );
      }
      final dynamic literalList = keywords['literal'];
      if (literalList is List) {
        _allKeywordPrompts.addAll(literalList.map(
          (keyword) => CodeKeywordPrompt(word: keyword))
        );
      }
      final dynamic typeList = keywords['type'];
      if (typeList is List) {
        _allKeywordPrompts.addAll(typeList.map(
          (keyword) => CodeKeywordPrompt(word: keyword))
        );
      }
    }
  }

  @override
  CodeAutocompleteEditingValue? build(BuildContext context, CodeLine codeLine, CodeLineSelection selection) {
    final String text = codeLine.text;
    final Characters charactersBefore = text.substring(0, selection.extentOffset).characters;
    if (charactersBefore.isEmpty) {
      return null;
    }
    final Characters charactersAfter = text.substring(selection.extentOffset).characters;
    // FIXME：Check whether the position is inside a string
    if (charactersBefore.containsSymbols(const ['\'', '"']) && charactersAfter.containsSymbols(const ['\'', '"'])) {
      return null;
    }
    // TODO Should check operator `->` for some languages like c/c++
    final Iterable<CodePrompt> prompts;
    final String input;
    if (charactersBefore.takeLast(1).string == '.') {
      input = '';
      int start = charactersBefore.length - 2;
      for (; start >= 0; start--) {
        if (!charactersBefore.elementAt(start).isValidVariablePart) {
          break;
        }
      }
      final String target = charactersBefore.getRange(start + 1, charactersBefore.length - 1).string;
      prompts = relatedPrompts[target] ?? const [];
    } else {
      int start = charactersBefore.length - 1;
      for (; start >= 0; start--) {
        if (!charactersBefore.elementAt(start).isValidVariablePart) {
          break;
        }
      }
      input = charactersBefore.getRange(start + 1, charactersBefore.length).string;
      if (input.isEmpty) {
        return null;
      }
      if (start > 0 && charactersBefore.elementAt(start) == '.') {
        final int mark = start;
        for (start = start - 1; start >= 0; start--) {
          if (!charactersBefore.elementAt(start).isValidVariablePart) {
            break;
          }
        }
        final String target = charactersBefore.getRange(start + 1, mark).string;
        prompts = relatedPrompts[target]?.where(
          (prompt) => prompt.match(input)
        ) ?? const [];
      } else {
        prompts = _allKeywordPrompts.where(
          (prompt) => prompt.match(input)
        );
      }
    }
    if (prompts.isEmpty) {
      return null;
    }
    return CodeAutocompleteEditingValue(
      input: input,
      prompts: prompts.toList(),
      index: 0
    );
  }

}

class _CodeAutocomplete extends StatefulWidget {

  const _CodeAutocomplete({
    required this.viewBuilder,
    required this.promptsBuilder,
    required this.child,
  });

  final CodeAutocompleteWidgetBuilder viewBuilder;
  final CodeAutocompletePromptsBuilder promptsBuilder;
  final Widget child;

  @override
  State<StatefulWidget> createState() => _CodeAutocompleteState();

}

class _CodeAutocompleteState extends State<_CodeAutocomplete> {

  late final _CodeAutocompleteNavigateAction _navigateAction;
  late final _CodeAutocompleteAction _selectAction;

  ValueChanged<CodeAutocompleteResult>? _onAutocomplete;
  OverlayEntry? _overlayEntry;
  ValueNotifier<CodeAutocompleteEditingValue>? _notifier;
  Offset? _position;
  double? _lineHeight;
  LayerLink? _layerLink;

  final GlobalKey _menuKey = GlobalKey();
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _isPointerSliding = false;

  @override
  void initState() {
    super.initState();
    _navigateAction = _CodeAutocompleteNavigateAction(
      onInvoke: (intent) {
        final CodeAutocompleteEditingValue? value = _notifier?.value;
        if (value == null) {
          return null;
        }
        int newIndex = value.index;
        if (intent.direction == AxisDirection.up) {
          newIndex--;
        } else {
          newIndex++;
        }
        if (newIndex < 0) {
          newIndex = value.prompts.length - 1;
        } else if (newIndex >= value.prompts.length) {
          newIndex = 0;
        }
        _notifier?.value = value.copyWith(
          index: newIndex,
        );
        return intent;
      },
    );
    _selectAction = _CodeAutocompleteAction<CodeShortcutNewLineIntent>(
      onInvoke: (intent) {
        final CodeAutocompleteEditingValue? value = _notifier?.value;
        if (value == null) {
          return null;
        }
        _onAutocomplete?.call(value.autocomplete);
        return intent;
      },
    );
  }

  @override
  void didUpdateWidget(covariant _CodeAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    dismiss();
    super.dispose();
  }

  void _handleEditorPointerDown(PointerDownEvent event) {
    if (_overlayEntry == null) return;
    _pointerDownPosition = event.position;
    _pointerDownTime = DateTime.now();
    _isPointerSliding = false;
  }

  void _handleEditorPointerMove(PointerMoveEvent event) {
    if (_overlayEntry == null || _pointerDownPosition == null) return;
    if ((event.position - _pointerDownPosition!).distance > kTouchSlop) {
      _isPointerSliding = true;
    }
  }

  void _handleEditorPointerUp(PointerUpEvent event) {
    if (_overlayEntry == null || _pointerDownPosition == null) {
      _pointerDownPosition = null;
      _isPointerSliding = false;
      return;
    }

    // 用户在编辑区滑动（例如上下或左右滚动代码），坚决不关闭菜单
    if (_isPointerSliding) {
      _pointerDownPosition = null;
      _isPointerSliding = false;
      return;
    }

    final duration = DateTime.now().difference(_pointerDownTime ?? DateTime.now());
    _pointerDownPosition = null;
    _isPointerSliding = false;

    // 轻触点击判定：时长小于 500ms 且无位移
    if (duration.inMilliseconds > 500) {
      return;
    }

    // 检查点击位置是否在补全菜单内
    final RenderBox? menuBox = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (menuBox != null && menuBox.hasSize) {
      final localPos = menuBox.globalToLocal(event.position);
      if (menuBox.paintBounds.contains(localPos)) {
        // 点击在菜单内部，由菜单自身交互逻辑处理，不关闭
        return;
      }
    }

    // 只有在菜单区域外的编辑区执行了点击（Tap），才关闭菜单
    dismiss();
  }

  void _handleEditorPointerCancel(PointerCancelEvent event) {
    _pointerDownPosition = null;
    _isPointerSliding = false;
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        CodeShortcutCursorMoveIntent: _navigateAction,
        CodeShortcutNewLineIntent: _selectAction,
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handleEditorPointerDown,
        onPointerMove: _handleEditorPointerMove,
        onPointerUp: _handleEditorPointerUp,
        onPointerCancel: _handleEditorPointerCancel,
        child: widget.child,
      ),
    );
  }

  int _showVersion = 0;

  void show({
    required LayerLink layerLink,
    required Offset position,
    required double lineHeight,
    required CodeLineEditingValue value,
    required ValueChanged<CodeAutocompleteResult> onAutocomplete,
  }) {
    final int version = ++_showVersion;
    final dynamic result = widget.promptsBuilder.build(
      context,
      value.codeLines[value.selection.extentIndex],
      value.selection,
    );

    if (result is Future) {
      result.then((resolved) {
        if (!mounted || version != _showVersion) return;
        if (resolved is CodeAutocompleteEditingValue) {
          _displayPrompts(
            layerLink: layerLink,
            position: position,
            lineHeight: lineHeight,
            editingValue: resolved,
            onAutocomplete: onAutocomplete,
          );
        } else {
          dismiss();
        }
      });
      return;
    }

    if (result is CodeAutocompleteEditingValue) {
      _displayPrompts(
        layerLink: layerLink,
        position: position,
        lineHeight: lineHeight,
        editingValue: result,
        onAutocomplete: onAutocomplete,
      );
    } else {
      dismiss();
    }
  }

  void _displayPrompts({
    required LayerLink layerLink,
    required Offset position,
    required double lineHeight,
    required CodeAutocompleteEditingValue editingValue,
    required ValueChanged<CodeAutocompleteResult> onAutocomplete,
  }) {
    _position = position;
    _lineHeight = lineHeight;
    _layerLink = layerLink;
    _onAutocomplete = onAutocomplete;

    if (_overlayEntry != null && _notifier != null) {
      // 已经处于展开状态，原地更新候选列表并重绘 OverlayEntry 计算自适应高度
      _notifier!.value = editingValue;
      _overlayEntry!.markNeedsBuild();
      return;
    }

    dismiss();
    _position = position;
    _lineHeight = lineHeight;
    _layerLink = layerLink;
    _notifier = ValueNotifier(editingValue);
    _onAutocomplete = onAutocomplete;
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return _buildWidget(context);
      },
    );
    final overlay = Overlay.maybeOf(context, rootOverlay: false) ?? Overlay.of(context, rootOverlay: true);
    overlay.insert(_overlayEntry!);
    _navigateAction.setEnabled(true);
    _selectAction.setEnabled(true);
  }

  void dismiss() {
    _position = null;
    _lineHeight = null;
    _layerLink = null;
    _notifier = null;
    _onAutocomplete = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _navigateAction.setEnabled(false);
    _selectAction.setEnabled(false);
  }

  Widget _buildWidget(BuildContext context) {
    if (_position == null || _layerLink == null || _notifier == null) {
      return const SizedBox.shrink();
    }
    final PreferredSizeWidget child = widget.viewBuilder(context, _notifier!, (result) {
      _onAutocomplete?.call(result);
    });
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final position = _position!;

    // 水平方向：允许菜单水平自然超出编辑区
    const double offsetX = 0.0;

    // 计算小键盘及局部 Overlay 的底部边界
    final overlay = Overlay.maybeOf(context, rootOverlay: false) ?? Overlay.of(context, rootOverlay: true);
    final RenderBox? overlayBox = overlay.context.findRenderObject() as RenderBox?;
    double overlayBottomY = screenSize.height;
    if (overlayBox != null && overlayBox.hasSize) {
      final overlayTopLeft = overlayBox.localToGlobal(Offset.zero);
      overlayBottomY = overlayTopLeft.dy + overlayBox.size.height;
    }
    final double systemKeyboardTop = screenSize.height - mediaQuery.viewInsets.bottom;
    final double effectiveBottom = min(overlayBottomY, systemKeyboardTop);

    // 计算光标所在行下方的可用高度，并预留 4.0 像素防顶边距
    const double safetyMargin = 4.0;
    final double availableHeight = effectiveBottom - position.dy - safetyMargin;

    // 显示位置坚决锁定在当前行下方，绝不在光标上方翻转显示
    const double offsetY = 0.0;

    // 高度自适应：如果顶到了小键盘，那么高度变小，剩余项在内部滑动
    final double desiredHeight = child.preferredSize.height;
    const double minSensibleHeight = 44.0;
    final double finalHeight;
    if (availableHeight < desiredHeight) {
      finalHeight = max(minSensibleHeight, availableHeight);
    } else {
      finalHeight = desiredHeight;
    }

    return CompositedTransformFollower(
      link: _layerLink!,
      showWhenUnlinked: false,
      offset: Offset(offsetX, offsetY),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: CodeEditorTapRegion(
            child: ExcludeSemantics(
              child: SizedBox(
                key: _menuKey,
                width: child.preferredSize.width,
                height: finalHeight,
                child: child,
              ),
            )
          ),
        )
      ),
    );
  }

}

class _CodeAutocompleteAction<T extends Intent> extends CallbackAction<T> {

  bool _isEnabled = false;

  _CodeAutocompleteAction({
    required super.onInvoke
  });

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  @override
  bool get isActionEnabled => _isEnabled;

}

class _CodeAutocompleteNavigateAction extends _CodeAutocompleteAction<CodeShortcutCursorMoveIntent> {

  _CodeAutocompleteNavigateAction({
    required super.onInvoke
  });

  @override
  bool consumesKey(CodeShortcutCursorMoveIntent intent) {
    return intent.direction == AxisDirection.up || intent.direction == AxisDirection.down;
  }

}

extension _CodeAutocompleteStringExtension on String {

  bool get isValidVariablePart {
    final int char = codeUnits.first;
    return (char >= 65 && char <= 90) || (char >= 97 && char <= 122) || char == 95;
  }

}

extension _CodeAutocompleteCharactersExtension on Characters {

  bool containsSymbols(List<String> symbols) {
    for (int i = length - 1; i >= 0; i--) {
      if (symbols.contains(elementAt(i))) {
        return true;
      }
    }
    return false;
  }

}