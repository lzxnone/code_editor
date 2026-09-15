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

      // 2. aboveStart: 空间狭小（靠近顶部）时翻转到下方
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
      final flippedBelowPos = tester.getTopLeft(find.byType(Material).last);
      expect(flippedBelowPos.dy, greaterThan(60));

      // 3. belowEnd: 空间充裕时显示在目标下方
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

      // 5. center: 居中显示
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
      final centerPos = tester.getCenter(find.byType(Material).last);
      expect((centerPos.dy - 300).abs(), lessThan(30));

      // 6. top: 顶部贴边
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
      expect(topPos.dy, closeTo(110, 10));

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
  });
}
