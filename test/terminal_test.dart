import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/virtual_keyboard_config.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/terminal_session_item_widget.dart';
import 'package:code_editor/widgets/virtual_keyboard_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart' as xterm;

class FakeDistroProvider extends DistroProvider {
  final List<String> _systems;
  String? _selected;

  FakeDistroProvider({List<String>? systems, String? selected})
      : _systems = systems ?? ['alpine'],
        _selected = selected ?? 'alpine';

  @override
  List<String> get installedSystems => List.unmodifiable(_systems);

  @override
  String? get selectedSystem => _selected;

  @override
  bool get hasAnySystem => _systems.isNotEmpty;

  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshSystems() async {}

  @override
  Future<void> selectSystem(String systemName) async {
    _selected = systemName;
    notifyListeners();
  }

  @override
  Future<void> importBuiltinUbuntu({
    String systemName = 'ubuntu',
    dynamic onProgress,
    bool Function()? isCancelled,
  }) async {
    _systems.add(systemName);
    _selected = systemName;
    notifyListeners();
  }
}

Widget createTestTerminalApp({
  required TerminalProvider terminalProvider,
  DistroProvider? distroProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
      ChangeNotifierProvider<DistroProvider>.value(
        value: distroProvider ?? FakeDistroProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TerminalView(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Terminal Subsystem Tests', () {
    testWidgets('Lazy loading creates first session upon first entry', (tester) async {
      final provider = TerminalProvider();
      expect(provider.sessions.isEmpty, isTrue);

      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      expect(provider.sessions.length, equals(1));
      expect(provider.activeIndex, equals(0));
      expect(provider.activeSession?.name, equals('会话'));

      // Check AppBar title and subtitle: without a project open, no subtitle is displayed
      expect(find.text('会话'), findsWidgets);
      expect(find.textContaining('终端'), findsNothing);
    });

    testWidgets('Right drawer can be opened and shows title "会话" with add button', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      // Click list button in AppBar to open endDrawer
      final listBtn = find.byIcon(Icons.format_list_bulleted);
      expect(listBtn, findsOneWidget);
      await tester.tap(listBtn);
      await tester.pumpAndSettle();

      // Drawer is open
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Verify item text format: (1) 会话
      expect(find.text('(1) 会话'), findsOneWidget);

      // Tap Add button in drawer: creates session, activates it and closes drawer
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(provider.sessions.length, equals(2));
      expect(provider.activeIndex, equals(1)); // Activated!
      expect(find.byType(Drawer), findsNothing); // Drawer closed!

      // Re-open drawer to verify item 2 is present
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();
      expect(find.text('(2) 会话'), findsOneWidget);
    });

    testWidgets('Tapping session item switches active session and closes drawer', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Add session 2 (creates and switches to session 2, closing drawer)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(provider.activeIndex, equals(1));
      expect(find.byType(Drawer), findsNothing);

      // Re-open drawer and tap session 1 item
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();
      await tester.tap(find.text('(1) 会话'));
      await tester.pumpAndSettle();

      // Drawer should be closed and activeIndex is now 0
      expect(find.byType(Drawer), findsNothing);
      expect(provider.activeIndex, equals(0));
    });

    testWidgets('Long press on session item opens context menu with rename and delete', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Long press on session item
      final sessionItem = find.byType(TerminalSessionItemWidget);
      expect(sessionItem, findsOneWidget);
      await tester.longPress(sessionItem);
      await tester.pumpAndSettle();

      // Context menu options
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // Tap 重命名
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(AlertDialog), findsOneWidget);
      final dialogTextField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextField, '调试终端');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(provider.activeSession?.name, equals('调试终端'));
    });

    testWidgets('Session persistence: returning to editor and re-entering preserves sessions and buffers', (tester) async {
      final provider = TerminalProvider();

      // Simulate root app with Navigator
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: provider),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TerminalView(),
                      ),
                    );
                  },
                  child: const Text('进入终端'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter terminal
      await tester.tap(find.text('进入终端'));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
      expect(provider.sessions.length, equals(1));

      // Append custom text to session buffer via provider
      provider.appendOutput(provider.activeSession!, 'CUSTOM_SESSION_OUTPUT_LINE');
      await tester.pumpAndSettle();
      expect(provider.activeSession!.bufferText.contains('CUSTOM_SESSION_OUTPUT_LINE'), isTrue);

      // Pop back to editor
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsNothing);
      expect(find.text('进入终端'), findsOneWidget);

      // Provider still holds the session and buffer
      expect(provider.sessions.length, equals(1));
      expect(provider.sessions.first.bufferText.contains('CUSTOM_SESSION_OUTPUT_LINE'), isTrue);

      // Re-enter terminal
      await tester.tap(find.text('进入终端'));
      await tester.pumpAndSettle();

      // Verify the session output is still preserved in buffer
      expect(find.byType(TerminalView), findsOneWidget);
      expect(provider.activeSession!.bufferText.contains('CUSTOM_SESSION_OUTPUT_LINE'), isTrue);
    });

    testWidgets('Deleting a session from context menu removes it and updates activeIndex', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Add second session (which automatically closes the drawer)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(provider.sessions.length, equals(2));

      // Re-open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Long press second session
      final items = find.byType(TerminalSessionItemWidget);
      expect(items, findsNWidgets(2));
      await tester.longPress(items.at(1));
      await tester.pumpAndSettle();

      // Tap 删除
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Confirm dialog opens
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      // Session 2 is deleted
      expect(provider.sessions.length, equals(1));
      expect(find.text('(2) 会话'), findsNothing);
    });

    testWidgets('Dragging to reorder sessions updates session list order and labels', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Add second session (which automatically closes the drawer)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Re-open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      provider.renameSession(provider.sessions[0].id, '第一项');
      provider.renameSession(provider.sessions[1].id, '第二项');
      await tester.pumpAndSettle();

      expect(find.text('(1) 第一项'), findsOneWidget);
      expect(find.text('(2) 第二项'), findsOneWidget);

      // Drag first item's drag handle downwards past the second item
      final firstDragHandle = find.byIcon(Icons.drag_handle).first;
      await tester.drag(firstDragHandle, const Offset(0, 120));
      await tester.pumpAndSettle();

      expect(provider.sessions[0].name, equals('第二项'));
      expect(provider.sessions[1].name, equals('第一项'));
      expect(find.text('(1) 第二项'), findsOneWidget);
      expect(find.text('(2) 第一项'), findsOneWidget);
    });

    testWidgets('English locale renders "Session" and "Sessions" dynamically', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: provider),
            ChangeNotifierProvider<DistroProvider>.value(value: FakeDistroProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TerminalView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar title "Session" (no project open, so subtitle is null)
      expect(find.text('Session'), findsOneWidget);

      // Open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Check drawer title "Sessions" and item "(1) Session"
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('(1) Session'), findsOneWidget);
    });

    testWidgets('Session name is fixed upon creation and does not re-translate on language change', (tester) async {
      final provider = TerminalProvider();
      // First created in English
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: provider),
            ChangeNotifierProvider<DistroProvider>.value(value: FakeDistroProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TerminalView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Session'), findsOneWidget);

      // Now re-render with Chinese locale
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: provider),
            ChangeNotifierProvider<DistroProvider>.value(value: FakeDistroProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TerminalView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The created session's name is FIXED as "Session"
      expect(find.text('Session'), findsOneWidget);
    });

    testWidgets('Active modifier also applies to soft-keyboard input', (tester) async {
      final terminalProvider = TerminalProvider();
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setKeyboardEnabled(KeyboardScope.terminal, true);

      // 先建会话并接管输出，便于观察终端最终发出的字节
      terminalProvider.ensureInitialized(defaultName: 'Session', defaultDistroId: 'alpine');
      final session = terminalProvider.activeSession!;
      final emitted = <String>[];
      session.terminal.onOutput = emitted.add;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<DistroProvider>.value(value: FakeDistroProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TerminalView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 展开小键盘（默认折叠只露第一行），点亮 Ctrl
      await tester.drag(find.byType(VirtualKeyboardWidget), const Offset(0, -90));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();

      // 模拟软键盘/IME 打进一个字符：它不产生 KeyEvent，只能在 onOutput 层被改写
      session.terminal.textInput('c');
      expect(emitted.last, '\x03', reason: '点亮 Ctrl 后软键盘输入的 c 应变成 ^C');

      // 一次性状态已被消耗，再打一次就是普通字母
      session.terminal.textInput('c');
      expect(emitted.last, 'c');

      // 未点修饰键时不应改写
      session.terminal.textInput('d');
      expect(emitted.last, 'd');
    });

    testWidgets('terminal background color follows the setting', (tester) async {
      final terminalProvider = TerminalProvider();
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setTerminalBackgroundColor(const Color(0xFF002B36));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<DistroProvider>.value(value: FakeDistroProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TerminalView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 容器与 xterm 主题都应使用设置的背景色
      final terminalView = tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
      expect(terminalView.theme.background.toARGB32(), 0xFF002B36);

      // 浅色背景时前景自动切成深色，保证可读
      await settingsProvider.setTerminalBackgroundColor(const Color(0xFFFFFFFF));
      await tester.pumpAndSettle();
      final lightView = tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
      expect(lightView.theme.background.toARGB32(), 0xFFFFFFFF);
      expect(lightView.theme.foreground.computeLuminance(), lessThan(0.5));
    });

    test('SettingsProvider manages UI, Editor, and Terminal font choices correctly', () async {
      final settings = SettingsProvider();
      expect(settings.uiFont.id, equals('system_default'));
      expect(settings.editorFont.id, equals('jetbrains_mono'));
      expect(settings.terminalFont.id, equals('jetbrains_mono'));

      await settings.setUiFontId('sans_serif');
      expect(settings.uiFont.id, equals('sans_serif'));
      expect(settings.uiFont.fontFamily, equals('sans-serif'));

      await settings.setEditorFontId('monospace');
      expect(settings.editorFont.id, equals('monospace'));
      expect(settings.editorFont.fontFamily, equals('monospace'));

      await settings.setTerminalFontId('consolas');
      expect(settings.terminalFont.id, equals('consolas'));
      expect(settings.terminalFont.fontFamily, equals('Consolas'));
    });

    testWidgets('Terminal accessory keyboard sends real keys through the PTY channel', (tester) async {
      final terminalProvider = TerminalProvider();
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      // 与编辑区开关相互独立：这里显式打开终端小键盘
      await settingsProvider.setKeyboardEnabled(KeyboardScope.terminal, true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<DistroProvider>.value(value: FakeDistroProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TerminalView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(terminalProvider.sessions, isNotEmpty);
      // 终端小键盘已挂载（默认预设：两行特殊键 + 修饰键）
      expect(find.byType(VirtualKeyboardWidget), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Ctrl'), findsOneWidget);

      // 接管 onOutput（真实场景下由 TerminalSession 接到 PTY）
      final emitted = <String>[];
      terminalProvider.activeSession!.terminal.onOutput = emitted.add;

      // 第一行：Esc / ↑ / 回车 / 文本符号（带图标的键在键盘上渲染图标）
      await tester.tap(find.text('Esc'));
      await tester.pumpAndSettle();
      expect(emitted.last, '\x1b');

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      expect(emitted.last, '\x1b[A');

      await tester.tap(find.text('-'));
      await tester.pumpAndSettle();
      expect(emitted.last, '-');

      // 默认折叠只显示第一行，上拉展开到第二行（与编辑区行为一致）
      await tester.drag(find.byType(VirtualKeyboardWidget), const Offset(0, -60));
      await tester.pumpAndSettle();

      // 第二行：End / : / 方向键
      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();
      expect(emitted.last, '\x1b[F');

      await tester.tap(find.text(':'));
      await tester.pumpAndSettle();
      expect(emitted.last, ':');

      // 运行时修饰键：一次性 Ctrl 与方向键叠加成 Ctrl+↑（一次性随即被消耗）
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      expect(emitted.last, '\x1b[1;5A', reason: '一次性 Ctrl 应与方向键叠加');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      expect(emitted.last, '\x1b[A', reason: '一次性 Ctrl 应已被消耗');

      // 关闭终端小键盘开关后应卸载
      await settingsProvider.setKeyboardEnabled(KeyboardScope.terminal, false);
      await tester.pumpAndSettle();
      expect(find.byType(VirtualKeyboardWidget), findsNothing);
    });
  });
}

