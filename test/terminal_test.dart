import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/distro_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/terminal_session_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<void> deleteSystem(String systemName) async {
    _systems.remove(systemName);
    if (_selected == systemName) {
      _selected = _systems.isNotEmpty ? _systems.first : null;
    }
    notifyListeners();
  }

  @override
  Future<void> importBuiltinAlpine({
    required String systemName,
    dynamic onProgress,
    bool Function()? isCancelled,
  }) async {
    _systems.add(systemName);
    _selected = systemName;
    notifyListeners();
  }

  @override
  Future<void> importFromCustomTarGz({
    required String systemName,
    required dynamic tarGzFile,
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

      // Check AppBar title and subtitle
      expect(find.text('会话'), findsWidgets);
      expect(find.textContaining('终端'), findsOneWidget);
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

      // Tap Add button in drawer: creates session but does NOT switch
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(provider.sessions.length, equals(2));
      expect(provider.activeIndex, equals(0)); // Did not switch!
      expect(find.text('(2) 会话'), findsOneWidget);
    });

    testWidgets('Tapping session item switches active session and closes drawer', (tester) async {
      final provider = TerminalProvider();
      await tester.pumpWidget(createTestTerminalApp(terminalProvider: provider));
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pumpAndSettle();

      // Add session 2
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(provider.activeIndex, equals(0));

      // Tap session 2 item
      await tester.tap(find.text('(2) 会话'));
      await tester.pumpAndSettle();

      // Drawer should be closed and activeIndex is now 1
      expect(find.byType(Drawer), findsNothing);
      expect(provider.activeIndex, equals(1));
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

      // Add second session
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(provider.sessions.length, equals(2));

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

      // Add second session
      await tester.tap(find.byIcon(Icons.add));
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

    testWidgets('English locale renders "Session", "Terminal · alpine", and "Sessions" dynamically', (tester) async {
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

      // Check AppBar title "Session" and subtitle "Terminal · alpine"
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('Terminal · alpine'), findsOneWidget);

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

      // The created session's name is FIXED as "Session", while subtitle translates to Chinese
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('终端 · alpine'), findsOneWidget);
    });

    test('SettingsProvider manages UI, Editor, and Terminal font choices correctly', () async {
      final settings = SettingsProvider();
      expect(settings.uiFont.id, equals('system_default'));
      expect(settings.editorFont.id, equals('monospace'));
      expect(settings.terminalFont.id, equals('monospace'));

      await settings.setUiFontId('sans_serif');
      expect(settings.uiFont.id, equals('sans_serif'));
      expect(settings.uiFont.fontFamily, equals('sans-serif'));

      await settings.setEditorFontId('jetbrains_mono');
      expect(settings.editorFont.id, equals('jetbrains_mono'));
      expect(settings.editorFont.fontFamily, equals('JetBrains Mono'));

      await settings.setTerminalFontId('consolas');
      expect(settings.terminalFont.id, equals('consolas'));
      expect(settings.terminalFont.fontFamily, equals('Consolas'));
    });
  });
}

