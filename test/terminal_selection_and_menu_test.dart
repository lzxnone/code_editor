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

    Widget buildTestWidget({Locale locale = const Locale('zh')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: TerminalSelectionOverlay(
              terminal: terminal,
              controller: controller,
              terminalViewKey: terminalViewKey,
              focusNode: focusNode,
              child: xterm.TerminalView(
                terminal,
                key: terminalViewKey,
                controller: controller,
                focusNode: focusNode,
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
  });
}
