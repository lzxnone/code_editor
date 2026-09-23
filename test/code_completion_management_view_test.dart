import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/views/code_completion_management_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settingsProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsProvider = SettingsProvider();
    await settingsProvider.init();
  });

  Widget buildTestWidget({Locale locale = const Locale('zh')}) {
    return ChangeNotifierProvider<SettingsProvider>.value(
      value: settingsProvider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const CodeCompletionManagementView(),
      ),
    );
  }

  testWidgets('代码补全管理页面展示总开关与两个分开关，且支持中文多语言', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 验证总开关
    final masterSwitch = find.byKey(const ValueKey('lsp_master_switch'));
    expect(masterSwitch, findsOneWidget);
    expect(find.text('后端语言服务补全'), findsOneWidget);

    // 2. 验证分开关 1：代码补全
    final completionSwitch = find.byKey(const ValueKey('code_completion_sub_switch'));
    expect(completionSwitch, findsOneWidget);
    expect(find.text('代码补全'), findsOneWidget);
    expect(find.text('输入时实时提示函数、变量与语法补全'), findsOneWidget);

    // 3. 验证分开关 2：代码纠错
    final diagnosticsSwitch = find.byKey(const ValueKey('code_diagnostics_sub_switch'));
    expect(diagnosticsSwitch, findsOneWidget);
    expect(find.text('代码纠错'), findsOneWidget);
    expect(find.text('实时语法检查、错误波浪线提示与修复建议'), findsOneWidget);

    // 4. 默认总开关开启时，两个分开关均为启用状态 (onChanged != null)
    final completionTile = tester.widget<SwitchListTile>(completionSwitch);
    final diagnosticsTile = tester.widget<SwitchListTile>(diagnosticsSwitch);
    expect(completionTile.onChanged, isNotNull);
    expect(diagnosticsTile.onChanged, isNotNull);
    expect(completionTile.value, isTrue);
    expect(diagnosticsTile.value, isTrue);
  });

  testWidgets('代码补全管理页面支持英文多语言展示', (tester) async {
    await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Backend Language Server'), findsOneWidget);
    expect(find.text('Code Completion'), findsOneWidget);
    expect(find.text('Code Correction'), findsOneWidget);
  });

  testWidgets('当总开关关闭时，两个分开关被禁用（onChanged == null）', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final masterSwitch = find.byKey(const ValueKey('lsp_master_switch'));
    final completionSwitch = find.byKey(const ValueKey('code_completion_sub_switch'));
    final diagnosticsSwitch = find.byKey(const ValueKey('code_diagnostics_sub_switch'));

    // 点击总开关以关闭
    await tester.tap(masterSwitch);
    await tester.pumpAndSettle();

    expect(settingsProvider.enableLspCompletion, isFalse);

    // 验证总开关关闭后，两个分开关的 onChanged 为 null (禁用状态)
    final disabledCompletionTile = tester.widget<SwitchListTile>(completionSwitch);
    final disabledDiagnosticsTile = tester.widget<SwitchListTile>(diagnosticsSwitch);
    expect(disabledCompletionTile.onChanged, isNull);
    expect(disabledDiagnosticsTile.onChanged, isNull);

    // 点击分开关不会发生任何状态变更
    await tester.tap(completionSwitch);
    await tester.pumpAndSettle();
    expect(settingsProvider.enableCodeCompletion, isTrue);

    // 重新开启总开关后，两个分开关重新恢复启用
    await tester.tap(masterSwitch);
    await tester.pumpAndSettle();

    expect(settingsProvider.enableLspCompletion, isTrue);
    final reenabledCompletionTile = tester.widget<SwitchListTile>(completionSwitch);
    final reenabledDiagnosticsTile = tester.widget<SwitchListTile>(diagnosticsSwitch);
    expect(reenabledCompletionTile.onChanged, isNotNull);
    expect(reenabledDiagnosticsTile.onChanged, isNotNull);
  });

  testWidgets('总开关开启时，点击两个分开关可正常独立切换各自状态', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final completionSwitch = find.byKey(const ValueKey('code_completion_sub_switch'));
    final diagnosticsSwitch = find.byKey(const ValueKey('code_diagnostics_sub_switch'));

    // 切换代码补全分开关
    await tester.tap(completionSwitch);
    await tester.pumpAndSettle();
    expect(settingsProvider.enableCodeCompletion, isFalse);

    // 切换代码纠错分开关
    await tester.tap(diagnosticsSwitch);
    await tester.pumpAndSettle();
    expect(settingsProvider.enableCodeDiagnostics, isFalse);
  });
}
