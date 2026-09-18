import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_font.dart';
import '../../models/editor_theme.dart';
import '../../models/git_model.dart';
import '../../providers/git_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/file_icon_utils.dart';
import '../../utils/git_diff_helper.dart';
import '../../utils/syntax_highlight_helper.dart';

/// 独立的 Git Diff 文件差异对比页面
class GitDiffPage extends StatefulWidget {
  final GitFileStatus file;
  final GitProvider gitProvider;

  const GitDiffPage({
    super.key,
    required this.file,
    required this.gitProvider,
  });

  @override
  State<GitDiffPage> createState() => _GitDiffPageState();
}

class _GitDiffPageState extends State<GitDiffPage> {
  bool _isLoading = true;
  String? _errorMessage;
  SplitDiffResult? _splitResult;
  List<UnifiedDiffLine> _unifiedLines = const [];

  bool _isSplitMode = true;
  double _splitRatio = 0.5;

  // 缩放字号状态（初始使用编辑区字号，双屏同步缩放，单屏独立，后续缩放不影响编辑区和设置）
  double? _splitFontSize;
  double? _unifiedFontSize;

  // 双屏分屏手势状态管理（基于 Listener 原生指针跟踪，对标 code_editor_widget 彻底根除抖动）
  final Map<int, Offset> _splitPointers = {};
  int? _splitPointer1;
  int? _splitPointer2;
  double? _splitInitialDistance;
  double? _splitInitialFontSize;
  double? _splitActiveZoomFontSize;
  Offset? _splitInitialLocalFocal;
  Offset? _splitCurrentLocalFocal;
  double _splitFocalLineContinuous = 0.0;
  double _splitFocalCharContinuous = 0.0;
  bool _isSplitPinching = false;
  Offset? _splitLastPanPos;
  VelocityTracker? _splitVelocityTracker;
  bool _isDraggingDivider = false;

  // 单屏内联手势状态管理
  final Map<int, Offset> _unifiedPointers = {};
  int? _unifiedPointer1;
  int? _unifiedPointer2;
  double? _unifiedInitialDistance;
  double? _unifiedInitialFontSize;
  double? _unifiedActiveZoomFontSize;
  Offset? _unifiedInitialLocalFocal;
  Offset? _unifiedCurrentLocalFocal;
  double _unifiedFocalLineContinuous = 0.0;
  double _unifiedFocalCharContinuous = 0.0;
  bool _isUnifiedPinching = false;
  Offset? _unifiedLastPanPos;
  VelocityTracker? _unifiedVelocityTracker;

  // 左屏滚动控制器（垂直、水平、行号）
  late final ScrollController _leftVController;
  late final ScrollController _leftHController;
  late final ScrollController _leftGutterController;

  // 右屏滚动控制器（垂直、水平、行号）
  late final ScrollController _rightVController;
  late final ScrollController _rightHController;
  late final ScrollController _rightGutterController;

  // 单屏内联滚动控制器
  late final ScrollController _unifiedVController;
  late final ScrollController _unifiedHController;
  late final ScrollController _unifiedGutterController;

  bool _syncingSplit = false;
  bool _syncingUnified = false;

  int _currentChangeIndex = -1;
  late GitFileStatus _currentFile;

  // 语法高亮缓存（key: 'fontSize-themeId-code'）
  final Map<String, TextSpan> _highlightSpanCache = {};

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;

    _leftVController = ScrollController();
    _leftHController = ScrollController();
    _leftGutterController = ScrollController();

    _rightVController = ScrollController();
    _rightHController = ScrollController();
    _rightGutterController = ScrollController();

    _unifiedVController = ScrollController();
    _unifiedHController = ScrollController();
    _unifiedGutterController = ScrollController();

    // 双屏同步滚动监听（左栏与右栏、行号区垂直与水平全向无缝联动）
    _leftVController.addListener(_onLeftVScrolled);
    _leftGutterController.addListener(_onLeftGutterScrolled);
    _leftHController.addListener(_onLeftHScrolled);

    _rightVController.addListener(_onRightVScrolled);
    _rightGutterController.addListener(_onRightGutterScrolled);
    _rightHController.addListener(_onRightHScrolled);

    // 单屏内联视图代码区与行号区垂直同步滚动
    _unifiedVController.addListener(_onUnifiedVScrolled);
    _unifiedGutterController.addListener(_onUnifiedGutterScrolled);

    _loadDiff();
  }

  void _onLeftVScrolled() {
    if (_syncingSplit) return;
    _syncingSplit = true;
    final offset = _leftVController.offset;
    if (_leftGutterController.hasClients) {
      _leftGutterController.jumpTo(offset.clamp(0.0, _leftGutterController.position.maxScrollExtent));
    }
    if (_rightVController.hasClients) {
      _rightVController.jumpTo(offset.clamp(0.0, _rightVController.position.maxScrollExtent));
    }
    if (_rightGutterController.hasClients) {
      _rightGutterController.jumpTo(offset.clamp(0.0, _rightGutterController.position.maxScrollExtent));
    }
    _syncingSplit = false;
  }

  void _onLeftGutterScrolled() {
    if (_syncingSplit || !_leftVController.hasClients) return;
    _syncingSplit = true;
    _leftVController.jumpTo(_leftGutterController.offset.clamp(0.0, _leftVController.position.maxScrollExtent));
    _syncingSplit = false;
  }

  void _onLeftHScrolled() {
    if (_syncingSplit) return;
    _syncingSplit = true;
    final offset = _leftHController.offset;
    if (_rightHController.hasClients) {
      _rightHController.jumpTo(offset.clamp(0.0, _rightHController.position.maxScrollExtent));
    }
    _syncingSplit = false;
  }

  void _onRightVScrolled() {
    if (_syncingSplit) return;
    _syncingSplit = true;
    final offset = _rightVController.offset;
    if (_rightGutterController.hasClients) {
      _rightGutterController.jumpTo(offset.clamp(0.0, _rightGutterController.position.maxScrollExtent));
    }
    if (_leftVController.hasClients) {
      _leftVController.jumpTo(offset.clamp(0.0, _leftVController.position.maxScrollExtent));
    }
    if (_leftGutterController.hasClients) {
      _leftGutterController.jumpTo(offset.clamp(0.0, _leftGutterController.position.maxScrollExtent));
    }
    _syncingSplit = false;
  }

  void _onRightGutterScrolled() {
    if (_syncingSplit || !_rightVController.hasClients) return;
    _syncingSplit = true;
    _rightVController.jumpTo(_rightGutterController.offset.clamp(0.0, _rightVController.position.maxScrollExtent));
    _syncingSplit = false;
  }

  void _onRightHScrolled() {
    if (_syncingSplit) return;
    _syncingSplit = true;
    final offset = _rightHController.offset;
    if (_leftHController.hasClients) {
      _leftHController.jumpTo(offset.clamp(0.0, _leftHController.position.maxScrollExtent));
    }
    _syncingSplit = false;
  }

  void _onUnifiedVScrolled() {
    if (_syncingUnified || !_unifiedGutterController.hasClients) return;
    _syncingUnified = true;
    _unifiedGutterController.jumpTo(_unifiedVController.offset.clamp(0.0, _unifiedGutterController.position.maxScrollExtent));
    _syncingUnified = false;
  }

  void _onUnifiedGutterScrolled() {
    if (_syncingUnified || !_unifiedVController.hasClients) return;
    _syncingUnified = true;
    _unifiedVController.jumpTo(_unifiedGutterController.offset.clamp(0.0, _unifiedVController.position.maxScrollExtent));
    _syncingUnified = false;
  }

  @override
  void dispose() {
    _leftVController.removeListener(_onLeftVScrolled);
    _leftGutterController.removeListener(_onLeftGutterScrolled);
    _leftHController.removeListener(_onLeftHScrolled);
    _leftVController.dispose();
    _leftHController.dispose();
    _leftGutterController.dispose();

    _rightVController.removeListener(_onRightVScrolled);
    _rightGutterController.removeListener(_onRightGutterScrolled);
    _rightHController.removeListener(_onRightHScrolled);
    _rightVController.dispose();
    _rightHController.dispose();
    _rightGutterController.dispose();

    _unifiedVController.removeListener(_onUnifiedVScrolled);
    _unifiedGutterController.removeListener(_onUnifiedGutterScrolled);
    _unifiedVController.dispose();
    _unifiedHController.dispose();
    _unifiedGutterController.dispose();

    super.dispose();
  }

  Future<void> _loadDiff() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repoPath = widget.gitProvider.currentRepoPath;
    if (repoPath == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '未选择 Git 仓库';
      });
      return;
    }

    try {
      final baseContent = await widget.gitProvider.gitService.getFileBaseContent(repoPath, _currentFile);
      final modifiedContent = await widget.gitProvider.gitService.getFileModifiedContent(repoPath, _currentFile);

      // 大文件采用后台 Isolate 计算双屏与单屏差异，彻底杜绝主 UI 线程卡顿
      final isLarge = (baseContent != null && baseContent.length > 32768) || modifiedContent.length > 32768;
      final diffData = isLarge
          ? await compute<_DiffDataInput, _DiffDataOutput>(
              _computeDiffPageData,
              _DiffDataInput(baseContent ?? '', modifiedContent),
            )
          : _computeDiffPageData(_DiffDataInput(baseContent ?? '', modifiedContent));

      if (mounted) {
        setState(() {
          _splitResult = diffData.split;
          _unifiedLines = diffData.unified;
          _isLoading = false;
          _currentChangeIndex = diffData.split.changeRowIndices.isNotEmpty ? 0 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _navigateToNextChange(double splitRowHeight, double unifiedRowHeight) {
    final split = _splitResult;
    if (split == null || split.changeRowIndices.isEmpty) return;

    setState(() {
      _currentChangeIndex = (_currentChangeIndex + 1) % split.changeRowIndices.length;
    });
    _scrollToChangeRow(split.changeRowIndices[_currentChangeIndex], splitRowHeight, unifiedRowHeight);
  }

  void _navigateToPrevChange(double splitRowHeight, double unifiedRowHeight) {
    final split = _splitResult;
    if (split == null || split.changeRowIndices.isEmpty) return;

    setState(() {
      _currentChangeIndex = (_currentChangeIndex - 1 + split.changeRowIndices.length) % split.changeRowIndices.length;
    });
    _scrollToChangeRow(split.changeRowIndices[_currentChangeIndex], splitRowHeight, unifiedRowHeight);
  }

  void _scrollToChangeRow(int rowIndex, double splitRowHeight, double unifiedRowHeight) {
    if (_isSplitMode) {
      final targetOffset = rowIndex * splitRowHeight;
      if (_leftVController.hasClients) {
        final maxScroll = _leftVController.position.maxScrollExtent;
        _leftVController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
      if (_rightVController.hasClients) {
        final maxScroll = _rightVController.position.maxScrollExtent;
        _rightVController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    } else {
      if (_unifiedVController.hasClients) {
        final maxScroll = _unifiedVController.position.maxScrollExtent;
        final targetOffset = rowIndex * unifiedRowHeight;
        _unifiedVController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // --- 双屏分屏指针手势处理（对标 code_editor_widget.dart，彻底消除抖动并实现双屏同步） ---
  void _handleSplitPointerDown(
    PointerDownEvent event,
    double currentFontSize,
    double rowH,
    double charW,
    double leftWidth,
    double dividerWidth,
  ) {
    _splitPointers[event.pointer] = event.position;
    if (_splitPointers.length == 1) {
      final localX = event.localPosition.dx;
      if (localX >= leftWidth && localX <= leftWidth + dividerWidth) {
        _isDraggingDivider = true;
      } else {
        _isDraggingDivider = false;
        _splitLastPanPos = event.position;
        _splitVelocityTracker = VelocityTracker.withKind(event.kind);
        _splitVelocityTracker?.addPosition(event.timeStamp, event.position);
      }
    } else if (_splitPointers.length >= 2 && !_isSplitPinching) {
      _isDraggingDivider = false;
      final keys = _splitPointers.keys.toList();
      _splitPointer1 = keys[0];
      _splitPointer2 = keys[1];

      final p1 = _splitPointers[_splitPointer1]!;
      final p2 = _splitPointers[_splitPointer2]!;

      _splitInitialDistance = (p1 - p2).distance;
      _splitInitialFontSize = _splitActiveZoomFontSize ?? currentFontSize;
      _splitActiveZoomFontSize = _splitInitialFontSize;

      final globalFocal = (p1 + p2) / 2;
      final renderBox = context.findRenderObject() as RenderBox?;
      final localFocal = renderBox != null ? renderBox.globalToLocal(globalFocal) : globalFocal;
      _splitInitialLocalFocal = localFocal;

      final curV = _leftVController.hasClients ? _leftVController.offset : 0.0;
      final curH = _leftHController.hasClients ? _leftHController.offset : 0.0;

      _splitFocalLineContinuous = (curV + localFocal.dy) / math.max(1.0, rowH);
      // 水平锚定：若当前未横向滚动（偏移 <= 4px），缩放时严格锁定在 0，
      // 避免全局屏幕触摸坐标算入 targetScrollH 导致代码首部字符（如 -I、#、关键字等）被意外向右推入视口外
      _splitFocalCharContinuous = curH <= 4.0 ? 0.0 : curH / math.max(1.0, charW);

      _splitLastPanPos = null;
      setState(() {
        _isSplitPinching = true;
      });
    }
  }

  void _handleSplitPointerMove(PointerMoveEvent event) {
    if (!_splitPointers.containsKey(event.pointer)) return;
    _splitPointers[event.pointer] = event.position;

    if (_isSplitPinching) {
      if (_splitPointer1 != null &&
          _splitPointer2 != null &&
          _splitPointers.containsKey(_splitPointer1) &&
          _splitPointers.containsKey(_splitPointer2) &&
          _splitInitialDistance != null &&
          _splitInitialDistance! > 10.0 &&
          _splitInitialFontSize != null &&
          _splitInitialLocalFocal != null) {
        final p1 = _splitPointers[_splitPointer1]!;
        final p2 = _splitPointers[_splitPointer2]!;

        final currentDistance = (p1 - p2).distance;
        final rawScale = currentDistance / _splitInitialDistance!;

        final minScale = SettingsProvider.minFontSize / _splitInitialFontSize!;
        final maxScale = (SettingsProvider.maxFontSize + 8.0) / _splitInitialFontSize!;
        final clampedScale = rawScale.clamp(minScale * 0.9, maxScale * 1.1);

        final continuousFontSize = ((_splitInitialFontSize! * clampedScale) * 10).round() / 10.0;
        final newFontSize = continuousFontSize.clamp(
          SettingsProvider.minFontSize,
          SettingsProvider.maxFontSize + 8.0,
        );

        final newRowH = (newFontSize * 1.45 + 4.0).roundToDouble();
        final newCharW = newFontSize * 0.60;

        final currentGlobalFocal = (p1 + p2) / 2;
        final renderBox = context.findRenderObject() as RenderBox?;
        final currentLocalFocal = renderBox != null
            ? renderBox.globalToLocal(currentGlobalFocal)
            : currentGlobalFocal;
        _splitCurrentLocalFocal = currentLocalFocal;

        final targetScrollV = _splitFocalLineContinuous * newRowH - currentLocalFocal.dy;
        final targetScrollH = _splitFocalCharContinuous <= 0.0
            ? 0.0
            : _splitFocalCharContinuous * newCharW;

        _jumpSplitScroll(targetScrollV, targetScrollH);

        if (_splitFontSize != newFontSize) {
          setState(() {
            _splitFontSize = newFontSize;
            _splitActiveZoomFontSize = newFontSize;
          });
        }
      }
    } else if (_splitPointers.length == 1 && !_isSplitPinching && !_isDraggingDivider) {
      _splitVelocityTracker?.addPosition(event.timeStamp, event.position);
      final curPos = event.position;
      if (_splitLastPanPos != null) {
        final delta = curPos - _splitLastPanPos!;
        _scrollSplitByDelta(delta);
      }
      _splitLastPanPos = curPos;
    }
  }

  void _finishSplitPinchZoom() {
    final finalSize = _splitActiveZoomFontSize;
    if (finalSize != null) {
      final double targetFontSize = finalSize
          .clamp(SettingsProvider.minFontSize, SettingsProvider.maxFontSize + 8.0)
          .roundToDouble();
      _splitFontSize = targetFontSize;
      final finalH = (targetFontSize * 1.45 + 4.0).roundToDouble();
      final finalW = targetFontSize * 0.60;
      final currentLocalFocal = _splitCurrentLocalFocal ?? _splitInitialLocalFocal;
      if (currentLocalFocal != null) {
        final targetScrollV = _splitFocalLineContinuous * finalH - currentLocalFocal.dy;
        final targetScrollH = _splitFocalCharContinuous <= 0.0
            ? 0.0
            : _splitFocalCharContinuous * finalW;
        _jumpSplitScroll(targetScrollV, targetScrollH);
      }
    }
    setState(() {
      _isSplitPinching = false;
      _splitPointer1 = null;
      _splitPointer2 = null;
      _splitInitialDistance = null;
      _splitInitialFontSize = null;
      _splitActiveZoomFontSize = null;
      _splitInitialLocalFocal = null;
      _splitCurrentLocalFocal = null;
    });
  }

  void _handleSplitPointerUp(PointerUpEvent event) {
    _splitPointers.remove(event.pointer);
    if (_isSplitPinching &&
        (_splitPointers.length < 2 || event.pointer == _splitPointer1 || event.pointer == _splitPointer2)) {
      _finishSplitPinchZoom();
    } else if (!_isSplitPinching && _splitPointers.isEmpty) {
      if (!_isDraggingDivider && _splitVelocityTracker != null) {
        final estimate = _splitVelocityTracker!.getVelocity();
        final velocity = estimate.pixelsPerSecond;
        _flingSplit(velocity);
      }
      _isDraggingDivider = false;
      _splitLastPanPos = null;
    }
  }

  void _handleSplitPointerCancel(PointerCancelEvent event) {
    _splitPointers.remove(event.pointer);
    if (_isSplitPinching) {
      _finishSplitPinchZoom();
    }
    _isDraggingDivider = false;
    _splitLastPanPos = null;
  }

  void _jumpSplitScroll(double targetV, double targetH) {
    _syncingSplit = true;
    if (_leftVController.hasClients) {
      final maxV = _leftVController.position.maxScrollExtent;
      final clampedV = targetV.clamp(0.0, math.max(maxV, targetV)).toDouble();
      _leftVController.jumpTo(clampedV);
      if (_leftGutterController.hasClients) _leftGutterController.jumpTo(clampedV);
    }
    if (_rightVController.hasClients) {
      final maxV = _rightVController.position.maxScrollExtent;
      final clampedV = targetV.clamp(0.0, math.max(maxV, targetV)).toDouble();
      _rightVController.jumpTo(clampedV);
      if (_rightGutterController.hasClients) _rightGutterController.jumpTo(clampedV);
    }
    if (_leftHController.hasClients) {
      final maxH = _leftHController.position.maxScrollExtent;
      final clampedH = targetH.clamp(0.0, math.max(maxH, targetH)).toDouble();
      _leftHController.jumpTo(clampedH);
    }
    if (_rightHController.hasClients) {
      final maxH = _rightHController.position.maxScrollExtent;
      final clampedH = targetH.clamp(0.0, math.max(maxH, targetH)).toDouble();
      _rightHController.jumpTo(clampedH);
    }
    _syncingSplit = false;
  }

  void _scrollSplitByDelta(Offset delta) {
    _syncingSplit = true;
    if (_leftVController.hasClients) {
      final maxV = _leftVController.position.maxScrollExtent;
      final newV = (_leftVController.offset - delta.dy).clamp(0.0, maxV);
      _leftVController.jumpTo(newV);
      if (_leftGutterController.hasClients) _leftGutterController.jumpTo(newV);
    }
    if (_rightVController.hasClients) {
      final maxV = _rightVController.position.maxScrollExtent;
      final newV = (_rightVController.offset - delta.dy).clamp(0.0, maxV);
      _rightVController.jumpTo(newV);
      if (_rightGutterController.hasClients) _rightGutterController.jumpTo(newV);
    }
    if (_leftHController.hasClients) {
      final maxH = _leftHController.position.maxScrollExtent;
      final newH = (_leftHController.offset - delta.dx).clamp(0.0, maxH);
      _leftHController.jumpTo(newH);
    }
    if (_rightHController.hasClients) {
      final maxH = _rightHController.position.maxScrollExtent;
      final newH = (_rightHController.offset - delta.dx).clamp(0.0, maxH);
      _rightHController.jumpTo(newH);
    }
    _syncingSplit = false;
  }

  void _flingSplit(Offset velocity) {
    if (velocity.dy.abs() > 60) {
      if (_leftVController.hasClients) {
        final maxV = _leftVController.position.maxScrollExtent;
        final targetV = (_leftVController.offset - velocity.dy * 0.22).clamp(0.0, maxV);
        _leftVController.animateTo(
          targetV,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      if (_rightVController.hasClients) {
        final maxV = _rightVController.position.maxScrollExtent;
        final targetV = (_rightVController.offset - velocity.dy * 0.22).clamp(0.0, maxV);
        _rightVController.animateTo(
          targetV,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (velocity.dx.abs() > 60) {
      if (_leftHController.hasClients) {
        final maxH = _leftHController.position.maxScrollExtent;
        final targetH = (_leftHController.offset - velocity.dx * 0.22).clamp(0.0, maxH);
        _leftHController.animateTo(
          targetH,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      if (_rightHController.hasClients) {
        final maxH = _rightHController.position.maxScrollExtent;
        final targetH = (_rightHController.offset - velocity.dx * 0.22).clamp(0.0, maxH);
        _rightHController.animateTo(
          targetH,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  // --- 单屏内联指针手势处理 ---
  void _handleUnifiedPointerDown(
    PointerDownEvent event,
    double currentFontSize,
    double rowH,
    double charW,
  ) {
    _unifiedPointers[event.pointer] = event.position;
    if (_unifiedPointers.length == 1) {
      _unifiedLastPanPos = event.position;
      _unifiedVelocityTracker = VelocityTracker.withKind(event.kind);
      _unifiedVelocityTracker?.addPosition(event.timeStamp, event.position);
    } else if (_unifiedPointers.length >= 2 && !_isUnifiedPinching) {
      final keys = _unifiedPointers.keys.toList();
      _unifiedPointer1 = keys[0];
      _unifiedPointer2 = keys[1];

      final p1 = _unifiedPointers[_unifiedPointer1]!;
      final p2 = _unifiedPointers[_unifiedPointer2]!;

      _unifiedInitialDistance = (p1 - p2).distance;
      _unifiedInitialFontSize = _unifiedActiveZoomFontSize ?? currentFontSize;
      _unifiedActiveZoomFontSize = _unifiedInitialFontSize;

      final globalFocal = (p1 + p2) / 2;
      final renderBox = context.findRenderObject() as RenderBox?;
      final localFocal = renderBox != null ? renderBox.globalToLocal(globalFocal) : globalFocal;
      _unifiedInitialLocalFocal = localFocal;

      final curV = _unifiedVController.hasClients ? _unifiedVController.offset : 0.0;
      final curH = _unifiedHController.hasClients ? _unifiedHController.offset : 0.0;

      _unifiedFocalLineContinuous = (curV + localFocal.dy) / math.max(1.0, rowH);
      // 水平锚定：若当前未横向滚动（偏移 <= 4px），缩放时严格锁定在 0，
      // 避免全局屏幕触摸坐标算入 targetScrollH 导致代码首部字符被推入视口外
      _unifiedFocalCharContinuous = curH <= 4.0 ? 0.0 : curH / math.max(1.0, charW);

      _unifiedLastPanPos = null;
      setState(() {
        _isUnifiedPinching = true;
      });
    }
  }

  void _handleUnifiedPointerMove(PointerMoveEvent event) {
    if (!_unifiedPointers.containsKey(event.pointer)) return;
    _unifiedPointers[event.pointer] = event.position;

    if (_isUnifiedPinching) {
      if (_unifiedPointer1 != null &&
          _unifiedPointer2 != null &&
          _unifiedPointers.containsKey(_unifiedPointer1) &&
          _unifiedPointers.containsKey(_unifiedPointer2) &&
          _unifiedInitialDistance != null &&
          _unifiedInitialDistance! > 10.0 &&
          _unifiedInitialFontSize != null &&
          _unifiedInitialLocalFocal != null) {
        final p1 = _unifiedPointers[_unifiedPointer1]!;
        final p2 = _unifiedPointers[_unifiedPointer2]!;

        final currentDistance = (p1 - p2).distance;
        final rawScale = currentDistance / _unifiedInitialDistance!;

        final minScale = SettingsProvider.minFontSize / _unifiedInitialFontSize!;
        final maxScale = (SettingsProvider.maxFontSize + 8.0) / _unifiedInitialFontSize!;
        final clampedScale = rawScale.clamp(minScale * 0.9, maxScale * 1.1);

        final continuousFontSize = ((_unifiedInitialFontSize! * clampedScale) * 10).round() / 10.0;
        final newFontSize = continuousFontSize.clamp(
          SettingsProvider.minFontSize,
          SettingsProvider.maxFontSize + 8.0,
        );

        final newRowH = (newFontSize * 1.45 + 4.0).roundToDouble();
        final newCharW = newFontSize * 0.60;

        final currentGlobalFocal = (p1 + p2) / 2;
        final renderBox = context.findRenderObject() as RenderBox?;
        final currentLocalFocal = renderBox != null
            ? renderBox.globalToLocal(currentGlobalFocal)
            : currentGlobalFocal;
        _unifiedCurrentLocalFocal = currentLocalFocal;

        final targetScrollV = _unifiedFocalLineContinuous * newRowH - currentLocalFocal.dy;
        final targetScrollH = _unifiedFocalCharContinuous <= 0.0
            ? 0.0
            : _unifiedFocalCharContinuous * newCharW;

        _syncingUnified = true;
        if (_unifiedVController.hasClients) {
          final maxV = _unifiedVController.position.maxScrollExtent;
          final clampedV = targetScrollV.clamp(0.0, math.max(maxV, targetScrollV)).toDouble();
          _unifiedVController.jumpTo(clampedV);
          if (_unifiedGutterController.hasClients) _unifiedGutterController.jumpTo(clampedV);
        }
        if (_unifiedHController.hasClients) {
          final maxH = _unifiedHController.position.maxScrollExtent;
          final clampedH = targetScrollH.clamp(0.0, math.max(maxH, targetScrollH)).toDouble();
          _unifiedHController.jumpTo(clampedH);
        }
        _syncingUnified = false;

        if (_unifiedFontSize != newFontSize) {
          setState(() {
            _unifiedFontSize = newFontSize;
            _unifiedActiveZoomFontSize = newFontSize;
          });
        }
      }
    } else if (_unifiedPointers.length == 1 && !_isUnifiedPinching) {
      _unifiedVelocityTracker?.addPosition(event.timeStamp, event.position);
      final curPos = event.position;
      if (_unifiedLastPanPos != null) {
        final delta = curPos - _unifiedLastPanPos!;
        _syncingUnified = true;
        if (_unifiedVController.hasClients) {
          final maxV = _unifiedVController.position.maxScrollExtent;
          final newV = (_unifiedVController.offset - delta.dy).clamp(0.0, maxV);
          _unifiedVController.jumpTo(newV);
          if (_unifiedGutterController.hasClients) _unifiedGutterController.jumpTo(newV);
        }
        if (_unifiedHController.hasClients) {
          final maxH = _unifiedHController.position.maxScrollExtent;
          final newH = (_unifiedHController.offset - delta.dx).clamp(0.0, maxH);
          _unifiedHController.jumpTo(newH);
        }
        _syncingUnified = false;
      }
      _unifiedLastPanPos = curPos;
    }
  }

  void _finishUnifiedPinchZoom() {
    final finalSize = _unifiedActiveZoomFontSize;
    if (finalSize != null) {
      final double targetFontSize = finalSize
          .clamp(SettingsProvider.minFontSize, SettingsProvider.maxFontSize + 8.0)
          .roundToDouble();
      _unifiedFontSize = targetFontSize;
      final finalH = (targetFontSize * 1.45 + 4.0).roundToDouble();
      final finalW = targetFontSize * 0.60;
      final currentLocalFocal = _unifiedCurrentLocalFocal ?? _unifiedInitialLocalFocal;
      if (currentLocalFocal != null) {
        final targetScrollV = _unifiedFocalLineContinuous * finalH - currentLocalFocal.dy;
        final targetScrollH = _unifiedFocalCharContinuous <= 0.0
            ? 0.0
            : _unifiedFocalCharContinuous * finalW;
        _syncingUnified = true;
        if (_unifiedVController.hasClients) {
          final maxV = _unifiedVController.position.maxScrollExtent;
          final clampedV = targetScrollV.clamp(0.0, math.max(maxV, targetScrollV)).toDouble();
          _unifiedVController.jumpTo(clampedV);
          if (_unifiedGutterController.hasClients) _unifiedGutterController.jumpTo(clampedV);
        }
        if (_unifiedHController.hasClients) {
          final maxH = _unifiedHController.position.maxScrollExtent;
          final clampedH = targetScrollH.clamp(0.0, math.max(maxH, targetScrollH)).toDouble();
          _unifiedHController.jumpTo(clampedH);
        }
        _syncingUnified = false;
      }
    }
    setState(() {
      _isUnifiedPinching = false;
      _unifiedPointer1 = null;
      _unifiedPointer2 = null;
      _unifiedInitialDistance = null;
      _unifiedInitialFontSize = null;
      _unifiedActiveZoomFontSize = null;
      _unifiedInitialLocalFocal = null;
      _unifiedCurrentLocalFocal = null;
    });
  }

  void _handleUnifiedPointerUp(PointerUpEvent event) {
    _unifiedPointers.remove(event.pointer);
    if (_isUnifiedPinching &&
        (_unifiedPointers.length < 2 || event.pointer == _unifiedPointer1 || event.pointer == _unifiedPointer2)) {
      _finishUnifiedPinchZoom();
    } else if (!_isUnifiedPinching && _unifiedPointers.isEmpty) {
      if (_unifiedVelocityTracker != null) {
        final estimate = _unifiedVelocityTracker!.getVelocity();
        final velocity = estimate.pixelsPerSecond;
        if (velocity.dy.abs() > 60 && _unifiedVController.hasClients) {
          final maxV = _unifiedVController.position.maxScrollExtent;
          final targetV = (_unifiedVController.offset - velocity.dy * 0.22).clamp(0.0, maxV);
          _unifiedVController.animateTo(
            targetV,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
        if (velocity.dx.abs() > 60 && _unifiedHController.hasClients) {
          final maxH = _unifiedHController.position.maxScrollExtent;
          final targetH = (_unifiedHController.offset - velocity.dx * 0.22).clamp(0.0, maxH);
          _unifiedHController.animateTo(
            targetH,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      }
      _unifiedLastPanPos = null;
    }
  }

  void _handleUnifiedPointerCancel(PointerCancelEvent event) {
    _unifiedPointers.remove(event.pointer);
    if (_isUnifiedPinching) {
      _finishUnifiedPinchZoom();
    }
    _unifiedLastPanPos = null;
  }

  Widget _buildZoomBadge(EditorTheme editorTheme, double fontSize) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: editorTheme.isDark
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '${fontSize.toStringAsFixed(1)} pt',
            style: TextStyle(
              color: editorTheme.isDark ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _getHighlightedLineSpan({
    required String code,
    required TextStyle baseStyle,
    required EditorTheme editorTheme,
  }) {
    if (code.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }
    final key = '${baseStyle.fontSize}-${editorTheme.id}-$code';
    final cached = _highlightSpanCache[key];
    if (cached != null) {
      return cached;
    }
    final span = SyntaxHighlightHelper.highlightLine(
      code: code,
      filePath: _currentFile.relativePath,
      baseStyle: baseStyle,
      highlightTheme: editorTheme.highlightTheme,
    );
    _highlightSpanCache[key] = span;
    return span;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final split = _splitResult;

    // 获取独立的代码编辑器主题与默认字号配置
    EditorTheme editorTheme = EditorTheme.atomOneDark;
    double baseFontSize = 14.0;
    AppFontItem editorFont = AppFonts.editorJetBrainsMono;
    try {
      final settings = context.watch<SettingsProvider>();
      editorTheme = settings.editorTheme;
      baseFontSize = settings.fontSize;
      editorFont = settings.editorFont;
    } catch (_) {}

    // 字号计算：双屏统一使用 _splitFontSize，单屏内联使用 _unifiedFontSize，初始使用编辑区字号
    final splitFontSize = _splitFontSize ?? baseFontSize;
    final unifiedFontSize = _unifiedFontSize ?? baseFontSize;

    final splitRowHeight = (splitFontSize * 1.45 + 4.0).roundToDouble();
    final unifiedRowHeight = (unifiedFontSize * 1.45 + 4.0).roundToDouble();

    return Scaffold(
      backgroundColor: editorTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(
              FileIconUtils.getIcon(name: _currentFile.fileName, isDirectory: false),
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _currentFile.fileName,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (split != null && (split.additionsCount > 0 || split.deletionsCount > 0)) ...[
                        const SizedBox(width: 6),
                        if (split.additionsCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '+${split.additionsCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        if (split.deletionsCount > 0) ...[
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '-${split.deletionsCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  if (_currentFile.directoryPath.isNotEmpty)
                    Text(
                      _currentFile.directoryPath,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 上一处更改
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
            iconSize: 20,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            tooltip: l10n.gitDiffPrevChange,
            onPressed: (_splitResult?.changeRowIndices.isNotEmpty ?? false)
                ? () => _navigateToPrevChange(splitRowHeight, unifiedRowHeight)
                : null,
          ),
          // 下一处更改
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
            iconSize: 20,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: l10n.gitDiffNextChange,
            onPressed: (_splitResult?.changeRowIndices.isNotEmpty ?? false)
                ? () => _navigateToNextChange(splitRowHeight, unifiedRowHeight)
                : null,
          ),
          // 切换分栏 / 内联
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 16,
            iconSize: 18,
            icon: Icon(_isSplitMode ? Icons.view_agenda_outlined : Icons.vertical_split_outlined),
            tooltip: _isSplitMode ? l10n.gitDiffUnifiedView : l10n.gitDiffSplitView,
            onPressed: () {
              setState(() {
                _isSplitMode = !_isSplitMode;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(
        context,
        theme,
        l10n,
        editorTheme,
        editorFont,
        splitFontSize,
        unifiedFontSize,
        splitRowHeight,
        unifiedRowHeight,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    EditorTheme editorTheme,
    AppFontItem editorFont,
    double splitFontSize,
    double unifiedFontSize,
    double splitRowHeight,
    double unifiedRowHeight,
  ) {
    if (_isLoading) {
      return Container(
        color: editorTheme.backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: editorTheme.backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 13, color: editorTheme.textColor),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadDiff,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.gitRefresh),
              ),
            ],
          ),
        ),
      );
    }

    final split = _splitResult;
    if (split == null || (split.leftLines.isEmpty && split.rightLines.isEmpty)) {
      return Container(
        color: editorTheme.backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: editorTheme.gutterTextColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.gitDiffNoChanges,
                style: TextStyle(
                  fontSize: 13,
                  color: editorTheme.gutterTextColor,
                  fontFamily: editorFont.fontFamily,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isSplitMode) {
      return _buildSplitDiffView(
        context,
        theme,
        l10n,
        split,
        editorTheme,
        editorFont,
        splitFontSize,
        splitRowHeight,
      );
    } else {
      return _buildUnifiedDiffView(
        context,
        theme,
        l10n,
        editorTheme,
        editorFont,
        unifiedFontSize,
        unifiedRowHeight,
      );
    }
  }

  /// 构建双屏并排对比视图（左右两个内容区完全同步滚动与同步缩放，对标编辑器彻底消除抖动）
  Widget _buildSplitDiffView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    SplitDiffResult split,
    EditorTheme editorTheme,
    AppFontItem editorFont,
    double splitFontSize,
    double splitRowHeight,
  ) {
    final subHeaderBg = editorTheme.isDark
        ? const Color(0xFF1E2227)
        : const Color(0xFFEEEEEE);
    final borderColor = editorTheme.gutterTextColor.withValues(alpha: 0.25);

    final displayFontSize = _splitActiveZoomFontSize ?? splitFontSize;
    final displayRowHeight = (displayFontSize * 1.45 + 4.0).roundToDouble();
    final displayCharWidth = displayFontSize * 0.60;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final totalWidth = constraints.maxWidth;
        const dividerWidth = 18.0;
        final availableWidth = totalWidth - dividerWidth;
        final leftWidth = availableWidth * _splitRatio;
        final rightWidth = availableWidth * (1.0 - _splitRatio);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _handleSplitPointerDown(
            e,
            displayFontSize,
            displayRowHeight,
            displayCharWidth,
            leftWidth,
            dividerWidth,
          ),
          onPointerMove: _handleSplitPointerMove,
          onPointerUp: _handleSplitPointerUp,
          onPointerCancel: _handleSplitPointerCancel,
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: _isSplitPinching,
                child: Container(
                  color: editorTheme.backgroundColor,
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                    children: [
                      // 双屏顶栏：原始版本 vs 修改版本标签
                      Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: subHeaderBg,
                          border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: leftWidth,
                              child: ClipRect(
                                child: leftWidth < 28
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.history_rounded, size: 14, color: editorTheme.gutterTextColor),
                                            if (leftWidth >= 65) ...[
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  l10n.gitDiffOriginal,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: editorTheme.gutterTextColor,
                                                    fontFamily: editorFont.fontFamily,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(
                              width: dividerWidth,
                              child: Center(
                                child: Container(
                                  width: 1.0,
                                  height: 16,
                                  color: borderColor,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: rightWidth,
                              child: ClipRect(
                                child: rightWidth < 28
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_note_rounded, size: 15, color: theme.colorScheme.primary),
                                            if (rightWidth >= 65) ...[
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  l10n.gitDiffModified,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.primary,
                                                    fontFamily: editorFont.fontFamily,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 双屏代码对比区域（左右两侧完全同步滚动、同步缩放）
                      Expanded(
                        child: Row(
                          children: [
                            // 左栏 (原始文件)
                            SizedBox(
                              width: leftWidth,
                              child: _buildSideCodePane(
                                vController: _leftVController,
                                hController: _leftHController,
                                gutterController: _leftGutterController,
                                lines: split.leftLines,
                                isLeft: true,
                                editorTheme: editorTheme,
                                fontSize: displayFontSize,
                                editorFont: editorFont,
                                rowHeight: displayRowHeight,
                                viewportWidth: leftWidth,
                              ),
                            ),

                            // 中间可拖拽竖直分割线（宽大舒适触控手柄）
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  _splitRatio = (_splitRatio + details.delta.dx / availableWidth).clamp(0.05, 0.95);
                                });
                              },
                              onDoubleTap: () {
                                setState(() {
                                  _splitRatio = 0.5;
                                });
                              },
                              child: Container(
                                width: dividerWidth,
                                height: double.infinity,
                                color: editorTheme.backgroundColor,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 背景通顶细线
                                    Container(
                                      width: 1.0,
                                      height: double.infinity,
                                      color: borderColor,
                                    ),
                                    // 加大加宽的胶囊形拖动手柄按钮（宽 14，高 56）
                                    Container(
                                      width: 14.0,
                                      height: 56.0,
                                      decoration: BoxDecoration(
                                        color: editorTheme.isDark
                                            ? const Color(0xFF282C34)
                                            : const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: editorTheme.gutterTextColor.withValues(alpha: 0.35),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color: editorTheme.gutterTextColor.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),
                                            const SizedBox(height: 3.5),
                                            Container(
                                              width: 6.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color: editorTheme.gutterTextColor.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),
                                            const SizedBox(height: 3.5),
                                            Container(
                                              width: 6.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color: editorTheme.gutterTextColor.withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 右栏 (修改文件)
                            SizedBox(
                              width: rightWidth,
                              child: _buildSideCodePane(
                                vController: _rightVController,
                                hController: _rightHController,
                                gutterController: _rightGutterController,
                                lines: split.rightLines,
                                isLeft: false,
                                editorTheme: editorTheme,
                                fontSize: displayFontSize,
                                editorFont: editorFont,
                                rowHeight: displayRowHeight,
                                viewportWidth: rightWidth,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 缩放实时字号胶囊悬浮气泡
              if (_isSplitPinching && _splitActiveZoomFontSize != null)
                _buildZoomBadge(editorTheme, _splitActiveZoomFontSize!),
            ],
          ),
        );
      },
    );
  }

  /// 单侧独立代码视图（整区横向同步滚动、行号区内显示符号、完整语法高亮）
  Widget _buildSideCodePane({
    required ScrollController vController,
    required ScrollController hController,
    required ScrollController gutterController,
    required List<DiffLine> lines,
    required bool isLeft,
    required EditorTheme editorTheme,
    required double fontSize,
    required AppFontItem editorFont,
    required double rowHeight,
    required double viewportWidth,
  }) {
    if (viewportWidth <= 0) {
      return const SizedBox.shrink();
    }

    final gutterBg = editorTheme.gutterBackgroundColor ?? editorTheme.backgroundColor;
    final gutterDividerColor = editorTheme.gutterTextColor.withValues(alpha: 0.25);
    final isDark = editorTheme.isDark;

    // 计算行号栏宽度
    final totalLines = lines.length;
    final digits = totalLines > 0 ? '$totalLines'.length : 1;
    final charW = fontSize * 0.60;
    final signW = (charW + 4.0).clamp(14.0, 36.0);
    final gutterWidth = math.max(44.0, digits * charW + signW + 12.0);

    // 视口极限狭窄自适应判定（彻底根治 RenderFlex 水平溢出）
    final bool hasCodeArea = viewportWidth > (gutterWidth + 1.0);
    final double actualGutterWidth = hasCodeArea
        ? gutterWidth
        : math.max(0.0, viewportWidth - 1.0);
    final bool hasDivider = viewportWidth >= 1.0;

    // 计算代码最长行宽度，支撑整区横向同步滚动
    int maxChars = 0;
    for (final l in lines) {
      if (l.text.length > maxChars) {
        maxChars = l.text.length;
      }
    }
    final codeContentAvailableWidth = math.max(10.0, viewportWidth - gutterWidth - 1.0);
    final maxCodeWidth = math.max(codeContentAvailableWidth, maxChars * charW + 200.0);

    return Stack(
      children: [
        // 1. 全屏底层常驻背景与垂直分割线
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (actualGutterWidth > 0)
                Container(
                  width: actualGutterWidth,
                  color: gutterBg,
                ),
              if (hasDivider)
                Container(
                  width: 1.0,
                  color: gutterDividerColor,
                ),
              if (hasCodeArea)
                Expanded(
                  child: Container(color: editorTheme.backgroundColor),
                ),
            ],
          ),
        ),

        // 2. 主体视口内容
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 固定的行号栏（符号在行号区显示，垂直随代码同步滚动，水平不滚出；极限狭窄时平滑右对齐裁切防溢出）
              if (actualGutterWidth > 0)
                SizedBox(
                  width: actualGutterWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerRight,
                      minWidth: 0,
                      maxWidth: gutterWidth,
                      child: SizedBox(
                        width: gutterWidth,
                        child: ListView.builder(
                          controller: gutterController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lines.length,
                          itemExtent: rowHeight,
                          padding: const EdgeInsets.only(bottom: 240.0),
                          itemBuilder: (ctx, index) {
                            final line = lines[index];
                            final isDeleted = line.type == DiffLineType.deleted;
                            final isAdded = line.type == DiffLineType.added;
                            final isEmpty = line.type == DiffLineType.empty;

                            Color? rowBgColor;
                            if (isDeleted) {
                              rowBgColor = Colors.red.withValues(alpha: isDark ? 0.22 : 0.14);
                            } else if (isAdded) {
                              rowBgColor = Colors.green.withValues(alpha: isDark ? 0.22 : 0.14);
                            } else if (isEmpty) {
                              rowBgColor = isDark ? Colors.white.withValues(alpha: 0.035) : Colors.black.withValues(alpha: 0.035);
                            }

                            final signColor = isDeleted
                                ? (isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F))
                                : (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32));

                            return Container(
                              height: rowHeight,
                              color: rowBgColor,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                children: [
                                  // 行号
                                  Expanded(
                                    child: Text(
                                      line.lineNumber != null ? '${line.lineNumber}' : '',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: (fontSize - 1).clamp(SettingsProvider.minFontSize - 1.0, SettingsProvider.maxFontSize + 8.0),
                                        fontFamily: editorFont.fontFamily,
                                        fontFamilyFallback: editorFont.fallback,
                                        height: 1.4,
                                        color: isDeleted || isAdded ? signColor : editorTheme.gutterTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // 加号/减号符号严格显示在行号区内，随字号动态伸缩且防溢出裁切
                                  SizedBox(
                                    width: signW,
                                    child: Center(
                                      child: Text(
                                        isDeleted ? '-' : (isAdded ? '+' : ''),
                                        overflow: TextOverflow.visible,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: (fontSize - 1).clamp(SettingsProvider.minFontSize - 1.0, SettingsProvider.maxFontSize + 8.0),
                                          fontWeight: FontWeight.bold,
                                          fontFamily: editorFont.fontFamily,
                                          fontFamilyFallback: editorFont.fallback,
                                          height: 1.4,
                                          color: signColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              // 行号与代码之间的常驻分隔坚线
              if (hasDivider)
                Container(
                  width: 1.0,
                  color: gutterDividerColor,
                ),

              // 代码内容区（仅当空间足够容纳代码区时构建 Expanded，彻底根除视口极限挤压时的 RenderFlex 水平溢出）
              if (hasCodeArea)
                Expanded(
                  child: SingleChildScrollView(
                    controller: hController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: maxCodeWidth,
                      child: ListView.builder(
                        controller: vController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lines.length,
                        itemExtent: rowHeight,
                        padding: const EdgeInsets.only(bottom: 240.0),
                        itemBuilder: (ctx, index) {
                          final line = lines[index];
                          final isDeleted = line.type == DiffLineType.deleted;
                          final isAdded = line.type == DiffLineType.added;
                          final isEmpty = line.type == DiffLineType.empty;

                          Color? rowBgColor;
                          if (isDeleted) {
                            rowBgColor = Colors.red.withValues(alpha: isDark ? 0.22 : 0.14);
                          } else if (isAdded) {
                            rowBgColor = Colors.green.withValues(alpha: isDark ? 0.22 : 0.14);
                          } else if (isEmpty) {
                            rowBgColor = isDark ? Colors.white.withValues(alpha: 0.035) : Colors.black.withValues(alpha: 0.035);
                          }

                          final baseStyle = TextStyle(
                            fontSize: fontSize,
                            fontFamily: editorFont.fontFamily,
                            fontFamilyFallback: editorFont.fallback,
                            height: 1.4,
                            color: editorTheme.textColor,
                          );

                          // 获取带语法高亮的 TextSpan
                          final span = _getHighlightedLineSpan(
                            code: line.text,
                            baseStyle: baseStyle,
                            editorTheme: editorTheme,
                          );

                          return Container(
                            height: rowHeight,
                            color: rowBgColor,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 6.0, right: 160.0),
                            child: Text.rich(
                              span,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建单屏内联 (Unified) 对比视图（单行号列、带完整语法高亮、全向平滑滚动与基于 Listener 的稳定缩放）
  Widget _buildUnifiedDiffView(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    EditorTheme editorTheme,
    AppFontItem editorFont,
    double unifiedFontSize,
    double unifiedRowHeight,
  ) {
    final gutterBg = editorTheme.gutterBackgroundColor ?? editorTheme.backgroundColor;
    final gutterDividerColor = editorTheme.gutterTextColor.withValues(alpha: 0.25);
    final isDark = editorTheme.isDark;
    final lines = _unifiedLines;

    final displayFontSize = _unifiedActiveZoomFontSize ?? unifiedFontSize;
    final displayRowHeight = (displayFontSize * 1.45 + 4.0).roundToDouble();
    final displayCharWidth = displayFontSize * 0.60;

    final totalLines = lines.length;
    final digits = totalLines > 0 ? '$totalLines'.length : 1;
    final signW = (displayCharWidth + 4.0).clamp(14.0, 36.0);
    final gutterWidth = math.max(44.0, digits * displayCharWidth + signW + 12.0);

    int maxChars = 0;
    for (final l in lines) {
      if (l.text.length > maxChars) {
        maxChars = l.text.length;
      }
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final codeContentAvailableWidth = math.max(10.0, screenWidth - gutterWidth - 1.0);
    final maxCodeWidth = math.max(codeContentAvailableWidth, maxChars * displayCharWidth + 200.0);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _handleUnifiedPointerDown(
        e,
        displayFontSize,
        displayRowHeight,
        displayCharWidth,
      ),
      onPointerMove: _handleUnifiedPointerMove,
      onPointerUp: _handleUnifiedPointerUp,
      onPointerCancel: _handleUnifiedPointerCancel,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _isUnifiedPinching,
            child: Container(
              color: editorTheme.backgroundColor,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // 全屏背景与常驻行号竖线
                  Positioned.fill(
                    child: Row(
                      children: [
                        Container(
                          width: gutterWidth,
                          color: gutterBg,
                        ),
                        Container(
                          width: 1.0,
                          color: gutterDividerColor,
                        ),
                        Expanded(
                          child: Container(color: editorTheme.backgroundColor),
                        ),
                      ],
                    ),
                  ),

                  // 内联差异内容
                  Positioned.fill(
                    child: Row(
                      children: [
                        // 单行号列（仅显示一列行号与符号指示器，消除双行号混乱）
                        SizedBox(
                          width: gutterWidth,
                          child: ListView.builder(
                            controller: _unifiedGutterController,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lines.length,
                            itemExtent: displayRowHeight,
                            padding: const EdgeInsets.only(bottom: 240.0),
                            itemBuilder: (ctx, index) {
                              final line = lines[index];
                              final isDeleted = line.type == DiffLineType.deleted;
                              final isAdded = line.type == DiffLineType.added;

                              Color? rowBgColor;
                              if (isDeleted) {
                                rowBgColor = Colors.red.withValues(alpha: isDark ? 0.22 : 0.14);
                              } else if (isAdded) {
                                rowBgColor = Colors.green.withValues(alpha: isDark ? 0.22 : 0.14);
                              }

                              final signColor = isDeleted
                                  ? (isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F))
                                  : (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32));

                              // 仅显示单个行号：删除行显示旧号，新增/修改/未改行显示新号
                              final int? lineNum = isDeleted ? line.oldLineNumber : (line.newLineNumber ?? line.oldLineNumber);

                              return Container(
                                height: displayRowHeight,
                                color: rowBgColor,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    // 单列行号
                                    Expanded(
                                      child: Text(
                                        lineNum != null ? '$lineNum' : '',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: (displayFontSize - 1).clamp(SettingsProvider.minFontSize - 1.0, SettingsProvider.maxFontSize + 8.0),
                                          fontFamily: editorFont.fontFamily,
                                          fontFamilyFallback: editorFont.fallback,
                                          height: 1.4,
                                          color: isDeleted || isAdded ? signColor : editorTheme.gutterTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // 符号指示器（+ / -）同样在行号区内，随字号动态伸缩且防溢出裁切
                                    SizedBox(
                                      width: signW,
                                      child: Center(
                                        child: Text(
                                          isDeleted ? '-' : (isAdded ? '+' : ''),
                                          overflow: TextOverflow.visible,
                                          softWrap: false,
                                          style: TextStyle(
                                            fontSize: (displayFontSize - 1).clamp(SettingsProvider.minFontSize - 1.0, SettingsProvider.maxFontSize + 8.0),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: editorFont.fontFamily,
                                            fontFamilyFallback: editorFont.fallback,
                                            height: 1.4,
                                            color: signColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // 分隔坚线
                        Container(
                          width: 1.0,
                          color: gutterDividerColor,
                        ),

                        // 纯代码内容区（整区横向同步滚动，支持完整语法高亮）
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _unifiedHController,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width: maxCodeWidth,
                              child: ListView.builder(
                                controller: _unifiedVController,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: lines.length,
                                itemExtent: displayRowHeight,
                                padding: const EdgeInsets.only(bottom: 240.0),
                                itemBuilder: (ctx, index) {
                                  final line = lines[index];
                                  final isDeleted = line.type == DiffLineType.deleted;
                                  final isAdded = line.type == DiffLineType.added;

                                  Color? rowBgColor;
                                  if (isDeleted) {
                                    rowBgColor = Colors.red.withValues(alpha: isDark ? 0.22 : 0.14);
                                  } else if (isAdded) {
                                    rowBgColor = Colors.green.withValues(alpha: isDark ? 0.22 : 0.14);
                                  }

                                  final baseStyle = TextStyle(
                                    fontSize: displayFontSize,
                                    fontFamily: editorFont.fontFamily,
                                    fontFamilyFallback: editorFont.fallback,
                                    height: 1.4,
                                    color: editorTheme.textColor,
                                  );

                                  // 获取带语法高亮的 TextSpan
                                  final span = _getHighlightedLineSpan(
                                    code: line.text,
                                    baseStyle: baseStyle,
                                    editorTheme: editorTheme,
                                  );

                                  return Container(
                                    height: displayRowHeight,
                                    color: rowBgColor,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 6.0, right: 160.0),
                                    child: Text.rich(
                                      span,
                                      overflow: TextOverflow.visible,
                                      softWrap: false,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 缩放实时字号胶囊悬浮气泡
          if (_isUnifiedPinching && _unifiedActiveZoomFontSize != null)
            _buildZoomBadge(editorTheme, _unifiedActiveZoomFontSize!),
        ],
      ),
    );
  }
}

class _DiffDataInput {
  final String baseContent;
  final String modifiedContent;
  const _DiffDataInput(this.baseContent, this.modifiedContent);
}

class _DiffDataOutput {
  final SplitDiffResult split;
  final List<UnifiedDiffLine> unified;
  const _DiffDataOutput(this.split, this.unified);
}

_DiffDataOutput _computeDiffPageData(_DiffDataInput input) {
  final split = GitDiffHelper.computeSplitDiff(input.baseContent, input.modifiedContent);
  final unified = GitDiffHelper.toUnifiedDiff(input.baseContent, input.modifiedContent);
  return _DiffDataOutput(split, unified);
}
