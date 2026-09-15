part of re_editor;

/// 选区弹出菜单的位置策略类型
enum EditorToolbarPlacement {
  /// 在起始端点（左端点）上方弹出，若上方空间不足则翻转至下方
  aboveStart,
  /// 在结束端点（右端点）下方弹出，若下方空间不足则翻转至上方
  belowEnd,
  /// 选区文本完全贯穿/占据视口时，在可视屏幕正中间弹出
  center,
  /// 选区整体在视口上方时，在视口顶部贴边弹出
  top,
  /// 选区整体在视口下方时，在视口底部贴边弹出
  bottom,
}

/// 携带智能定位策略与可视边界信息的扩展锚点
class EditorSelectionToolbarAnchors extends TextSelectionToolbarAnchors {
  /// 定位策略分支
  final EditorToolbarPlacement placement;
  /// 目标锚点位置（绝对屏幕坐标）
  final Offset targetOffset;
  /// 当前编辑器的有效可视区域边界（绝对屏幕坐标）
  final Rect visibleEditorRect;

  const EditorSelectionToolbarAnchors({
    required super.primaryAnchor,
    super.secondaryAnchor,
    required this.placement,
    required this.targetOffset,
    required this.visibleEditorRect,
  });
}

typedef ToolbarMenuBuilder = Widget Function({
  required BuildContext context,
  required TextSelectionToolbarAnchors anchors,
  required CodeLineEditingController controller,
  required VoidCallback onDismiss,
  required VoidCallback onRefresh,
  Rect? renderRect,
});

abstract class SelectionToolbarController {

  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  });

  void hide(BuildContext context);

}

abstract class MobileSelectionToolbarController implements SelectionToolbarController {

  factory MobileSelectionToolbarController({
    required ToolbarMenuBuilder builder
  }) => _MobileSelectionToolbarController(
    builder: builder
  );

}