import 'package:flutter/widgets.dart';

/// 编辑器专属局部 Overlay 作用域
///
/// 核心职责：
/// 1. 为代码补全弹窗（CodeAutocomplete）提供局部 Overlay 承载容器；
/// 2. 控制弹窗的堆叠层级（Z-Order）：使其位于编辑器内容之上，但在编辑区底栏（如虚拟小键盘 VirtualKeyboardWidget、诊断横幅）之下；
/// 3. 当父级状态变更时，自动刷新内部根 OverlayEntry，确保代码内容与控制器无缝响应。
class EditorOverlayScope extends StatefulWidget {
  final Widget child;
  final Clip clipBehavior;

  const EditorOverlayScope({
    super.key,
    required this.child,
    this.clipBehavior = Clip.none,
  });

  @override
  State<EditorOverlayScope> createState() => _EditorOverlayScopeState();
}

class _EditorOverlayScopeState extends State<EditorOverlayScope> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(
      builder: (context) => widget.child,
    );
  }

  @override
  void didUpdateWidget(covariant EditorOverlayScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      clipBehavior: widget.clipBehavior,
      initialEntries: [_entry],
    );
  }
}
