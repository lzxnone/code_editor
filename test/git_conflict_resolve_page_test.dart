import 'dart:io';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/git_model.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/widgets/git/git_conflict_resolve_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File conflictFile;
  late GitProvider gitProvider;
  late TabProvider tabProvider;
  late SettingsProvider settingsProvider;

  const conflictContent = 'first line\n'
      '<<<<<<< HEAD\n'
      'current line 1\n'
      'current line 2\n'
      '=======\n'
      'incoming line 1\n'
      '>>>>>>> feature/test\n'
      'last line\n';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('git_conflict_test_');
    conflictFile = File(p.join(tempDir.path, 'conflict_sample.txt'));
    conflictFile.writeAsStringSync(conflictContent);

    gitProvider = GitProvider();
    tabProvider = TabProvider();
    settingsProvider = SettingsProvider();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gitProvider),
        ChangeNotifierProvider.value(value: tabProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: GitConflictResolvePage(
          file: GitConflictedFile(
            relativePath: 'conflict_sample.txt',
            absolutePath: conflictFile.path,
            type: GitConflictType.bothModified,
          ),
          gitProvider: gitProvider,
          initialContent: conflictContent,
        ),
      ),
    );
  }

  testWidgets('GitConflictResolvePage 成功渲染 VS Code 风格 CodeLens 与标头色带', (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 验证文件名与未解决徽标
    expect(find.text('conflict_sample.txt'), findsOneWidget);
    expect(find.text('1 未解决'), findsOneWidget);

    // 2. 验证 CodeLens 按钮（紧凑模式下自适应短文案）
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('传入'), findsOneWidget);
    expect(find.text('双方'), findsOneWidget);
    expect(find.text('对比'), findsOneWidget);

    // 3. 验证标头带与分隔线
    expect(find.textContaining('<<<<<<< HEAD'), findsOneWidget);
    expect(find.text('======='), findsOneWidget);
    expect(find.textContaining('>>>>>>> feature/test'), findsOneWidget);

    // 4. 验证底部按钮
    expect(find.byKey(const ValueKey('git_conflict_edit_manually')), findsOneWidget);
    expect(find.byKey(const ValueKey('git_conflict_save_and_mark')), findsOneWidget);
  });

  testWidgets('点击「对比查看」能够弹出差异比对弹窗', (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 点击对比查看
    await tester.tap(find.text('对比'));
    await tester.pumpAndSettle();

    // 验证对比弹窗开启
    expect(find.text('冲突对比 · 第 1 处'), findsOneWidget);
    expect(find.textContaining('当前侧: HEAD'), findsOneWidget);
    expect(find.textContaining('传入侧: feature/test'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 关闭弹窗
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('冲突对比 · 第 1 处'), findsNothing);
  });

  testWidgets('点击「采用当前侧」正确替换该冲突块并更新状态为已解决', (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 点击采用当前侧并在真实异步环境中等待文件写入与状态更新
    await tester.runAsync(() async {
      await tester.tap(find.text('当前'));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 验证冲突标记消除，状态变为已全部解决
    expect(find.text('已全部解决'), findsOneWidget);
    expect(find.text('冲突已解决 · 保存并提交'), findsOneWidget);

    // 验证磁盘文件内容确实被写入
    final updatedContent = conflictFile.readAsStringSync();
    expect(updatedContent.contains('<<<<<<<'), isFalse);
    expect(updatedContent.contains('current line 1'), isTrue);
    expect(updatedContent.contains('incoming line 1'), isFalse);
  });

  testWidgets('当遇到嵌套/畸形冲突标记时，页面展示「标记异常」徽标与警示横幅，且绝不误显「已全部解决」', (tester) async {
    const malformedContent = '''
<<<<<<< HEAD
<<<<<<< ours
VERSION-A
=======
VERSION-B
>>>>>>> theirs
=======
VERSION-C
>>>>>>> 123456
''';
    final malformedFile = File(p.join(tempDir.path, 'nested.txt'))..writeAsStringSync(malformedContent);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gitProvider),
          ChangeNotifierProvider.value(value: tabProvider),
          ChangeNotifierProvider.value(value: settingsProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: GitConflictResolvePage(
            file: GitConflictedFile(
              relativePath: 'nested.txt',
              absolutePath: malformedFile.path,
              type: GitConflictType.bothModified,
            ),
            gitProvider: gitProvider,
            initialContent: malformedContent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 验证顶栏展示「标记异常」，绝不显示「已全部解决」
    expect(find.text('标记异常'), findsOneWidget);
    expect(find.text('已全部解决'), findsNothing);

    // 2. 验证页面顶部悬浮警告横幅
    expect(find.textContaining('检测到冲突标记嵌套或不完整'), findsOneWidget);

    // 3. 底栏不可显示「冲突已解决 · 保存并提交」
    expect(find.text('冲突已解决 · 保存并提交'), findsNothing);
  });

  testWidgets('极窄屏幕（如 240px 宽度）下 CodeLens 操作栏不会触发 RenderFlex 溢出，且支持水平拖动交互', (tester) async {
    tester.view.physicalSize = const Size(240, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 确认没有 RenderFlex overflow 异常
    expect(tester.takeException(), isNull);

    // 验证 CodeLens 容器中的 SingleChildScrollView
    final horizontalScrollView = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollView, findsWidgets);

    // 进行水平拖动手势滑动
    await tester.drag(horizontalScrollView.first, const Offset(-100, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('点击底栏「手动编辑」按钮能够正常触发并打开文件', (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final editBtn = find.byKey(const ValueKey('git_conflict_edit_manually'));
    expect(editBtn, findsOneWidget);

    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}



