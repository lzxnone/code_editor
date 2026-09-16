import 'dart:ui';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/terminal_session.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart' as xterm;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Terminal Font Size & Gesture Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsProvider: terminalFontSize defaults, updates, clamps, and persists', () async {
      SharedPreferences.setMockInitialValues({'terminal_font_size': 16.0});
      final provider = SettingsProvider();
      await provider.init();

      expect(provider.terminalFontSize, 16.0);

      // Updates and clamps between 8.0 and 32.0
      await provider.setTerminalFontSize(20.0);
      expect(provider.terminalFontSize, 20.0);

      await provider.setTerminalFontSize(5.0);
      expect(provider.terminalFontSize, 8.0);

      await provider.setTerminalFontSize(50.0);
      expect(provider.terminalFontSize, 32.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('terminal_font_size'), 32.0);
    });

    test('L10n: terminalFontSize strings exist in both zh and en', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(zh.terminalFontSize, '终端字号');
      expect(zh.terminalFontSizeDialogTitle, '终端字号');

      expect(en.terminalFontSize, 'Terminal Font Size');
      expect(en.terminalFontSizeDialogTitle, 'Terminal Font Size');
    });

    testWidgets('SettingsView: displays terminal font size tile with controls and dialog', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setTerminalFontSize(14.0);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find terminal font size tile
      final tileFinder = find.widgetWithText(ListTile, '终端字号');
      await tester.scrollUntilVisible(tileFinder, 100);
      await tester.pumpAndSettle();
      expect(tileFinder, findsOneWidget);
      expect(find.text('14 pt'), findsOneWidget);

      // Increase font size via + button
      final increaseFinder = find.byTooltip('增大字号').last;
      await tester.tap(increaseFinder);
      await tester.pumpAndSettle();
      expect(settings.terminalFontSize, 15.0);

      // Decrease font size via - button
      final decreaseFinder = find.byTooltip('减小字号').last;
      await tester.tap(decreaseFinder);
      await tester.pumpAndSettle();
      expect(settings.terminalFontSize, 14.0);

      // Open dialog by tapping tile
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('终端字号'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);

      // Tap done
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('TerminalView: textStyle uses terminalFontSize from settings', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setTerminalFontSize(18.0);

      final terminalProvider = TerminalProvider();
      final session = terminalProvider.createSession(
        name: 'test-session',
        autoStartProcess: false,
        activate: true,
      );
      session.terminal.write('Test Terminal Output\r\n');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TerminalView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that xterm.TerminalView receives fontSize 18.0
      final termView = tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
      expect(termView.textStyle.fontSize, 18.0);

      // Change font size in settings
      await settings.setTerminalFontSize(22.0);
      await tester.pumpAndSettle();

      final updatedTermView = tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
      expect(updatedTermView.textStyle.fontSize, 22.0);
    });

    testWidgets('TerminalView: two-finger pinch-to-zoom scales font size and persists', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setTerminalFontSize(14.0);

      final terminalProvider = TerminalProvider();
      final session = terminalProvider.createSession(
        name: 'pinch-session',
        autoStartProcess: false,
        activate: true,
      );
      session.terminal.write('Hello Pinch Zoom\r\n');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: TerminalView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(xterm.TerminalView));

      // Simulate pinch zoom with two touch pointers
      final touch1 = await tester.startGesture(center - const Offset(40, 0), kind: PointerDeviceKind.touch, pointer: 101);
      final touch2 = await tester.startGesture(center + const Offset(40, 0), kind: PointerDeviceKind.touch, pointer: 102);
      await tester.pump();

      // Move fingers apart: distance doubles from 80 to 160 -> scale ~ 2.0
      await touch1.moveTo(center - const Offset(80, 0));
      await touch2.moveTo(center + const Offset(80, 0));
      await tester.pump();

      final scaledTermView = tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
      expect(scaledTermView.textStyle.fontSize, greaterThan(14.0));

      // Release fingers
      await touch1.up();
      await touch2.up();
      await tester.pumpAndSettle();

      // Settings should now be updated and persisted
      expect(settings.terminalFontSize, greaterThan(14.0));
    });

    testWidgets('TerminalView gesture: Touch down does NOT request keyboard; Long press selects text without keyboard pop-up', (tester) async {
      int textInputAttachCount = 0;
      int textInputShowCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (MethodCall methodCall) async {
          if (methodCall.method == 'TextInput.attach') {
            textInputAttachCount++;
            return null;
          }
          if (methodCall.method == 'TextInput.show') {
            textInputShowCount++;
            return null;
          }
          return null;
        },
      );

      final settings = SettingsProvider();
      await settings.init();

      final terminalProvider = TerminalProvider();
      final session = terminalProvider.createSession(
        name: 'gesture-session',
        autoStartProcess: false,
        activate: true,
      );
      session.terminal.write('apple banana cherry\r\n');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<TerminalProvider>.value(value: terminalProvider),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: TerminalView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final targetPos = tester.getTopLeft(find.byType(xterm.TerminalView)) + const Offset(20, 20);

      textInputShowCount = 0;

      // 1. Touch down on screen
      final gesture = await tester.startGesture(targetPos, kind: PointerDeviceKind.touch, pointer: 201);
      await tester.pump();

      // Crucial: PointerDown must NOT show the keyboard!
      expect(textInputShowCount, 0, reason: 'Touch down must not optimistically request soft keyboard');

      // 2. Hold to long-press (> 500ms)
      await tester.pump(const Duration(milliseconds: 600));

      // Word should now be selected, and keyboard should STILL not have been shown!
      final termView = tester.widget<xterm.TerminalView>(find.byType(xterm.TerminalView));
      expect(termView.controller?.selection, isNotNull);
      expect(termView.controller?.selection!.isCollapsed, isFalse);
      expect(textInputShowCount, 0, reason: 'Long press must not show soft keyboard');

      // 3. Lift finger: Floating menu (复制, 粘贴, 全选) should appear
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('复制'), findsOneWidget);
      expect(textInputShowCount, 0, reason: 'Lifting finger after long-press selection must not show soft keyboard');

      // 4. Tap with active selection: Clears selection and does NOT open keyboard
      await tester.tapAt(targetPos + const Offset(100, 100));
      await tester.pumpAndSettle();

      expect(termView.controller?.selection, isNull);
      expect(find.text('复制'), findsNothing);
      expect(textInputShowCount, 0, reason: 'Tapping to clear selection must not open soft keyboard');

      // 5. Single tap when there is NO selection: Now opens the keyboard!
      await tester.tapAt(targetPos + const Offset(100, 100));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));

      expect(textInputShowCount, greaterThanOrEqualTo(1), reason: 'Single tap with no selection must open soft keyboard');
    });
  });
}
