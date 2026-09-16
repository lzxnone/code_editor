part of re_editor;

typedef CodeScrollbarBuilder = Widget Function(BuildContext context, Widget child, ScrollableDetails details);

/// Custom ScrollPosition for code editor that prevents blocking child pointers
/// during ballistic scrolling (inertia).
///
/// In standard Flutter, [ScrollPosition.shouldIgnorePointer] returns true during
/// ballistic activity, which causes [Scrollable] to wrap its viewport in an
/// [IgnorePointer(ignoring: true)]. In nested bidirectional scrolling (outer vertical,
/// inner horizontal), this completely blocked the inner horizontal scrollable from
/// receiving the initial touch-down when vertical was scrolling, forcing the user
/// to swipe twice horizontally to start horizontal scrolling. Overriding
/// [shouldIgnorePointer] to return false allows bidirectional scroll gestures to
/// seamlessly take over on the very first swipe.

class CodeEditorScrollPosition extends ScrollPositionWithSingleContext {
  CodeEditorScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  bool _isPinchLocked = false;
  bool get isPinchLocked => _isPinchLocked;
  set isPinchLocked(bool value) {
    if (_isPinchLocked == value) return;
    _isPinchLocked = value;
    if (value) {
      stopScrolling();
    }
  }

  @override
  void applyUserOffset(double delta) {
    if (_isPinchLocked) {
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  bool get shouldIgnorePointer => false;

  /// Immediately stop any ongoing scrolling animation or ballistic activity.
  void stopScrolling() {
    if (activity?.isScrolling == true) {
      goIdle();
    }
  }
}

/// A [ScrollController] that creates [CodeEditorScrollPosition] for smooth,
/// non-blocking bidirectional scrolling. Supports delegating to an external
/// [ScrollController] if provided.
class CodeEditorScrollController extends ScrollController {
  final ScrollController? delegate;

  CodeEditorScrollController({
    this.delegate,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
  });

  bool _isPinchLocked = false;
  bool get isPinchLocked => _isPinchLocked;
  set isPinchLocked(bool value) {
    if (_isPinchLocked == value) return;
    _isPinchLocked = value;
    for (final position in positions) {
      if (position is CodeEditorScrollPosition) {
        position.isPinchLocked = value;
      }
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    final position = CodeEditorScrollPosition(
      physics: physics,
      context: context,
      initialPixels: delegate?.initialScrollOffset ?? initialScrollOffset,
      keepScrollOffset: delegate?.keepScrollOffset ?? keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: delegate?.debugLabel ?? debugLabel,
    );
    position.isPinchLocked = _isPinchLocked;
    return position;
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    if (position is CodeEditorScrollPosition) {
      position.isPinchLocked = _isPinchLocked;
    }
    if (delegate != null && !delegate!.positions.contains(position)) {
      delegate!.attach(position);
    }
  }

  @override
  void detach(ScrollPosition position) {
    if (delegate != null && delegate!.positions.contains(position)) {
      delegate!.detach(position);
    }
    super.detach(position);
  }

  /// Immediately stop any ongoing scrolling animation or ballistic activity on all attached positions.
  void stopScrolling() {
    for (final position in positions) {
      if (position is CodeEditorScrollPosition) {
        position.stopScrolling();
      } else if (position is ScrollPositionWithSingleContext) {
        position.goIdle();
      }
    }
  }
}

class CodeScrollController {

  final ScrollController verticalScroller;
  final ScrollController horizontalScroller;

  GlobalKey? _editorKey;

  CodeScrollController({
    ScrollController? verticalScroller,
    ScrollController? horizontalScroller,
  }) : verticalScroller = verticalScroller ?? CodeEditorScrollController(),
    horizontalScroller = horizontalScroller ?? CodeEditorScrollController();

  void makeCenterIfInvisible(CodeLinePosition position) {
    _render?.makePositionCenterIfInvisible(position);
  }

  void makeVisible(CodeLinePosition position) {
    _render?.makePositionVisible(position);
  }

  void bindEditor(GlobalKey key) {
    _editorKey = key;
  }

  _CodeFieldRender? get _render => _editorKey?.currentContext?.findRenderObject() as _CodeFieldRender?;

  void dispose() {
    _editorKey = null;
  }

}