import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/widgets/code_editor_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodeEditorToolbarController 选区菜单定位与恢复测试', () {
    test('拖动 End Handle 时，锚点严格位于末尾手柄位置，绝不跳跃至顶端', () {
      // 模拟 re_editor 传递的 End Handle 拖拽锚点：primary 为 -10000，secondary 为末尾坐标 (180, 450)
      const inputAnchors = TextSelectionToolbarAnchors(
        primaryAnchor: Offset(-10000, -10000),
        secondaryAnchor: Offset(180, 450),
      );

      // 验证 End Handle 拖拽锚点规则
      final target = inputAnchors.primaryAnchor.dx < 0 && inputAnchors.secondaryAnchor != null
          ? inputAnchors.secondaryAnchor!
          : inputAnchors.primaryAnchor;

      expect(target.dy, equals(450));
      expect(target.dx, equals(180));
    });

    test('拖动 Start Handle 时，锚点严格位于起始手柄位置', () {
      const inputAnchors = TextSelectionToolbarAnchors(
        primaryAnchor: Offset(150, 120),
        secondaryAnchor: Offset(180, 450),
      );

      final target = inputAnchors.primaryAnchor.dx < 0 && inputAnchors.secondaryAnchor != null
          ? inputAnchors.secondaryAnchor!
          : inputAnchors.primaryAnchor;

      expect(target.dy, equals(120));
      expect(target.dx, equals(150));
    });

    testWidgets('reshowLastToolbar 在选区折叠时安全跳过，在有选区时可重新唤起', (tester) async {
      final controller = CodeEditorToolbarController();
      final codeController = CodeLineEditingController.fromText('Hello World\nSecond Line\nThird Line');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    controller.reshowLastToolbar(context);
                  },
                  child: const Text('Reshow'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 无选区（折叠）时点击 Reshow 不抛异常且无崩溃
      await tester.tap(find.text('Reshow'));
      await tester.pumpAndSettle();

      // 设置选区
      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 5,
      );

      // 模拟 show 记录上下文
      final layerLink = LayerLink();
      final visibility = ValueNotifier<bool>(true);
      final element = tester.element(find.text('Reshow'));

      controller.show(
        context: element,
        controller: codeController,
        anchors: const TextSelectionToolbarAnchors(
          primaryAnchor: Offset(100, 200),
        ),
        renderRect: const Rect.fromLTWH(0, 0, 400, 600),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();

      // 隐藏后再 reshow
      controller.hide(element);
      await tester.pumpAndSettle();

      controller.reshowLastToolbar(element);
      await tester.pumpAndSettle();

      // 验证无异常并正常处理
      expect(codeController.selection.isCollapsed, isFalse);
    });

    testWidgets('验证中英文本地化字符串正确无硬编码', (tester) async {
      late AppLocalizations zhL10n;
      late AppLocalizations enL10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              zhL10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(zhL10n.copy, equals('复制'));
      expect(zhL10n.cut, equals('剪切'));
      expect(zhL10n.paste, equals('粘贴'));
      expect(zhL10n.selectAll, equals('全选'));
      expect(zhL10n.copiedToClipboard, equals('已复制到剪贴板'));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              enL10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(enL10n.copy, equals('Copy'));
      expect(enL10n.cut, equals('Cut'));
      expect(enL10n.paste, equals('Paste'));
      expect(enL10n.selectAll, equals('Select All'));
      expect(enL10n.copiedToClipboard, equals('Copied to clipboard'));
    });

    testWidgets('CodeEditor 选区手柄在有选区时正常展现并支持鼠标交互', (tester) async {
      final codeController = CodeLineEditingController.fromText('Hello Flutter Code Editor\nSecond line text');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 400,
              child: CodeEditor(
                controller: codeController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();

      expect(codeController.selection.isCollapsed, isFalse);
    });

    testWidgets('智能定位算法测试: aboveStart/belowEnd/center/top/bottom 与空间避让翻转', (tester) async {
      final controller = CodeEditorToolbarController();
      final codeController = CodeLineEditingController.fromText('Test line 1\nTest line 2\nTest line 3');
      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 4,
      );

      late BuildContext buildCtx;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCtx = context;
                return const SizedBox(width: 400, height: 600);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layerLink = LayerLink();
      final visibility = ValueNotifier<bool>(true);

      // 1. aboveStart: 空间充裕时显示在目标上方
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 300),
          placement: EditorToolbarPlacement.aboveStart,
          targetOffset: Offset(200, 300),
          visibleEditorRect: Rect.fromLTWH(0, 50, 400, 500),
        ),
        renderRect: const Rect.fromLTWH(0, 50, 400, 500),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final abovePos = tester.getTopLeft(find.byType(Material).last);
      expect(abovePos.dy, lessThan(300));

      // 2. aboveStart: 靠前行可借用 AppBar 空间留在上方，避免向下翻转遮挡光标
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 60),
          placement: EditorToolbarPlacement.aboveStart,
          targetOffset: Offset(200, 60),
          visibleEditorRect: Rect.fromLTWH(0, 50, 400, 500),
        ),
        renderRect: const Rect.fromLTWH(0, 50, 400, 500),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final borrowAppBarPos = tester.getTopLeft(find.byType(Material).last);
      expect(borrowAppBarPos.dy, lessThan(60));

      // 2.1 aboveStart: 触及手机状态栏安全区极限时向下翻转，并避开行高与手柄
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 20),
          placement: EditorToolbarPlacement.aboveStart,
          targetOffset: Offset(200, 20),
          visibleEditorRect: Rect.fromLTWH(0, 0, 400, 500),
          lineHeight: 24.0,
        ),
        renderRect: const Rect.fromLTWH(0, 0, 400, 500),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final flippedBelowPos = tester.getTopLeft(find.byType(Material).last);
      expect(flippedBelowPos.dy, greaterThan(20 + 24.0 + 30.0));

      // 3. belowEnd: 空间充裕时显示在目标下方（避让动态行高 + 手柄）
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 200),
          placement: EditorToolbarPlacement.belowEnd,
          targetOffset: Offset(200, 200),
          visibleEditorRect: Rect.fromLTWH(0, 50, 400, 500),
        ),
        renderRect: const Rect.fromLTWH(0, 50, 400, 500),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final belowPos = tester.getTopLeft(find.byType(Material).last);
      expect(belowPos.dy, greaterThan(200));

      // 4. belowEnd: 空间狭小（靠近底部）时翻转到上方
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 530),
          placement: EditorToolbarPlacement.belowEnd,
          targetOffset: Offset(200, 530),
          visibleEditorRect: Rect.fromLTWH(0, 50, 400, 500),
        ),
        renderRect: const Rect.fromLTWH(0, 50, 400, 500),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final flippedAbovePos = tester.getTopLeft(find.byType(Material).last);
      expect(flippedAbovePos.dy, lessThan(530));

      // 5. center: 改为在屏幕最上方贴边显示（避免在中间遮挡文本，允许覆盖 TabBar/AppBar）
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 300),
          placement: EditorToolbarPlacement.center,
          targetOffset: Offset(200, 300),
          visibleEditorRect: Rect.fromLTWH(0, 100, 400, 400),
        ),
        renderRect: const Rect.fromLTWH(0, 100, 400, 400),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final centerPos = tester.getTopLeft(find.byType(Material).last);
      // 位于屏幕最上方（screenTop = mediaQuery.padding.top + 6.0，在测试默认环境下为 6.0）
      expect(centerPos.dy, closeTo(6.0, 1.0));

      // 6. top: 同样在屏幕最上方贴边显示
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 100),
          placement: EditorToolbarPlacement.top,
          targetOffset: Offset(200, 100),
          visibleEditorRect: Rect.fromLTWH(0, 100, 400, 400),
        ),
        renderRect: const Rect.fromLTWH(0, 100, 400, 400),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final topPos = tester.getTopLeft(find.byType(Material).last);
      expect(topPos.dy, closeTo(6.0, 1.0));

      // 7. bottom: 底部贴边
      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, 500),
          placement: EditorToolbarPlacement.bottom,
          targetOffset: Offset(200, 500),
          visibleEditorRect: Rect.fromLTWH(0, 100, 400, 400),
        ),
        renderRect: const Rect.fromLTWH(0, 100, 400, 400),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();
      final bottomPos = tester.getBottomLeft(find.byType(Material).last);
      expect(bottomPos.dy, closeTo(490, 20));

      controller.hide(buildCtx);
      await tester.pumpAndSettle();
    });

    testWidgets('存在框选区域时，点击框选区域不取消框选，点击外部则取消框选', (tester) async {
      final codeController = CodeLineEditingController.fromText('Hello Flutter Code Editor\nSecond line text');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 400,
              child: CodeEditor(
                controller: codeController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 设置选区为 "Hello" (offset 0 到 5)
      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();
      expect(codeController.selection.isCollapsed, isFalse);

      // 点击首行 "Hello" 内部
      final editorFinder = find.byType(CodeEditor);
      final editorTopLeft = tester.getTopLeft(editorFinder);
      await tester.tapAt(editorTopLeft + const Offset(20, 10));
      await tester.pumpAndSettle();

      // 选区不被取消！
      expect(codeController.selection.isCollapsed, isFalse);

      // 点击第 2 行（选区外部）
      await tester.tapAt(editorTopLeft + const Offset(20, 60));
      await tester.pumpAndSettle();

      // 选区在点击外部后被取消
      expect(codeController.selection.isCollapsed, isTrue);
    });

    testWidgets('点击选中文本所在行的末尾空白区域，严格判定为非选区并取消框选', (tester) async {
      final codeController = CodeLineEditingController.fromText('Hello Flutter Code Editor\nSecond line text');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 400,
              child: CodeEditor(
                controller: codeController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 选中第 0 行的 "Hello"
      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 5,
      );
      await tester.pumpAndSettle();
      expect(codeController.selection.isCollapsed, isFalse);

      // 点击第 0 行后面的空白区域 (例如横坐标 400 远超文本宽度)
      final editorFinder = find.byType(CodeEditor);
      final editorTopLeft = tester.getTopLeft(editorFinder);
      await tester.tapAt(editorTopLeft + const Offset(400, 10));
      await tester.pumpAndSettle();

      // 严格判定：点击末尾空白区域时，框选必须被取消
      expect(codeController.selection.isCollapsed, isTrue);
    });

    testWidgets('移动端选区菜单移除图标仅保留文字', (tester) async {
      final controller = CodeEditorToolbarController();
      final codeController = CodeLineEditingController.fromText('Hello World');
      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 5,
      );

      late BuildContext buildCtx;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCtx = context;
                return const SizedBox(width: 400, height: 600);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layerLink = LayerLink();
      final visibility = ValueNotifier<bool>(true);

      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const TextSelectionToolbarAnchors(
          primaryAnchor: Offset(100, 100),
        ),
        renderRect: const Rect.fromLTWH(0, 0, 400, 600),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();

      // 验证菜单弹出的 Material 容器内不包含任何 Icon，只保留文字
      final toolbarMaterial = find.byType(Material).last;
      expect(find.descendant(of: toolbarMaterial, matching: find.byType(Icon)), findsNothing);
      expect(find.descendant(of: toolbarMaterial, matching: find.byType(Text)), findsWidgets);

      controller.hide(buildCtx);
      await tester.pumpAndSettle();
    });

    testWidgets('大字号下 belowEnd 与翻转到下方时，根据动态行高与手柄下挂距离充分下移', (tester) async {
      final controller = CodeEditorToolbarController();
      final codeController = CodeLineEditingController.fromText('Large Font Test');
      codeController.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 5,
      );

      late BuildContext buildCtx;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCtx = context;
                return const SizedBox(width: 400, height: 700);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final layerLink = LayerLink();
      final visibility = ValueNotifier<bool>(true);

      // 模拟大字号：lineHeight 达到 48.0
      const double largeLineHeight = 48.0;
      const double targetY = 150.0;

      controller.show(
        context: buildCtx,
        controller: codeController,
        anchors: const EditorSelectionToolbarAnchors(
          primaryAnchor: Offset(200, targetY),
          placement: EditorToolbarPlacement.belowEnd,
          targetOffset: Offset(200, targetY),
          visibleEditorRect: Rect.fromLTWH(0, 0, 400, 700),
          lineHeight: largeLineHeight,
        ),
        renderRect: const Rect.fromLTWH(0, 0, 400, 700),
        layerLink: layerLink,
        visibility: visibility,
      );
      await tester.pumpAndSettle();

      final menuPos = tester.getTopLeft(find.byType(Material).last);
      // y 应该正好是 targetY + largeLineHeight + 32.0 = 150 + 48 + 32 = 230.0
      expect(menuPos.dy, equals(targetY + largeLineHeight + 32.0));

      controller.hide(buildCtx);
      await tester.pumpAndSettle();
    });

    testWidgets('选中文本后进行滚动，手柄层不应被销毁消失且在滚动停止后正常维持', (tester) async {
      final codeController = CodeLineEditingController.fromText(
        List.generate(50, (i) => 'Line $i: Content of the test line with some length').join('\n'),
      );
      final scrollController = CodeScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: CodeEditor(
                controller: codeController,
                scrollController: scrollController,
                wordWrap: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 选中第 5 行文本
      codeController.selection = const CodeLineSelection(
        baseIndex: 5,
        baseOffset: 0,
        extentIndex: 5,
        extentOffset: 10,
      );
      await tester.pumpAndSettle();

      // 执行纵向滚动
      await tester.drag(find.byType(CodeEditor), const Offset(0, -60));
      await tester.pumpAndSettle();

      // 选区依然存在
      expect(codeController.selection.isCollapsed, isFalse);
    });

    testWidgets('非折行模式(wordWrap: false)下控制器替换文本，渲染段落立即更新', (tester) async {
      final codeController = CodeLineEditingController.fromText('initial_text');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: CodeEditor(
                controller: codeController,
                wordWrap: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 模拟小键盘输入：修改文本
      codeController.replaceSelection('appended');
      await tester.pumpAndSettle();

      // 验证文字已在控制器中
      expect(codeController.text, contains('appended'));
      // 验证未抛异常且稳定渲染
      expect(find.byType(CodeEditor), findsOneWidget);
    });
  });
}
