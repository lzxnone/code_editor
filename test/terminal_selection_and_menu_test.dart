import 'dart:ui';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/widgets/terminal_selection_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalSelectionOverlay 终端框选与菜单测试', () {
    late xterm.Terminal terminal;
    late xterm.TerminalController controller;
    late FocusNode focusNode;
    late GlobalKey<xterm.TerminalViewState> terminalViewKey;

    String? clipboardContent;

    setUp(() {
      terminal = xterm.Terminal(maxLines: 100);
      controller = xterm.TerminalController();
      focusNode = FocusNode();
      terminalViewKey = GlobalKey<xterm.TerminalViewState>();
      clipboardContent = null;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardContent = (methodCall.arguments as Map<dynamic, dynamic>)['text'] as String?;
            return null;
          }
          if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardContent};
          }
          return null;
        },
      );
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Widget buildTestWidget({
      Locale locale = const Locale('zh'),
      ScrollController? scrollController,
      double height = 600,
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: height,
            child: TerminalSelectionOverlay(
              terminal: terminal,
              controller: controller,
              terminalViewKey: terminalViewKey,
              focusNode: focusNode,
              scrollController: scrollController,
              child: xterm.TerminalView(
                terminal,
                key: terminalViewKey,
                controller: controller,
                focusNode: focusNode,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('无选区时不显示拖动手柄与弹出菜单', (tester) async {
      terminal.write('Hello Terminal\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      // 没有任何选区手柄或菜单
      expect(find.text('复制'), findsNothing);
      expect(find.text('粘贴'), findsNothing);
      expect(find.text('全选'), findsNothing);
    });

    testWidgets('选中文本后自动展示两个拖动手柄以及浮动菜单', (tester) async {
      terminal.write('Hello Terminal World\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 设置选区覆盖 "Hello"
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      // 菜单弹出：包含复制、粘贴、全选
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('粘贴'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);

      // 选区存在手柄
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
    });

    testWidgets('英文环境下菜单显示 Copy, Paste, Select All', (tester) async {
      terminal.write('Hello Terminal World\r\n');
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
    });

    testWidgets('点击菜单中的“复制”将选区文本写入剪贴板并清空选区与关闭菜单', (tester) async {
      terminal.write('TestText\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 清空初始系统剪贴板
      await Clipboard.setData(const ClipboardData(text: ''));

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(8, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      await tester.tap(find.text('复制'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 验证剪贴板
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipData?.text, equals('TestText'));

      // 选区已清空，菜单已隐藏
      expect(controller.selection, isNull);
      expect(find.text('复制'), findsNothing);
    });

    testWidgets('点击菜单中的“粘贴”将剪贴板内容输入到终端', (tester) async {
      String? outputData;
      terminal.onOutput = (data) {
        outputData = data;
        terminal.write(data);
      };

      terminal.write('Prompt\$ ');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      clipboardContent = 'ls -la';

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(6, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('粘贴'), findsOneWidget);
      await tester.tap(find.text('粘贴'));
      await tester.pumpAndSettle();

      // 验证终端输出被粘贴
      expect(outputData, equals('ls -la'));
      expect(terminal.buffer.getText(), contains('ls -la'));
      expect(controller.selection, isNull);
      expect(find.text('粘贴'), findsNothing);
    });

    testWidgets('点击菜单中的“全选”选择终端所有可见字符', (tester) async {
      terminal.write('Line 1\r\nLine 2\r\nLine 3\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(4, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('全选'), findsOneWidget);
      await tester.tap(find.text('全选'));
      await tester.pumpAndSettle();

      // 选区扩展
      expect(controller.selection, isNotNull);
      expect(controller.selection!.begin.x, equals(0));
      expect(controller.selection!.begin.y, equals(0));
    });

    testWidgets('拖动手柄时隐藏弹出菜单，拖动结束后重新展示', (tester) async {
      terminal.write('Hello World from Terminal\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(11, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsOneWidget);

      final handleFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TerminalSelectionHandle',
      );
      expect(handleFinder, findsNWidgets(2));

      // 模拟拖拽结束手柄
      final handleCenter = tester.getCenter(handleFinder.last);
      final gesture = await tester.startGesture(handleCenter);
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();

      // 移动过程中菜单隐藏
      expect(find.text('复制'), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();

      // 松手后菜单恢复
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('鼠标直接拖动框选文本后松开弹出菜单', (tester) async {
      terminal.write('Hello Terminal World\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final terminalTopLeft = tester.getTopLeft(find.byType(xterm.TerminalView));
      // 在文本区域内拖动
      final gesture = await tester.startGesture(
        terminalTopLeft + const Offset(15, 15),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // 验证是否已选中文本
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      // 验证菜单是否弹出
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('弹出菜单不包含任何图标，仅保留纯文本且带有分割线', (tester) async {
      terminal.write('Hello Clean Menu\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      // 菜单已弹出
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('粘贴'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);

      // 验证菜单中无任何 Icon 组件，保持与代码编辑区一致的纯文本清爽风格
      final copyItemFinder = find.ancestor(
        of: find.text('复制'),
        matching: find.byType(Row),
      );
      expect(copyItemFinder, findsOneWidget);
      expect(
        find.descendant(of: copyItemFinder, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(of: copyItemFinder, matching: find.byType(VerticalDivider)),
        findsWidgets,
      );
    });

    testWidgets('多行选区时弹出菜单显示在顶部安全区，绝不遮挡多行文本', (tester) async {
      terminal.write('Line 1\r\nLine 2\r\nLine 3\r\nLine 4\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 跨越 3 行的选区
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 3),
      );
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);

      // 菜单顶部位置应位于顶部（screenTop，y <= 50）
      final menuTop = tester.getTopLeft(find.text('复制')).dy;
      expect(menuTop, lessThanOrEqualTo(50.0));
    });

    testWidgets('边界框选时弹出菜单被安全夹紧在屏幕安全边界内，绝不超出屏幕', (tester) async {
      terminal.write('1234567890123456789012345678901234567890\r\n');
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 靠右侧的选区
      controller.setSelection(
        terminal.buffer.createAnchor(25, 0),
        terminal.buffer.createAnchor(35, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      final copyFinder = find.text('复制');
      final selectAllFinder = find.text('全选');

      final copyRect = tester.getRect(copyFinder);
      final selectAllRect = tester.getRect(selectAllFinder);

      // 整个菜单的 x 坐标都在 0 到 400（测试容器宽度）之间
      expect(copyRect.left, greaterThanOrEqualTo(0.0));
      expect(selectAllRect.right, lessThanOrEqualTo(400.0));
    });

    testWidgets('拖动结束手柄至终端底部边缘时自动向下滚动并扩展选区', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Terminal Line $i\r\n');
      }
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(buildTestWidget(scrollController: scrollController, height: 300));
      await tester.pumpAndSettle();

      scrollController.jumpTo(0.0);
      await tester.pumpAndSettle();
      expect(scrollController.position.pixels, equals(0.0));

      final render = terminalViewKey.currentState!.renderTerminal;
      final startCell = render.getCellOffset(const Offset(30, 40));
      final endCell = render.getCellOffset(const Offset(100, 60));
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(startCell),
        terminal.buffer.createAnchorFromOffset(endCell),
      );
      await tester.pumpAndSettle();

      final handleFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TerminalSelectionHandle',
      );
      expect(handleFinder, findsNWidgets(2));

      // 拖拽结束手柄移动到终端底部边缘（y = 295）
      final gesture = await tester.startGesture(tester.getCenter(handleFinder.last));
      await tester.pump();
      await gesture.moveTo(const Offset(200, 295));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 验证终端已经自动向下滚动，pixels 大于 0
      expect(scrollController.position.pixels, greaterThan(0.0));
      // 验证选区向下扩展
      expect(controller.selection!.end.y, greaterThan(endCell.y));

      // 松手后停止自动滚动并展示菜单
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('拖动起始手柄至终端顶部边缘时自动向上滚动', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Terminal History Line $i\r\n');
      }
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(buildTestWidget(scrollController: scrollController, height: 300));
      await tester.pumpAndSettle();

      // 滚动到中间位置
      scrollController.jumpTo(250.0);
      await tester.pumpAndSettle();
      final initialPixels = scrollController.position.pixels;
      expect(initialPixels, equals(250.0));

      // 在视口内精准设置可见选区
      final render = terminalViewKey.currentState!.renderTerminal;
      final startCell = render.getCellOffset(const Offset(30, 100));
      final endCell = render.getCellOffset(const Offset(100, 180));
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(startCell),
        terminal.buffer.createAnchorFromOffset(endCell),
      );
      await tester.pumpAndSettle();

      final handleFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TerminalSelectionHandle',
      );
      expect(handleFinder, findsNWidgets(2));

      // 拖拽起始手柄至终端顶部边缘（y = 10）
      final gesture = await tester.startGesture(tester.getCenter(handleFinder.first));
      await tester.pump();
      await gesture.moveTo(const Offset(200, 10));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 验证终端已经自动向上滚动，当前 pixels 小于初始 pixels
      expect(scrollController.position.pixels, lessThan(initialPixels));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('自动滚动中途手指松开时立即停止滚动，后续不会继续发生任何自动滚动', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Terminal Stop Test Line $i\r\n');
      }
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(buildTestWidget(scrollController: scrollController, height: 300));
      await tester.pumpAndSettle();

      scrollController.jumpTo(0.0);
      await tester.pumpAndSettle();

      final render = terminalViewKey.currentState!.renderTerminal;
      final startCell = render.getCellOffset(const Offset(30, 40));
      final endCell = render.getCellOffset(const Offset(100, 60));
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(startCell),
        terminal.buffer.createAnchorFromOffset(endCell),
      );
      await tester.pumpAndSettle();

      final handleFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TerminalSelectionHandle',
      );
      expect(handleFinder, findsNWidgets(2));

      // 拖拽结束手柄至底部边缘触发自动滚动
      final gesture = await tester.startGesture(tester.getCenter(handleFinder.last));
      await tester.pump();
      await gesture.moveTo(const Offset(200, 295));
      await tester.pump(const Duration(milliseconds: 100));

      final scrollPixelsBeforeRelease = scrollController.position.pixels;
      expect(scrollPixelsBeforeRelease, greaterThan(0.0));

      // 手指松开
      await gesture.up();
      await tester.pump();

      // 在松手之后经过 200ms，验证滚动位置保持绝对静止，绝不继续自动滚动！
      await tester.pump(const Duration(milliseconds: 200));
      expect(scrollController.position.pixels, equals(scrollPixelsBeforeRelease));

      await tester.pumpAndSettle();
      expect(scrollController.position.pixels, equals(scrollPixelsBeforeRelease));
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('执行 clear（含 ESC[3J 清空回滚缓冲）之后仍可正常框选、手柄与复制可用', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Line $i\r\n');
      }

      await tester.pumpWidget(buildTestWidget(height: 300));
      await tester.pumpAndSettle();

      // shell 的 clear / Ctrl+L：清屏 + 清空回滚缓冲（xterm-256color 带 E3 能力）
      terminal.write('\x1b[H\x1b[2J\x1b[3J');
      terminal.write('Hello Clear World\r\n');
      await tester.pumpAndSettle();

      final terminalTopLeft = tester.getTopLeft(find.byType(xterm.TerminalView));
      final gesture = await tester.startGesture(
        terminalTopLeft + const Offset(15, 15),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // 选区行号必须落在真实缓冲区范围内（补丁前行号会整体偏移出界，选区根本无法绘制）
      expect(controller.selection, isNotNull);
      expect(controller.selection!.isCollapsed, isFalse);
      expect(controller.selection!.begin.y, lessThan(terminal.buffer.height));
      expect(controller.selection!.end.y, lessThan(terminal.buffer.height));

      final handleFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TerminalSelectionHandle',
      );
      expect(handleFinder, findsNWidgets(2));
      expect(find.text('复制'), findsOneWidget);

      // 复制内容真实有效（补丁前 getText(selection) 会得到空串）
      await tester.tap(find.text('复制'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipData?.text?.trim(), isNotEmpty);
      expect(terminal.buffer.getText(), contains(clipData!.text!.trim()));
    });

    testWidgets('执行 clear 使选区所在行被裁掉后，残留手柄与菜单会被自动清理', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Line $i\r\n');
      }
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(buildTestWidget(scrollController: scrollController, height: 300));
      await tester.pumpAndSettle();

      // 滚到顶部，使首行位于可见视口内
      scrollController.jumpTo(0.0);
      await tester.pumpAndSettle();

      // 先建立选区：手柄与菜单出现
      controller.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(5, 0),
      );
      await tester.pumpAndSettle();

      final handleFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_TerminalSelectionHandle',
      );
      expect(handleFinder, findsNWidgets(2));
      expect(find.text('复制'), findsOneWidget);

      // 清空回滚缓冲：选区锚点随被裁掉的行一起失效
      terminal.write('\x1b[3J');
      await tester.pumpAndSettle();

      expect(controller.selection, isNull);
      expect(handleFinder, findsNothing);
      expect(find.text('复制'), findsNothing);
    });

    testWidgets('多行选区整体位于可见视口下方时，菜单贴视口底边而不是屏幕顶部', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Line $i\r\n');
      }
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(buildTestWidget(scrollController: scrollController, height: 300));
      await tester.pumpAndSettle();

      scrollController.jumpTo(0.0);
      await tester.pumpAndSettle();

      final render = terminalViewKey.currentState!.renderTerminal;
      final lastVisibleRow = render.getCellOffset(Offset(0, render.size.height)).y;

      // 跨 3 行、且整体位于可见视口下方
      controller.setSelection(
        terminal.buffer.createAnchor(0, lastVisibleRow + 3),
        terminal.buffer.createAnchor(5, lastVisibleRow + 5),
      );
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      final menuBottom = tester.getBottomLeft(find.byType(Material).last).dy;
      final menuTop = tester.getTopLeft(find.byType(Material).last).dy;

      // 参考编辑区 EditorToolbarPlacement.bottom：贴视口底边（safeBottom = 300 - 6 = 294）
      expect(menuBottom, closeTo(290.0, 10.0));
      expect(menuTop, greaterThan(200.0), reason: '不得被钉在屏幕顶部');
    });

    testWidgets('单行选区整体位于可见视口下方时，菜单同样贴视口底边显示', (tester) async {
      for (int i = 0; i < 60; i++) {
        terminal.write('Line $i\r\n');
      }
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(buildTestWidget(scrollController: scrollController, height: 300));
      await tester.pumpAndSettle();

      scrollController.jumpTo(0.0);
      await tester.pumpAndSettle();

      final render = terminalViewKey.currentState!.renderTerminal;
      final lastVisibleRow = render.getCellOffset(Offset(0, render.size.height)).y;

      controller.setSelection(
        terminal.buffer.createAnchor(0, lastVisibleRow + 3),
        terminal.buffer.createAnchor(5, lastVisibleRow + 3),
      );
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      final copyRect = tester.getRect(find.text('复制'));
      expect(copyRect.top, greaterThan(200.0), reason: '不得被钉在屏幕顶部');
      expect(copyRect.bottom, closeTo(290.0 - 9.0, 12.0), reason: '应贴视口底边');
    });
  });
}
