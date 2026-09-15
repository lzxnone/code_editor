part of re_editor;

const double _kDefaultTextSize = 13.0;
const double _kDefaultFontHeight = 1.4;
const double _kDefaultCaretWidth = 2;
const EdgeInsetsGeometry _kDefaultPadding = EdgeInsets.all(5);
const Duration _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);

class _CodeEditable extends StatefulWidget {

  final GlobalKey editorKey;
  final String? hint;
  final CodeIndicatorBuilder? indicatorBuilder;
  final CodeScrollbarBuilder? scrollbarBuilder;
  final double? verticalScrollbarWidth;
  final double? horizontalScrollbarHeight;
  final TextStyle textStyle;
  final Color? hintTextColor;
  final Color? backgroundColor;
  final Color selectionColor;
  final Color highlightColor;
  final Color cursorColor;
  final Color? cursorLineColor;
  final Color? chunkIndicatorColor;
  final double cursorWidth;
  final bool showCursorWhenReadOnly;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Widget? leadingDivider;
  final bool pinLineNumbers;
  final Border? border;
  final BorderRadius? borderRadius;
  final Clip clipBehavior;
  final ValueChanged<CodeLineEditingValue>? onChanged;
  final FocusNode focusNode;
  final CodeLineEditingController controller;
  final _CodeInputController inputController;
  final _CodeFloatingCursorController floatingCursorController;
  final CodeHighlightTheme? codeTheme;
  final bool readOnly;
  final bool autofocus;
  final bool wordWrap;
  final int? maxLengthSingleLineRendering;
  final CodeFindController findController;
  final CodeScrollController scrollController;
  final CodeChunkController chunkController;
  final LayerLink startHandleLayerLink;
  final LayerLink endHandleLayerLink;
  final LayerLink toolbarLayerLink;
  final _SelectionOverlayController selectionOverlayController;

  const _CodeEditable({
    required this.editorKey,
    this.hint,
    this.indicatorBuilder,
    this.scrollbarBuilder,
    this.verticalScrollbarWidth,
    this.horizontalScrollbarHeight,
    required this.textStyle,
    this.hintTextColor,
    this.backgroundColor,
    required this.selectionColor,
    required this.highlightColor,
    required this.cursorColor,
    this.cursorLineColor,
    this.chunkIndicatorColor,
    required this.cursorWidth,
    required this.showCursorWhenReadOnly,
    required this.padding,
    required this.margin,
    required this.leadingDivider,
    this.pinLineNumbers = true,
    this.border,
    this.borderRadius,
    this.clipBehavior = Clip.none,
    this.onChanged,
    required this.focusNode,
    required this.controller,
    required this.inputController,
    required this.floatingCursorController,
    required this.codeTheme,
    required this.readOnly,
    required this.autofocus,
    required this.wordWrap,
    this.maxLengthSingleLineRendering,
    required this.findController,
    required this.scrollController,
    required this.chunkController,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.toolbarLayerLink,
    required this.selectionOverlayController,
  });

  @override
  State<StatefulWidget> createState() => _CodeEditableState();

}

class _CodeEditableState extends State<_CodeEditable> with AutomaticKeepAliveClientMixin<_CodeEditable>, SingleTickerProviderStateMixin {

  late bool _didAutoFocus;
  late final _CodeCursorBlinkController _cursorController;

  late AnimationController _floatingCursorAnimationController;

  late _CodeHighlighter _highlighter;
  late CodeIndicatorValueNotifier _codeIndicatorValueNotifier;
  _ShiftedViewportOffset? _shiftedHorizontalViewport;
  double _gutterWidth = 0.0;

  @override
  bool get wantKeepAlive => widget.focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    _didAutoFocus = false;

    widget.controller.addListener(_onCodeInputChanged);
    widget.inputController.addListener(_onCodeUserInputChanged);

    _highlighter = _CodeHighlighter(
      context: context,
      controller: widget.controller,
      theme: widget.codeTheme,
    );

    _codeIndicatorValueNotifier = CodeIndicatorValueNotifier(null);

    _cursorController = _CodeCursorBlinkController();
    _floatingCursorAnimationController = AnimationController(vsync: this);

    widget.floatingCursorController
      ..blinkController = _cursorController
      ..animationController = _floatingCursorAnimationController;

    widget.focusNode.addListener(_onFocusChanged);
    widget.findController.addListener(_onCodeFindChanged);
  }

  @override
  void didUpdateWidget(covariant _CodeEditable oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _highlighter.controller = widget.controller;
      oldWidget.controller.removeListener(_onCodeInputChanged);
      widget.controller.addListener(_onCodeInputChanged);
    }
    if (oldWidget.inputController != widget.inputController) {
      oldWidget.inputController.removeListener(_onCodeUserInputChanged);
      widget.inputController.addListener(_onCodeUserInputChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.findController != widget.findController) {
      oldWidget.findController.removeListener(_onCodeFindChanged);
      widget.findController.addListener(_onCodeFindChanged);
    }
    if (oldWidget.codeTheme != widget.codeTheme) {
      _highlighter.theme = widget.codeTheme;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus && widget.autofocus) {
      _didAutoFocus = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).autofocus(widget.focusNode);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCodeInputChanged);
    widget.inputController.removeListener(_onCodeUserInputChanged);
    _highlighter.dispose();
    _codeIndicatorValueNotifier.dispose();
    _cursorController.dispose();
    _floatingCursorAnimationController.dispose();
    widget.focusNode.removeListener(_onFocusChanged);
    widget.findController.removeListener(_onCodeFindChanged);
    _shiftedHorizontalViewport?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Widget child = _CodeScrollable(
      axisDirection: AxisDirection.down,
      controller: widget.scrollController.verticalScroller,
      viewportBuilder: (context, ViewportOffset vertical) {
        final Widget? indicator = widget.indicatorBuilder?.call(
          context,
          widget.controller,
          widget.chunkController,
          _codeIndicatorValueNotifier
        );
        final Widget? gutterWidget;
        if (indicator != null || widget.leadingDivider != null) {
          gutterWidget = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (indicator != null) indicator,
              if (widget.leadingDivider != null) widget.leadingDivider!,
            ],
          );
        } else {
          gutterWidget = null;
        }

        final Widget? effectiveGutter;
        if (gutterWidget == null) {
          effectiveGutter = null;
        } else if (widget.pinLineNumbers || widget.wordWrap) {
          effectiveGutter = gutterWidget;
        } else {
          effectiveGutter = _ScrollingGutter(
            horizontalScroller: widget.scrollController.horizontalScroller,
            onWidthMeasured: (width) {
              _gutterWidth = width;
            },
            child: gutterWidget,
          );
        }

        Widget codeField;
        if (widget.wordWrap) {
          codeField = _buildCodeField(vertical, null);
        } else {
          codeField = _CodeScrollable(
            axisDirection: AxisDirection.right,
            controller: widget.scrollController.horizontalScroller,
            viewportBuilder: (context, ViewportOffset horizontal) {
              final ViewportOffset effectiveHorizontal;
              if (widget.pinLineNumbers || gutterWidget == null) {
                effectiveHorizontal = horizontal;
              } else {
                if (_shiftedHorizontalViewport == null ||
                    _shiftedHorizontalViewport!._delegate != horizontal) {
                  _shiftedHorizontalViewport?.dispose();
                  _shiftedHorizontalViewport = _ShiftedViewportOffset(
                    horizontal,
                    () => _gutterWidth,
                  );
                }
                effectiveHorizontal = _shiftedHorizontalViewport!;
              }
              return _buildCodeField(vertical, effectiveHorizontal);
            },
            scrollbarBuilder: widget.scrollbarBuilder
          );
        }
        if (widget.controller.value.isInitial) {
          final String? hint = widget.hint;
          if (hint != null && hint.isNotEmpty) {
            codeField = Stack(
              children: [
                codeField,
                IgnorePointer(
                  ignoring: true,
                  child: Padding(
                    padding: widget.padding,
                    child: Text(
                      hint,
                      style: widget.textStyle.copyWith(
                        color: widget.hintTextColor
                      ),
                    ),
                  )
                )
              ],
            );
          }
        }
        return Container(
          decoration: BoxDecoration(
            border: widget.border,
            color: widget.backgroundColor,
            borderRadius: widget.borderRadius,
          ),
          clipBehavior: widget.clipBehavior,
          margin: widget.margin,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (effectiveGutter != null)
                effectiveGutter,
              Expanded(
                child: RepaintBoundary(
                  child: CompositedTransformTarget(
                    link: widget.toolbarLayerLink,
                    child: codeField
                  ),
                ),
              )
            ],
          ),
        );
      },
      scrollbarBuilder: widget.scrollbarBuilder
    );
    return CodeEditorTapRegion(
      onTapOutside: (_) {
        widget.focusNode.unfocus();
      },
      child: NotificationListener(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            widget.selectionOverlayController.hideToolbar();
          } else if (notification is ScrollEndNotification) {
            if (!widget.controller.selection.isCollapsed && widget.controller.selection.baseOffset != -1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.focusNode.hasFocus &&
                    !widget.controller.selection.isCollapsed &&
                    widget.controller.selection.baseOffset != -1) {
                  widget.selectionOverlayController.showToolbar(context, Offset.zero);
                }
              });
            }
          }
          return false;
        },
        child: child
      )
    );
  }

  Widget _buildCodeField(ViewportOffset vertical, ViewportOffset? horizontal) {
    return _CodeField(
      key: widget.editorKey,
      verticalViewport: vertical,
      horizontalViewport: horizontal,
      verticalScrollbarWidth: widget.verticalScrollbarWidth ?? _kScrollbarThickness,
      horizontalScrollbarHeight: widget.horizontalScrollbarHeight ?? _kScrollbarThickness,
      selection: widget.controller.selection,
      highlightSelections: widget.findController.allMatchSelections,
      codes: widget.controller.codeLines,
      textStyle: widget.textStyle,
      hasFocus: widget.focusNode.hasFocus,
      highlighter: _highlighter,
      showCursorNotifier: _cursorController,
      floatingCursorNotifier: widget.floatingCursorController,
      onRenderParagraphsChanged: (paragraphs) {
        _codeIndicatorValueNotifier.value = CodeIndicatorValue(
          paragraphs: paragraphs,
          focusedIndex: widget.controller.selection.extentIndex
        );
      },
      selectionColor: widget.selectionColor,
      highlightColor: widget.highlightColor,
      cursorColor: widget.cursorColor,
      cursorLineColor: widget.cursorLineColor,
      chunkIndicatorColor: widget.chunkIndicatorColor,
      cursorWidth: widget.cursorWidth,
      padding: widget.padding,
      readOnly: widget.readOnly,
      // Enable long text rendering when the find is on.
      maxLengthSingleLineRendering: widget.findController.value != null ? null : widget.maxLengthSingleLineRendering,
      startHandleLayerLink: widget.startHandleLayerLink,
      endHandleLayerLink: widget.endHandleLayerLink,
    );
  }

  void _onFocusChanged() {
    if (!mounted) {
      return;
    }
    _updateCursorState();
    _updateAutoCompleteState(false);
    updateKeepAlive();
    if (!widget.focusNode.hasFocus) {
      if (kIsAndroid || kIsIOS) {
        widget.controller.cancelSelection();
      }
      widget.selectionOverlayController.hideHandle();
      widget.selectionOverlayController.hideToolbar();
    }
  }

  void _onCodeInputChanged() {
    if (!mounted) {
      return;
    }
    widget.onChanged?.call(widget.controller.value);
    if (widget.controller.codeLines != widget.controller.preValue?.codeLines &&
      widget.controller.preValue != null) {
      widget.selectionOverlayController.hideHandle();
      widget.selectionOverlayController.hideToolbar();
    } else {
      _updateAutoCompleteState(false);
    }
    _updateCursorState();
    setState(() {
    });
  }

  void _onCodeUserInputChanged() {
    if (!mounted) {
      return;
    }
    // Delay 50ms to update the auto-complate prompt words.
    Future.delayed(const Duration(milliseconds: 50), () {
      _updateAutoCompleteState(true);
    });
  }

  void _onCodeFindChanged() {
    if (!mounted) {
      return;
    }
    final CodeFindValue? value = widget.findController.value;
    if (value == null) {
      widget.focusNode.requestFocus();
      return;
    }
    if (widget.focusNode.hasFocus) {
      return;
    }
    final CodeLineSelection? currentMatch = widget.findController.currentMatchSelection;
    if (currentMatch == null) {
      return;
    }
    widget.controller.selection = currentMatch;
    if (currentMatch.isSameLine) {
      widget.controller.makePositionCenterIfInvisible(CodeLinePosition(
        index: currentMatch.start.index,
        offset: (currentMatch.startOffset + currentMatch.endOffset) >> 1
      ));
    } else {
      widget.controller.makePositionCenterIfInvisible(currentMatch.start);
    }
  }

  void _updateCursorState() {
    if (widget.focusNode.hasFocus && (!widget.readOnly || widget.showCursorWhenReadOnly)) {
      _cursorController.startBlink();
    } else {
      _cursorController.stopBlink();
    }
  }

  void _updateAutoCompleteState(bool isCodeLineChanged) {
    if (!mounted) {
      return;
    }
    final _CodeAutocompleteState? autocompleteState;
    try {
      autocompleteState = context.findAncestorStateOfType<_CodeAutocompleteState>();
    } catch (e) {
      // Ignore the error when the widget is disposed.
      return;
    }
    if (autocompleteState == null) {
      return;
    }
    if (!isCodeLineChanged) {
      autocompleteState.dismiss();
      return;
    }
    if (widget.controller.isComposing || !widget.controller.selection.isCollapsed) {
      autocompleteState.dismiss();
      return;
    }
    final _CodeFieldRender? render = widget.editorKey.currentContext?.findRenderObject() as _CodeFieldRender?;
    if (render == null) {
      autocompleteState.dismiss();
      return;
    }
    final Offset? position = render.calculateTextPositionScreenOffset(widget.controller.selection.extent, true);
    if (position == null) {
      autocompleteState.dismiss();
      return;
    }
    autocompleteState.show(
      layerLink: widget.startHandleLayerLink,
      position: position,
      lineHeight: render.lineHeight,
      value: widget.controller.value,
      onAutocomplete: (value) {
        autocompleteState?.dismiss();
        final CodeLineSelection selection = widget.controller.selection;
        widget.controller.replaceSelection(value.word, selection.copyWith(
          baseOffset: selection.baseOffset - value.input.length,
        ));
        widget.controller.selection = selection.copyWith(
          baseOffset: selection.baseOffset + value.selection.baseOffset,
          extentOffset: selection.extentOffset + value.selection.extentOffset,
        );
      }
    );
  }

}

class _CodeCursorBlinkController extends ValueNotifier<bool> {

  Timer? _timer;

  _CodeCursorBlinkController() : super(false);

  void startBlink() {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
    if (kIsAndroid || kIsIOS) {
      // Wait selection position to update
      Future.delayed(const Duration(milliseconds: 100), () {
        value = true;
      });
    } else {
      value = true;
    }
  }

  void stopBlink() {
    if (_timer == null) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    value = false;
  }

  void _cursorTick(Timer timer) {
    value = !value;
  }

  @override
  void dispose() {
    stopBlink();
    super.dispose();
  }

}

class _ShiftedViewportOffset extends ViewportOffset {

  final ViewportOffset _delegate;
  final ValueGetter<double> _gutterWidthGetter;

  _ShiftedViewportOffset(this._delegate, this._gutterWidthGetter) {
    _delegate.addListener(notifyListeners);
  }

  double get _gutterWidth => _gutterWidthGetter();

  @override
  bool get hasPixels => _delegate.hasPixels;

  @override
  double get pixels =>
      _delegate.hasPixels ? max(0.0, _delegate.pixels - _gutterWidth) : 0.0;

  @override
  bool applyViewportDimension(double viewportDimension) {
    return _delegate.applyViewportDimension(viewportDimension);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    return _delegate.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent + _gutterWidth,
    );
  }

  @override
  void correctBy(double correction) {
    _delegate.correctBy(correction);
  }

  @override
  void jumpTo(double pixels) {
    _delegate.jumpTo(pixels + _gutterWidth);
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    return _delegate.animateTo(
      to + _gutterWidth,
      duration: duration,
      curve: curve,
    );
  }

  @override
  ScrollDirection get userScrollDirection => _delegate.userScrollDirection;

  @override
  bool get allowImplicitScrolling => _delegate.allowImplicitScrolling;

  @override
  void dispose() {
    _delegate.removeListener(notifyListeners);
    super.dispose();
  }

}

class _ScrollingGutter extends SingleChildRenderObjectWidget {

  final ScrollController horizontalScroller;
  final ValueChanged<double>? onWidthMeasured;

  const _ScrollingGutter({
    required this.horizontalScroller,
    this.onWidthMeasured,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScrollingGutter(
      horizontalScroller: horizontalScroller,
      onWidthMeasured: onWidthMeasured,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderScrollingGutter renderObject) {
    renderObject
      ..horizontalScroller = horizontalScroller
      ..onWidthMeasured = onWidthMeasured;
  }

}

class _RenderScrollingGutter extends RenderShiftedBox {

  ScrollController _horizontalScroller;
  ValueChanged<double>? _onWidthMeasured;
  double _lastMeasuredWidth = 0.0;

  _RenderScrollingGutter({
    required ScrollController horizontalScroller,
    ValueChanged<double>? onWidthMeasured,
    RenderBox? child,
  })  : _horizontalScroller = horizontalScroller,
        _onWidthMeasured = onWidthMeasured,
        super(child);

  ScrollController get horizontalScroller => _horizontalScroller;
  set horizontalScroller(ScrollController value) {
    if (_horizontalScroller == value) return;
    if (attached) {
      _horizontalScroller.removeListener(_handleScroll);
    }
    _horizontalScroller = value;
    if (attached) {
      _horizontalScroller.addListener(_handleScroll);
    }
    markNeedsLayout();
  }

  set onWidthMeasured(ValueChanged<double>? value) {
    _onWidthMeasured = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _horizontalScroller.addListener(_handleScroll);
  }

  @override
  void detach() {
    _horizontalScroller.removeListener(_handleScroll);
    super.detach();
  }

  void _handleScroll() {
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (child == null) {
      size = Size(0.0, constraints.maxHeight);
      return;
    }

    child!.layout(constraints.loosen(), parentUsesSize: true);
    final double naturalWidth = child!.size.width;
    if (naturalWidth != _lastMeasuredWidth) {
      _lastMeasuredWidth = naturalWidth;
      _onWidthMeasured?.call(naturalWidth);
    }

    final double scrollOffset =
        _horizontalScroller.hasClients ? _horizontalScroller.offset : 0.0;
    final double visibleWidth = max(0.0, naturalWidth - scrollOffset);

    size = Size(visibleWidth, constraints.maxHeight);

    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    childParentData.offset = Offset(-scrollOffset, 0.0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.width <= 0) {
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTWH(0, 0, size.width, size.height),
      (PaintingContext context, Offset offset) {
        final BoxParentData childParentData = child!.parentData! as BoxParentData;
        context.paintChild(child!, offset + childParentData.offset);
      },
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null || size.width <= 0) {
      return false;
    }
    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child!.hitTest(result, position: transformed);
      },
    );
  }

}