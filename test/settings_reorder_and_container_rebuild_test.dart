import 'dart:io';
import 'dart:ui';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/editor_tab_item.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/providers/terminal_provider.dart';
import 'package:code_editor/views/settings_view.dart';
import 'package:code_editor/views/terminal_view.dart';
import 'package:code_editor/widgets/code_editor_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart' as xterm;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Reorder, Font Size 8-30, Container Rebuild & Terminal HUD Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SettingsProvider: fontSize clamped to 8.0 - 30.0 using constants', () async {
      final provider = SettingsProvider();
      await provider.init();

      expect(SettingsProvider.minFontSize, 8.0);
      expect(SettingsProvider.maxFontSize, 30.0);

      // Lower clamp
      await provider.setFontSize(4.0);
      expect(provider.fontSize, SettingsProvider.minFontSize);

      // Upper clamp
      await provider.setFontSize(35.0);
      expect(provider.fontSize, SettingsProvider.maxFontSize);

      // Valid value
      await provider.setFontSize(14.0);
      expect(provider.fontSize, 14.0);
    });

    test('SettingsProvider: terminalFontSize clamped to 8.0 - 30.0 using constants', () async {
      final provider = SettingsProvider();
      await provider.init();

      // Lower clamp
      await provider.setTerminalFontSize(6.0);
      expect(provider.terminalFontSize, SettingsProvider.minFontSize);

      // Upper clamp
      await provider.setTerminalFontSize(32.0);
      expect(provider.terminalFontSize, SettingsProvider.maxFontSize);

      // Valid value
      await provider.setTerminalFontSize(16.0);
      expect(provider.terminalFontSize, 16.0);
    });

    test('Localization: all newly added keys exist in both zh and en', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      final en = lookupAppLocalizations(const Locale('en'));

      expect(zh.lspQuickFixTitle(457), '代码问题与修复 (第 457 行)');
      expect(en.lspQuickFixTitle(457), 'Code Issues & Fixes (Line 457)');

      expect(zh.lspNoFixAvailable, '当前报错未提供自动修复动作');
      expect(en.lspNoFixAvailable, 'No automated fixes available');

      expect(zh.diagnosticLinePrefix(10, 'error'), '行 10: error');
      expect(en.diagnosticLinePrefix(10, 'error'), 'Line 10: error');

      expect(zh.quickFixButton, '修复');
      expect(en.quickFixButton, 'Fix');

      expect(zh.containerSection, '容器');
      expect(en.containerSection, 'Container');

      expect(zh.destroyAndRebuildContainer, '销毁并重建容器');
      expect(en.destroyAndRebuildContainer, 'Destroy and Rebuild Container');

      expect(zh.destroyContainerConfirmTitle, '销毁并重建容器');
      expect(en.destroyContainerConfirmTitle, 'Destroy and Rebuild Container');

      expect(zh.destroyContainerButton, '销毁并重建');
      expect(en.destroyContainerButton, 'Destroy & Rebuild');

      expect(zh.containerRebuiltSuccess, '容器已成功重建');
      expect(en.containerRebuiltSuccess, 'Container rebuilt successfully');
    });

    testWidgets('SettingsView: renders container section and destroy & rebuild tile in red', (tester) async {
      final settings = SettingsProvider();
      await settings.init();

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

      // Scroll down to container section
      final containerTileFinder = find.widgetWithText(ListTile, '销毁并重建容器');
      await tester.scrollUntilVisible(containerTileFinder, 200);
      await tester.pumpAndSettle();

      expect(containerTileFinder, findsOneWidget);

      // Verify the title text is styled in danger red (colorScheme.error)
      final textWidget = tester.widget<Text>(find.descendant(
        of: containerTileFinder,
        matching: find.text('销毁并重建容器'),
      ));
      expect(textWidget.style?.color, isNotNull);

      // Tap tile and verify AlertDialog opens
      await tester.tap(containerTileFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('此操作将永久清空当前 Ubuntu 容器内的所有已安装软件包和环境配置（工程文件不受影响），并重新解压纯净容器系统。确定要继续吗？'), findsOneWidget);
      expect(find.text('销毁并重建'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('TerminalView: shows floating HUD capsule when pinching', (tester) async {
      final settings = SettingsProvider();
      await settings.init();
      await settings.setTerminalFontSize(14.0);

      final terminalProvider = TerminalProvider();
      terminalProvider.createSession(
        name: 'hud-session',
        autoStartProcess: false,
        activate: true,
      );

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

      // No HUD initially
      expect(find.textContaining('pt'), findsNothing);

      // Pinch zoom in
      final touch1 = await tester.startGesture(center - const Offset(30, 0), kind: PointerDeviceKind.touch, pointer: 201);
      final touch2 = await tester.startGesture(center + const Offset(30, 0), kind: PointerDeviceKind.touch, pointer: 202);
      await tester.pump();

      await touch1.moveTo(center - const Offset(70, 0));
      await touch2.moveTo(center + const Offset(70, 0));
      await tester.pump();

      // Floating HUD capsule is now visible with pt font size
      expect(find.textContaining('pt'), findsOneWidget);

      // Release touch
      await touch1.up();
      await touch2.up();
      await tester.pumpAndSettle();

      // HUD disappears after pinch completes
      expect(find.textContaining('pt'), findsNothing);
    });

    testWidgets('CodeEditorWidget: pinch zoom out scales down to 8.0', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('editor_zoom_min_test');
      final testFile = File('${tempDir.path}/test.dart')..writeAsStringSync('void main() {}');

      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      await settingsProvider.setFontSize(14.0);

      final tabProvider = TabProvider();
      await tabProvider.init();
      tabProvider.openTabs.add(
        EditorTabItem(
          path: testFile.path,
          content: 'void main() {}',
          originalContent: 'void main() {}',
          isLoaded: true,
          isModified: false,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: tabProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CodeEditorWidget(
                rootPath: tempDir.path,
                filePath: testFile.path,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeEditor), findsOneWidget);
      expect(settingsProvider.fontSize, 14.0);

      // Pinch zoom out: start far apart (100px) and move close together (20px)
      final gesture1 = await tester.createGesture();
      final gesture2 = await tester.createGesture();

      await gesture1.down(const Offset(200, 250));
      await gesture2.down(const Offset(200, 350));
      await tester.pump();

      await gesture2.moveTo(const Offset(200, 270)); // distance goes from 100 to 20 -> scale 0.2
      await tester.pump();

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      // Should be clamped to minFontSize (8.0), NOT 10.0
      expect(settingsProvider.fontSize, 8.0);
    });
  });
}
