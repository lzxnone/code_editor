part of re_editor;

const double _kScrollbarThickness = 8.0;

class _CodeScrollable extends StatefulWidget {

  final AxisDirection axisDirection;
  final ScrollController? controller;
  final ScrollController? bidirectionalHorizontalController;
  final bool enableDrag;
  final ViewportBuilder viewportBuilder;
  final CodeScrollbarBuilder? scrollbarBuilder;

  const _CodeScrollable({
    super.key,
    required this.axisDirection,
    this.controller,
    this.bidirectionalHorizontalController,
    this.enableDrag = true,
    required this.viewportBuilder,
    this.scrollbarBuilder,
  });

  @override
  State<_CodeScrollable> createState() => _CodeScrollableState();

}

class _CodeScrollableState extends State<_CodeScrollable> {

  CodeEditorScrollController? _effectiveController;

  ScrollHoldController? _verticalHold;
  ScrollHoldController? _horizontalHold;
  Drag? _verticalDrag;
  Drag? _horizontalDrag;

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
      _handlePanCancel();
      if (_effectiveController != null && _effectiveController!.delegate != null) {
        _effectiveController!.dispose();
      }
      _initController();
    }
    if (widget.bidirectionalHorizontalController != oldWidget.bidirectionalHorizontalController) {
      _handlePanCancel();
    }
  }

  @override
  void dispose() {
    _handlePanCancel();
    if (_effectiveController != null && _effectiveController!.delegate != null) {
      _effectiveController!.dispose();
    }
    super.dispose();
  }

  ScrollPosition? get _verticalPosition {
    if (_effectiveController != null && _effectiveController!.positions.isNotEmpty) {
      return _effectiveController!.positions.first;
    }
    return null;
  }

  ScrollPosition? get _horizontalPosition {
    final hController = widget.bidirectionalHorizontalController;
    if (hController != null && hController.positions.isNotEmpty) {
      return hController.positions.first;
    }
    return null;
  }

  void _handlePanDown(DragDownDetails details) {
    if (_effectiveController?.isPinchLocked == true) {
      return;
    }
    final vPos = _verticalPosition;
    final hPos = _horizontalPosition;
    _verticalHold = vPos?.hold(_disposeVerticalHold);
    _horizontalHold = hPos?.hold(_disposeHorizontalHold);
  }

  void _handlePanStart(DragStartDetails details) {
    if (_effectiveController?.isPinchLocked == true) {
      _handlePanCancel();
      return;
    }
    final vPos = _verticalPosition;
    final hPos = _horizontalPosition;
    _verticalDrag = vPos?.drag(details, _disposeVerticalDrag);
    _horizontalDrag = hPos?.drag(details, _disposeHorizontalDrag);
    _disposeVerticalHold();
    _disposeHorizontalHold();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_effectiveController?.isPinchLocked == true) {
      _handlePanCancel();
      return;
    }
    if (_verticalDrag != null) {
      final verticalDetails = DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(0.0, details.delta.dy),
        primaryDelta: details.delta.dy,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      );
      _verticalDrag?.update(verticalDetails);
    }
    if (_horizontalDrag != null) {
      final horizontalDetails = DragUpdateDetails(
        sourceTimeStamp: details.sourceTimeStamp,
        delta: Offset(details.delta.dx, 0.0),
        primaryDelta: details.delta.dx,
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      );
      _horizontalDrag?.update(horizontalDetails);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    final double dx = details.velocity.pixelsPerSecond.dx;
    final double dy = details.velocity.pixelsPerSecond.dy;

    final vDrag = _verticalDrag;
    final hDrag = _horizontalDrag;
    _verticalDrag = null;
    _horizontalDrag = null;

    if (vDrag != null) {
      final verticalDetails = DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(0.0, dy)),
        primaryVelocity: dy,
      );
      vDrag.end(verticalDetails);
    }
    if (hDrag != null) {
      final horizontalDetails = DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(dx, 0.0)),
        primaryVelocity: dx,
      );
      hDrag.end(horizontalDetails);
    }
  }

  void _handlePanCancel() {
    final vHold = _verticalHold;
    final hHold = _horizontalHold;
    final vDrag = _verticalDrag;
    final hDrag = _horizontalDrag;
    _verticalHold = null;
    _horizontalHold = null;
    _verticalDrag = null;
    _horizontalDrag = null;
    vHold?.cancel();
    hHold?.cancel();
    vDrag?.cancel();
    hDrag?.cancel();
  }

  void _disposeVerticalHold() {
    _verticalHold = null;
  }

  void _disposeHorizontalHold() {
    _horizontalHold = null;
  }

  void _disposeVerticalDrag() {
    _verticalDrag = null;
  }

  void _disposeHorizontalDrag() {
    _horizontalDrag = null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isBidirectional = widget.bidirectionalHorizontalController != null;
    final Widget scrollable = Scrollable(
      excludeFromSemantics: true,
      controller: _effectiveController,
      scrollBehavior: _ScrollBehavior(
        widget.scrollbarBuilder,
        enableDrag: !isBidirectional && widget.enableDrag,
      ),
      viewportBuilder: widget.viewportBuilder,
      axisDirection: widget.axisDirection,
      physics: const ClampingScrollPhysics(),
    );

    if (isBidirectional) {
      return RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => PanGestureRecognizer(
              supportedDevices: const <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.trackpad,
              },
            ),
            (PanGestureRecognizer instance) {
              instance
                ..onDown = _handlePanDown
                ..onStart = _handlePanStart
                ..onUpdate = _handlePanUpdate
                ..onEnd = _handlePanEnd
                ..onCancel = _handlePanCancel
                ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
            },
          ),
        },
        behavior: HitTestBehavior.opaque,
        child: scrollable,
      );
    }

    return scrollable;
  }

}

class _ScrollBehavior extends MaterialScrollBehavior {

  final _ScrollPhysics physics;
  final CodeScrollbarBuilder? scrollbarBuilder;
  final bool enableDrag;

  _ScrollBehavior(this.scrollbarBuilder, {this.enableDrag = true}) : physics = _ScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices =>
      enableDrag ? super.dragDevices : const <PointerDeviceKind>{};

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