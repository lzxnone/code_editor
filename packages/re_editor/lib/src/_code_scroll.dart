part of re_editor;

const double _kScrollbarThickness = 8.0;

class _CodeScrollable extends StatefulWidget {

  final AxisDirection axisDirection;
  final ScrollController? controller;
  final ViewportBuilder viewportBuilder;
  final CodeScrollbarBuilder? scrollbarBuilder;

  const _CodeScrollable({
    super.key,
    required this.axisDirection,
    this.controller,
    required this.viewportBuilder,
    this.scrollbarBuilder,
  });

  @override
  State<_CodeScrollable> createState() => _CodeScrollableState();

}

class _CodeScrollableState extends State<_CodeScrollable> {

  CodeEditorScrollController? _effectiveController;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller is CodeEditorScrollController) {
      _effectiveController = widget.controller as CodeEditorScrollController;
    } else {
      _effectiveController = CodeEditorScrollController(
        delegate: widget.controller,
        initialScrollOffset: widget.controller?.initialScrollOffset ?? 0.0,
        keepScrollOffset: widget.controller?.keepScrollOffset ?? true,
      );
    }
  }

  @override
  void didUpdateWidget(_CodeScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_effectiveController != null && _effectiveController!.delegate != null) {
        _effectiveController!.dispose();
      }
      _initController();
    }
  }

  @override
  void dispose() {
    if (_effectiveController != null && _effectiveController!.delegate != null) {
      _effectiveController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      excludeFromSemantics: true,
      controller: _effectiveController,
      scrollBehavior: _ScrollBehavior(widget.scrollbarBuilder),
      viewportBuilder: widget.viewportBuilder,
      axisDirection: widget.axisDirection,
      physics: const ClampingScrollPhysics(),
    );
  }

}

class _ScrollBehavior extends MaterialScrollBehavior {

  final _ScrollPhysics physics;
  final CodeScrollbarBuilder? scrollbarBuilder;

  _ScrollBehavior(this.scrollbarBuilder) : physics = _ScrollPhysics();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    final Widget? scrollbar = scrollbarBuilder?.call(context, child, details);
    if (scrollbar != null) {
      return scrollbar;
    }
    final ScrollbarOrientation? orientation;
    if (details.direction == AxisDirection.down) {
      orientation = ScrollbarOrientation.right;
    } else if (details.direction == AxisDirection.right) {
      orientation = ScrollbarOrientation.bottom;
    } else {
      orientation = null;
    }
    if (kIsAndroid || kIsIOS) {
      return Scrollbar(
        controller: details.controller,
        scrollbarOrientation: orientation,
        thumbVisibility: details.direction == AxisDirection.down,
        child: child,
      );
    }
    return _RawScrollbar(
      physics: physics,
      controller: details.controller ?? ScrollController(),
      scrollbarOrientation: orientation,
      thumbVisibility: details.direction == AxisDirection.down,
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return physics;
  }

}

class _RawScrollbar extends RawScrollbar {

  final _ScrollPhysics physics;

  const _RawScrollbar({
    required this.physics,
    required Widget child,
    required ScrollController controller,
    ScrollbarOrientation? scrollbarOrientation,
    required bool thumbVisibility,
  }) : super(
    controller: controller,
    scrollbarOrientation: scrollbarOrientation,
    thumbVisibility: thumbVisibility,
    thickness: _kScrollbarThickness,
    radius: const Radius.circular(10),
    crossAxisMargin: 2,
    child: child,
  );

  @override
  RawScrollbarState<_RawScrollbar> createState() => _RawScrollbarState();

}

class _RawScrollbarState extends RawScrollbarState<_RawScrollbar> {

  Offset? downPosition;
  double? downOffset;

  @override
  void handleThumbPressStart(ui.Offset localPosition) {
    downPosition = localPosition;
    downOffset = widget.controller!.offset;
    super.handleThumbPressStart(localPosition);
  }

  @override
  void handleThumbPressUpdate(Offset localPosition) {
    if (getScrollbarDirection() == Axis.vertical) {
      widget.physics.setScrollPosition(downOffset! + scrollbarPainter.getTrackToScroll(localPosition.dy - downPosition!.dy));
    }
    super.handleThumbPressUpdate(localPosition);
  }

}

// ignore: must_be_immutable
class _ScrollPhysics extends ScrollPhysics {

  double? _position;

  void setScrollPosition(double position) {
    _position = position;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (_position == null) {
      return super.applyBoundaryConditions(position, value);
    }
    return value - _position!;
  }

}