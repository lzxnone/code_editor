import 'dart:io';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/git_model.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/git_service.dart';
import 'package:code_editor/utils/git_error_mapper.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/git/git_panel_widget.dart';
import 'package:code_editor/widgets/git/git_remote_management_sheet.dart';
import 'package:code_editor/widgets/git/git_sync_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late GitProvider gitProvider;
  late ProjectProvider projectProvider;
  late TabProvider tabProvider;
  late SearchProvider searchProvider;

  /// 记录流式执行的命令串
  late List<String> executedCommands;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('git_sync_bar_test_');
    executedCommands = [];
    GitService.instance.resetForTesting();
    GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
      if (args.contains('--version')) {
        return ProcessResult(0, 0, 'git version 2.45.0\n', '');
      }
      return ProcessResult(0, 0, '', '');
    };
    GitService.instance.streamRunner = ({
      required String executable,
      required List<String> arguments,
      required String workspacePath,
      required String? containerWorkDir,
      void Function(String chunk)? onOutput,
      HeadlessCancelToken? cancelToken,
      Duration timeout = const Duration(minutes: 5),
    }) async {
      executedCommands.add(executable);
      return ProcessResult(1, 0, '', '');
    };
    gitProvider = GitProvider();
    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    searchProvider = SearchProvider()..bindRootPath(tempDir.path);
  });

  tearDown(() {
    GitService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Widget buildApp({Widget? home}) {
    return ChangeNotifierProvider<GitProvider>.value(
      value: gitProvider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: home ?? const Scaffold(body: GitPanelWidget()),
      ),
    );
  }

  /// 构造一个"已配置 origin 的正常仓库"状态
  void seedRepo({
    GitBranchTracking? tracking,
    int changedCount = 0,
    List<GitRemote>? remotes,
  }) {
    final repoPath = p.normalize(tempDir.path);
    gitProvider.setStateForTesting(
      rootPath: repoPath,
      currentRepoPath: repoPath,
      currentBranch: 'main',
      gitInstalled: true,
      repositories: [
        GitRepositoryInfo(
          rootPath: repoPath,
          name: 'proj',
          isRoot: true,
          currentBranch: 'main',
        ),
      ],
      changedFiles: List.generate(
        changedCount,
        (i) => GitFileStatus(
          path: p.normalize(p.join(repoPath, 'f$i.dart')),
          relativePath: 'f$i.dart',
          statusType: GitFileStatusType.modified,
        ),
      ),
      remotes: remotes ??
          const [
            GitRemote(name: 'origin', fetchUrl: 'https://github.com/me/repo.git'),
          ],
      tracking: tracking,
    );
  }

  group('GitSyncBar 渲染', () {
    /// 打开云按钮的动作菜单
    Future<void> openSyncMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('git_sync_cloud_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('未打开仓库时不渲染同步工具条', (tester) async {
      gitProvider.bindRootPath(null);
      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsNothing);
    });

    testWidgets('未配置远程仓库时展示添加入口而非无效按钮', (tester) async {
      seedRepo(remotes: const []);

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('git_sync_add_remote_guide_button')), findsOneWidget);
      expect(find.text('尚未配置远程仓库'), findsOneWidget);
      // 关键：没有任何会必然失败的动作入口
      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsNothing);
    });

    testWidgets('有追踪上游但远程列表为空时仍展示同步按钮', (tester) async {
      // 例如 remote 定义丢失但上游引用残留，此时不该屏蔽同步能力
      seedRepo(
        remotes: const [],
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main', ahead: 1),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('git_sync_add_remote_guide_button')), findsNothing);
    });

    testWidgets('云按钮展开后包含 抓取/拉取/推送 三个动作与计数', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 2,
          behind: 3,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 收起状态下只有一个云按钮，不再占据大半行宽
      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
      expect(find.text('抓取'), findsNothing);

      await openSyncMenu(tester);
      expect(find.text('抓取'), findsOneWidget);
      expect(find.text('拉取'), findsOneWidget);
      expect(find.text('推送'), findsOneWidget);
      // 菜单项上带计数
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('云按钮为纯图标，计数只在菜单中呈现', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 2,
          behind: 3,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 与「分支」行的更多按钮一致：纯图标、不带文字、不带角标
      expect(find.text('同步'), findsNothing);
      expect(find.text('↓3'), findsNothing);
      expect(find.text('↑2'), findsNothing);
      // 落后时图标切换为下拉箭头，提示"有东西要拉"
      expect(find.byIcon(Icons.arrow_downward_rounded), findsWidgets);

      await openSyncMenu(tester);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('仅领先时云按钮图标切换为上传', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 4,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
      expect(find.text('↑4'), findsNothing);
    });

    testWidgets('无上游时菜单项变为「发布分支」', (tester) async {
      seedRepo(tracking: const GitBranchTracking(branch: 'main'));

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();
      await openSyncMenu(tester);

      expect(find.text('发布分支'), findsOneWidget);
      expect(find.text('推送'), findsNothing);
    });

    testWidgets('上游被删除时同样视为需要发布分支', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          isGone: true,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();
      await openSyncMenu(tester);

      expect(find.text('发布分支'), findsOneWidget);
    });

    testWidgets('进行中的操作展示取消按钮，且云按钮被禁用', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
        changedCount: 0,
      );
      gitProvider.setStateForTesting(
        isFetching: true,
        remoteProgress: const GitOperationProgress(
          phase: 'fetch',
          percent: 45,
          raw: 'Receiving objects:  45% (450/1000)',
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      // 进度条为不确定态动画（无百分比），pumpAndSettle 永远不会稳定，只能用 pump
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('git_sync_cancel_button')), findsOneWidget);
      // 进行中时云按钮不可再点，避免并发操作打爆索引锁
      final button = tester.widget<PopupMenuButton<Object?>>(
        find.byKey(const ValueKey('git_sync_cloud_button')),
      );
      expect(button.enabled, isFalse);
    });

    testWidgets('错误面板为推送被拒提供「先拉取再推送」', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );
      gitProvider.setStateForTesting(
        lastRemoteError: const GitErrorInfo(
          kind: GitOperationErrorKind.nonFastForward,
          fixAction: GitErrorFixAction.pullThenPush,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 文案来自 l10n（中文环境），而非硬编码
      expect(find.text('推送被拒绝：远端存在本地尚无的提交'), findsOneWidget);
      expect(find.byKey(const ValueKey('git_error_fix_pull_then_push')), findsOneWidget);
      expect(find.text('先拉取再推送'), findsOneWidget);
    });

    testWidgets('错误面板按错误类型取词，无权限时提示 Fork', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );
      gitProvider.setStateForTesting(
        lastRemoteError: const GitErrorInfo(
          kind: GitOperationErrorKind.writePermissionDenied,
          fixAction: GitErrorFixAction.openAccountManagement,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.text('当前账号对该仓库没有写权限'), findsOneWidget);
      expect(find.textContaining('Fork'), findsOneWidget);
      expect(find.byKey(const ValueKey('git_error_fix_accounts')), findsOneWidget);
    });

    testWidgets('兜底错误展示 git 原始输出行并可展开完整日志', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );
      gitProvider.setStateForTesting(
        lastRemoteError: const GitErrorInfo(
          kind: GitOperationErrorKind.unknown,
          rawDetail: 'fatal: the remote end hung up unexpectedly',
        ),
        remoteLog: 'fatal: the remote end hung up unexpectedly\nsome more output',
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 原始英文错误行直接展示（便于精确检索）
      expect(find.text('Git 操作失败'), findsOneWidget);
      expect(find.text('fatal: the remote end hung up unexpectedly'), findsOneWidget);

      // 默认折叠，点击后展开完整输出
      expect(find.text('some more output'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('git_error_toggle_raw_log')));
      await tester.pumpAndSettle();
      expect(find.textContaining('some more output'), findsOneWidget);
    });

    testWidgets('冲突错误提供「放弃本次变基」', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );
      gitProvider.setStateForTesting(
        lastRemoteError: const GitErrorInfo(
          kind: GitOperationErrorKind.conflictDetected,
          fixAction: GitErrorFixAction.abortRebase,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('git_error_fix_abort_rebase')), findsOneWidget);
    });

    testWidgets('操作进行中显示已用时间计时', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );
      gitProvider.setStateForTesting(
        isFetching: true,
        remoteProgress: const GitOperationProgress(
          phase: 'fetch',
          raw: 'remote: Enumerating objects: 2233, done.',
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 65));

      // 无百分比的阶段靠"已用时间"判断是否卡死
      expect(find.textContaining('已用'), findsOneWidget);
      expect(find.textContaining('Enumerating objects'), findsWidgets);
    });
  });

  group('GitSyncBar 响应式布局（窄屏不溢出）', () {
    /// 在指定宽度下渲染同步条
    Future<void> pumpAtWidth(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<GitProvider>.value(
          value: gitProvider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: const GitSyncBar()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('回归：窄屏抽屉宽度下不再水平溢出', (tester) async {
      // 真实事故：360dp 手机打开抽屉后内容区仅剩 ~170dp，
      // 4 个带文字的按钮造成 "RIGHT OVERFLOWED BY 12 PIXELS"
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 3,
          behind: 1,
        ),
      );

      for (final width in <double>[150, 170, 180, 200, 240, 320]) {
        await pumpAtWidth(tester, width);
        expect(
          tester.takeException(),
          isNull,
          reason: '宽度 $width 下发生了布局溢出',
        );
      }
    });

    testWidgets('极窄宽度下选定条与云按钮都保留且不溢出', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 3,
          behind: 1,
        ),
      );

      // 170dp 容器 ≈ 360dp 手机抽屉里的实际可用宽度。
      // 结构改为「Expanded 选定条 + 固定 32dp 按钮」后不再依赖像素分配，
      // 因此任意宽度都不会溢出。
      for (final width in <double>[120, 150, 170, 200]) {
        await pumpAtWidth(tester, width);
        expect(find.byKey(const ValueKey('git_remote_selector_bar')), findsOneWidget);
        expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: '宽度 $width 下发生了布局溢出',
        );
      }
    });

    testWidgets('选定条占满剩余宽度，远程名用等宽字体展示', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );

      await pumpAtWidth(tester, 300);

      expect(find.byKey(const ValueKey('git_remote_selector_bar')), findsOneWidget);
      expect(find.text('origin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('极窄宽度下远程名仍可见且不溢出', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );

      await pumpAtWidth(tester, 150);

      expect(find.text('origin'), findsOneWidget);
      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('云按钮始终为纯图标，任何宽度都不显示文字', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 2,
        ),
      );

      for (final width in <double>[150, 300, 360, 500]) {
        await pumpAtWidth(tester, width);
        expect(find.text('同步'), findsNothing, reason: '宽度 $width 下出现了按钮文字');
        expect(tester.takeException(), isNull);
      }
    });


    testWidgets('中文长菜单项「发布分支」在窄屏不溢出', (tester) async {
      // 无上游时菜单文案变长，是中文界面下最容易溢出的分支
      seedRepo(tracking: const GitBranchTracking(branch: 'main'));

      for (final width in <double>[150, 170, 200, 240, 320]) {
        await pumpAtWidth(tester, width);
        expect(
          tester.takeException(),
          isNull,
          reason: '「发布分支」在宽度 $width 下发生了布局溢出',
        );
      }
    });

    testWidgets('英文界面下长菜单项不溢出', (tester) async {
      seedRepo(tracking: const GitBranchTracking(branch: 'main'));

      await tester.pumpWidget(
        ChangeNotifierProvider<GitProvider>.value(
          value: gitProvider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 170, child: GitSyncBar()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
    });
  });

  group('GitSyncBar 交互', () {
    /// 展开云按钮菜单并点选指定动作
    Future<void> chooseSyncAction(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const ValueKey('git_sync_cloud_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('菜单中选「抓取」执行 fetch 命令', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 真实异步流程（含 toast 计时器）需在 runAsync 中完成
      await tester.runAsync(() async {
        await chooseSyncAction(tester, '抓取');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(executedCommands.length, equals(1));
      expect(executedCommands.first, contains('fetch --progress --prune origin'));

      // 排空 toast 计时器
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('有未提交改动时选「拉取」弹出三选一，取消则不执行任何命令', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main', behind: 1),
        changedCount: 2,
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      await chooseSyncAction(tester, '拉取');

      // 弹窗出现且包含三个出口
      expect(find.text('存在未提交的改动'), findsOneWidget);
      expect(find.text('贮藏并拉取'), findsOneWidget);
      expect(find.text('先去提交'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 关键：取消后绝不静默执行 stash 或 pull
      expect(executedCommands, isEmpty);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('无未提交改动时选「拉取」直接执行 pull --rebase', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main', behind: 1),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 真实异步流程（含凭据灌注与 toast 计时器）需在 runAsync 中完成
      await tester.runAsync(() async {
        await chooseSyncAction(tester, '拉取');
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump();

      expect(executedCommands.length, equals(1));
      expect(executedCommands.first, contains('pull --progress --rebase origin main'));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('选「推送」执行 push 命令', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main', ahead: 1),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await chooseSyncAction(tester, '推送');
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump();

      expect(executedCommands.length, equals(1));
      expect(executedCommands.first, contains('push --progress origin main'));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('选「发布分支」推送带 --set-upstream', (tester) async {
      seedRepo(tracking: const GitBranchTracking(branch: 'main'));

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 真实异步流程（含凭据灌注与 toast 计时器）需在 runAsync 中完成
      await tester.runAsync(() async {
        await chooseSyncAction(tester, '发布分支');
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump();

      expect(executedCommands.length, equals(1));
      expect(executedCommands.first, contains('--set-upstream'));
      expect(executedCommands.first, isNot(contains('--force')));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('远程管理已移出同步条，改由更多操作菜单进入', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 同步条上不再有独立的远程管理按钮（避免与「更多操作」重复）
      expect(find.byKey(const ValueKey('git_sync_remote_button')), findsNothing);
      expect(find.byType(GitRemoteManagementSheet), findsNothing);
    });
  });

  group('GitRemoteManagementSheet', () {
    testWidgets('无远端时展示引导与添加入口', (tester) async {
      seedRepo(remotes: const []);

      await tester.pumpWidget(buildApp(
        home: const Scaffold(body: GitRemoteManagementSheet()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('尚未配置远程仓库'), findsOneWidget);
      expect(find.byKey(const ValueKey('git_remote_add_button')), findsOneWidget);
    });

    testWidgets('添加远端时校验名称与地址必填', (tester) async {
      seedRepo(remotes: const []);

      await tester.pumpWidget(buildApp(
        home: const Scaffold(body: GitRemoteManagementSheet()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('git_remote_add_button')));
      await tester.pumpAndSettle();

      // 清空默认的 origin 名称后直接确认
      await tester.enterText(
        find.byKey(const ValueKey('git_remote_name_field')),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('git_remote_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.text('请输入远程名称'), findsOneWidget);
      expect(find.text('请输入远程地址'), findsOneWidget);
    });

    testWidgets('添加远端后执行 git remote add 并通知', (tester) async {
      seedRepo(remotes: const []);

      final executed = <List<String>>[];
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        executed.add(args);
        if (args.contains('remote') && args.contains('-v')) {
          return ProcessResult(
            0,
            0,
            'origin\thttps://github.com/me/repo.git (fetch)\n'
                'origin\thttps://github.com/me/repo.git (push)\n',
            '',
          );
        }
        return ProcessResult(0, 0, '', '');
      };

      await tester.pumpWidget(buildApp(
        home: const Scaffold(body: GitRemoteManagementSheet()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('git_remote_add_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('git_remote_name_field')),
        'origin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('git_remote_url_field')),
        'https://github.com/me/repo.git',
      );
      await tester.tap(find.byKey(const ValueKey('git_remote_confirm_button')));
      await tester.pumpAndSettle();

      expect(
        executed.any((args) =>
            args.length >= 4 &&
            args[0] == 'remote' &&
            args[1] == 'add' &&
            args[2] == 'origin'),
        isTrue,
      );

      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('多远程推送目标解析', () {
    /// 让 git 返回完整的仓库信息（远程列表 + 上游 + 可配置的 config 值）
    ///
    /// [branch] 同时决定 `git status` 汇报的当前分支与查询哪个分支的 config，
    /// 因此切换分支的测试必须同步改这个值。
    void seedGit({
      String? pushRemote,
      String? pushDefault,
      String? branchRemote,
      String? upstreamRef = 'upstream/main',
      String branch = 'main',
    }) {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.isNotEmpty && args[0] == 'config') {
          final key = args.length > 1 ? args[1] : '';
          String? value;
          if (key == 'branch.$branch.pushRemote') {
            value = pushRemote;
          } else if (key == 'remote.pushDefault') {
            value = pushDefault;
          } else if (key == 'branch.$branch.remote') {
            value = branchRemote;
          }
          return value == null
              ? ProcessResult(1, 1, '', '')
              : ProcessResult(0, 0, '$value\n', '');
        }
        if (args.contains('branch') && args.contains('--show-current')) {
          // getCurrentRefInfo 优先走这一条；缺了它就会落到 .git/HEAD 兜底，
          // 而测试目录没有真实 HEAD，最终返回硬编码的 'main'。
          return ProcessResult(0, 0, '$branch\n', '');
        }
        if (args.contains('remote') && args.contains('-v')) {
          return ProcessResult(
            0,
            0,
            'upstream\thttps://github.com/ggml-org/llama.cpp.git (fetch)\n'
                'upstream\thttps://github.com/ggml-org/llama.cpp.git (push)\n'
                'origin\thttps://github.com/lzxnone/llama.cpp.git (fetch)\n'
                'origin\thttps://github.com/lzxnone/llama.cpp.git (push)\n',
            '',
          );
        }
        if (args.contains('status')) {
          final buf = StringBuffer('# branch.head $branch\n');
          if (upstreamRef != null) {
            buf.writeln('# branch.upstream $upstreamRef');
            buf.writeln('# branch.ab +0 -0');
          }
          return ProcessResult(0, 0, buf.toString(), '');
        }
        return ProcessResult(0, 0, '', '');
      };
    }

    /// 走真实的 refresh() 流程加载仓库配置
    Future<void> loadForkRepo({
      String? pushRemote,
      String? pushDefault,
      String? branchRemote,
      String? upstreamRef = 'upstream/main',
      String branch = 'main',
    }) async {
      Directory(p.join(tempDir.path, '.git')).createSync(recursive: true);
      seedGit(
        pushRemote: pushRemote,
        pushDefault: pushDefault,
        branchRemote: branchRemote,
        upstreamRef: upstreamRef,
        branch: branch,
      );
      gitProvider = GitProvider();
      gitProvider.bindRootPath(tempDir.path);
      await gitProvider.refresh();
    }

    test('无任何配置时推送目标跟随上游远程', () async {
      await loadForkRepo();

      final target = gitProvider.pushTarget;
      expect(target.remote?.name, equals('upstream'));
      expect(target.source, equals(GitRemoteSource.upstream));
      // 上游与推送目标一致时，两者同值
      expect(gitProvider.fetchTarget?.name, equals('upstream'));
    });

    test('branch.<name>.pushRemote 优先级最高（fork 推送场景）', () async {
      // git config branch.main.pushRemote origin
      await loadForkRepo(pushRemote: 'origin');

      final target = gitProvider.pushTarget;
      expect(target.remote?.name, equals('origin'));
      expect(target.source, equals(GitRemoteSource.pushRemote));
      // 关键：拉取仍走 upstream，推送走 origin —— 这正是 fork 工作流
      expect(gitProvider.fetchTarget?.name, equals('upstream'));
    });

    test('remote.pushDefault 次之', () async {
      await loadForkRepo(pushDefault: 'origin');

      final target = gitProvider.pushTarget;
      expect(target.remote?.name, equals('origin'));
      expect(target.source, equals(GitRemoteSource.pushDefault));
    });

    test('fetch 目标优先 branch.<name>.remote（回归：不再固定抓 origin）', () async {
      // 分支配置 remote=upstream，但上游引用缺失
      await loadForkRepo(branchRemote: 'upstream', upstreamRef: null);

      // 修复的核心：fork 场景下抓取必须走上游，
      // 否则 upstream/* 永不更新，ahead/behind 会一直算错。
      expect(gitProvider.fetchTarget?.name, equals('upstream'));
    });

    test('缺少分支配置时 fetch 回退到 origin', () async {
      await loadForkRepo(branchRemote: null, upstreamRef: null);
      expect(gitProvider.fetchTarget?.name, equals('origin'));
    });

    test('pull 目标跟随上游远程', () async {
      await loadForkRepo(pushRemote: 'origin');
      // 即使推送被改到 origin，拉取仍应跟随上游
      expect(gitProvider.pullTarget?.name, equals('upstream'));
    });

    test('会话级覆盖优先于 git 配置，且可恢复自动解析', () async {
      await loadForkRepo(pushRemote: 'origin');

      gitProvider.setPushTargetOverride('upstream');
      expect(gitProvider.pushTarget.remote?.name, equals('upstream'));
      expect(gitProvider.pushTarget.source, equals(GitRemoteSource.manualOverride));
      expect(gitProvider.hasPushTargetOverride, isTrue);

      // 传 null 恢复按 git 配置自动解析
      gitProvider.setPushTargetOverride(null);
      expect(gitProvider.hasPushTargetOverride, isFalse);
      expect(gitProvider.pushTarget.remote?.name, equals('origin'));
      expect(gitProvider.pushTarget.source, equals(GitRemoteSource.pushRemote));
    });

    test('切换仓库会清空会话级覆盖', () async {
      await loadForkRepo();
      gitProvider.setPushTargetOverride('origin');
      expect(gitProvider.hasPushTargetOverride, isTrue);

      seedGit();
      gitProvider.bindRootPath('/other/project');
      expect(gitProvider.hasPushTargetOverride, isFalse);
    });

    test('切换分支会清空会话级覆盖（防止把分支选择带过去）', () async {
      await loadForkRepo(pushRemote: 'origin');
      // 用户在 main 上手动选了 upstream
      gitProvider.setPushTargetOverride('upstream');
      expect(gitProvider.pushTarget.remote?.name, equals('upstream'));

      // 切到 feature 分支：该分支自己的 pushRemote 是 origin
      seedGit(pushRemote: 'origin', branch: 'feature', upstreamRef: 'origin/feature');
      final res = await gitProvider.switchBranch('feature');
      expect(res.success, isTrue);

      // 关键：main 上的选择不能带到 feature 上，必须按 feature 自己的配置解析
      expect(gitProvider.hasPushTargetOverride, isFalse);
      expect(gitProvider.pushTarget.remote?.name, equals('origin'));
      expect(gitProvider.pushTarget.source, equals(GitRemoteSource.pushRemote));
    });

    test('覆盖指向的远程被删除后自动失效并回落', () async {
      await loadForkRepo(pushRemote: 'origin');
      // 覆盖到一个即将被删除的远程
      gitProvider.setPushTargetOverride('upstream');
      expect(gitProvider.pushTarget.remote?.name, equals('upstream'));

      // 模拟远程被删除后重新加载列表
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.contains('remote') && args.contains('-v')) {
          return ProcessResult(
            0,
            0,
            'origin\thttps://github.com/lzxnone/llama.cpp.git (fetch)\n'
                'origin\thttps://github.com/lzxnone/llama.cpp.git (push)\n',
            '',
          );
        }
        return ProcessResult(0, 0, '', '');
      };
      await gitProvider.reloadRemotes();

      // 不能静默继续用旧名字，也不能悄悄推到别的远程还不告诉用户
      expect(gitProvider.hasPushTargetOverride, isFalse);
      expect(gitProvider.pushTarget.remote?.name, equals('origin'));
      expect(gitProvider.pushTarget.source, equals(GitRemoteSource.pushRemote));
    });

    test('无远程时推送目标为空', () {
      gitProvider.setStateForTesting(
        rootPath: tempDir.path,
        currentRepoPath: tempDir.path,
        remotes: const [],
        tracking: const GitBranchTracking(branch: 'main'),
      );
      expect(gitProvider.pushTarget.remote, isNull);
      expect(gitProvider.pushTarget.source, equals(GitRemoteSource.none));
    });

    test('推送实际使用解析出的目标，而非固定 origin', () async {
      await loadForkRepo(pushRemote: 'origin');
      gitProvider.setPushTargetOverride('origin');
      executedCommands.clear();

      await gitProvider.push();

      expect(executedCommands.length, equals(1));
      expect(executedCommands.first, contains('push --progress origin main'));
      // 绝不推到上游（用户对上游没有写权限）
      expect(executedCommands.first, isNot(contains('upstream main')));
    });

    test('未配置 pushRemote 时推送跟随上游', () async {
      await loadForkRepo();
      executedCommands.clear();

      await gitProvider.push();

      expect(executedCommands.length, equals(1));
      expect(executedCommands.first, contains('push --progress upstream main'));
    });

    testWidgets('多远程时点击选定条可切换推送目标', (tester) async {
      await loadForkRepo();

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('git_remote_selector_bar')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('git_remote_selector_bar')));
      await tester.pumpAndSettle();

      // 列出全部远程，并标注哪个是上游
      expect(find.text('选择推送目标'), findsOneWidget);
      expect(find.byKey(const ValueKey('git_push_target_origin')), findsOneWidget);
      expect(find.byKey(const ValueKey('git_push_target_upstream')), findsOneWidget);
      expect(find.textContaining('上游（拉取）'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('git_push_target_origin')));
      await tester.pumpAndSettle();

      expect(gitProvider.pushTarget.remote?.name, equals('origin'));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('单一远程时点击选定条不弹出选择器', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitSyncBar())));
      await tester.pumpAndSettle();

      // 选定条仍然展示远程名，但只有一个时点击无意义
      expect(find.text('origin'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('git_remote_selector_bar')));
      await tester.pumpAndSettle();
      expect(find.text('选择推送目标'), findsNothing);
    });

    /// 在指定宽度下渲染并断言无溢出
    Future<void> pumpForkAt(WidgetTester tester, double width) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<GitProvider>.value(
          value: gitProvider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: const GitSyncBar()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('推送目标≠上游时各宽度都不溢出（回归）', (tester) async {
      // 真实事故：把「推送目标与上游不同」这句话塞进选择条当徽标，
      // 使选择条内出现第三个抢宽度的元素 —— 窄屏溢出 45px，
      // 且长远程名（upstream）被挤到看不见。
      await loadForkRepo(pushRemote: 'origin');
      expect(gitProvider.pushTarget.remote?.name, equals('origin'));

      for (final width in <double>[150, 170, 200, 300]) {
        await pumpForkAt(tester, width);
        expect(
          tester.takeException(),
          isNull,
          reason: '宽度 $width 下发生了布局溢出',
        );
      }
    });

    testWidgets('提示行在极窄宽度下自动换行而不溢出', (tester) async {
      await loadForkRepo(pushRemote: 'origin');

      // 提示行只有图标 + Expanded 文本（maxLines 2），结构上不会溢出；
      // 这里仍逐宽度验证，因为这句话比"推送目标与上游不同"长得多。
      for (final width in <double>[120, 150, 170, 320]) {
        await pumpForkAt(tester, width);
        expect(find.textContaining('拉取走'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: '提示行在宽度 $width 下发生了布局溢出',
        );
      }
    });

    testWidgets('选择器里上游角色与地址分两行，角色不会被 URL 挤掉', (tester) async {
      await loadForkRepo(pushRemote: 'origin');

      await pumpForkAt(tester, 320);
      await tester.tap(find.byKey(const ValueKey('git_remote_selector_bar')));
      await tester.pumpAndSettle();

      // 关键：URL 很长时「上游（拉取）」仍然完整可见
      expect(find.text('上游（拉取）'), findsOneWidget);
      expect(
        find.text('https://github.com/ggml-org/llama.cpp.git'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    });

    testWidgets('提示单独占一行，选择条仍完整展示远程名', (tester) async {
      await loadForkRepo(pushRemote: 'origin');

      await pumpForkAt(tester, 320);

      expect(find.text('拉取走 upstream，推送走 origin'), findsOneWidget);
      expect(find.text('origin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('推送目标与上游一致时不显示提示行', (tester) async {
      await loadForkRepo();

      await pumpForkAt(tester, 320);

      // 推送目标跟随上游（都是 upstream），无需额外提示，避免噪音
      expect(find.textContaining('拉取走'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('冲突状态探测', () {
    test('pull 撞冲突后必须立刻暴露冲突状态（回归）', () async {
      // 真实 bug：pull 失败分支只调 _loadRemoteStateOnly()，
      // 而读冲突状态的逻辑挂在 _loadCurrentRepoDetails() 里 ——
      // 结果冲突发生了但面板不知道，横幅不出现，用户找不到解决入口。
      final repoDir = Directory(p.join(tempDir.path, 'conflict_repo'))
        ..createSync(recursive: true);
      Directory(p.join(repoDir.path, '.git')).createSync(recursive: true);

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.isNotEmpty && args[0] == 'config') {
          return ProcessResult(1, 1, '', '');
        }
        if (args.contains('remote') && args.contains('-v')) {
          return ProcessResult(
            0,
            0,
            'origin\thttps://github.com/me/repo.git (fetch)\n'
                'origin\thttps://github.com/me/repo.git (push)\n',
            '',
          );
        }
        if (args.contains('status')) {
          return ProcessResult(0, 0, '# branch.head master\n# branch.ab +0 -0\n', '');
        }
        if (args.contains('diff') && args.contains('--diff-filter=U')) {
          return ProcessResult(0, 0, 'lib/a.dart\x00', '');
        }
        if (args.contains('branch') && args.contains('--show-current')) {
          return ProcessResult(0, 0, 'master\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      // pull 失败，并且仓库已进入 rebase 中断状态（文件系统上真实创建）
      GitService.instance.streamRunner = ({
        required String executable,
        required List<String> arguments,
        required String workspacePath,
        required String? containerWorkDir,
        void Function(String chunk)? onOutput,
        HeadlessCancelToken? cancelToken,
        Duration timeout = const Duration(minutes: 5),
      }) async {
        Directory(p.join(repoDir.path, '.git', 'rebase-merge'))
            .createSync(recursive: true);
        return ProcessResult(
          1,
          1,
          '',
          'CONFLICT (content): Merge conflict in lib/a.dart',
        );
      };

      final provider = GitProvider();
      provider.bindRootPath(repoDir.path);
      await provider.refresh();
      expect(provider.hasPendingOperation, isFalse, reason: '初始无冲突');

      final res = await provider.pull();
      expect(res.success, isFalse);

      // 关键断言：冲突必须已被探测到
      expect(provider.hasPendingOperation, isTrue);
      expect(provider.conflictState.operation, equals(GitPendingOperation.rebase));
      expect(provider.hasConflicts, isTrue);
      expect(provider.conflictState.conflictCount, equals(1));
      expect(provider.conflictState.files.first.relativePath, equals('lib/a.dart'));
    });

    test('无中断状态时冲突状态为空且可继续为假', () async {
      final repoDir = Directory(p.join(tempDir.path, 'clean_repo'))
        ..createSync(recursive: true);
      Directory(p.join(repoDir.path, '.git')).createSync(recursive: true);

      GitService.instance.processRunner = (
        String exec,
        List<String> args, {
        String? workingDirectory,
      }) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.isNotEmpty && args[0] == 'config') {
          return ProcessResult(1, 1, '', '');
        }
        if (args.contains('remote') && args.contains('-v')) {
          return ProcessResult(0, 0, '', '');
        }
        if (args.contains('status')) {
          return ProcessResult(0, 0, '# branch.head master\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };
      GitService.instance.streamRunner = ({
        required String executable,
        required List<String> arguments,
        required String workspacePath,
        required String? containerWorkDir,
        void Function(String chunk)? onOutput,
        HeadlessCancelToken? cancelToken,
        Duration timeout = const Duration(minutes: 5),
      }) async {
        return ProcessResult(0, 0, '', '');
      };

      final provider = GitProvider();
      provider.bindRootPath(repoDir.path);
      await provider.refresh();

      expect(provider.hasPendingOperation, isFalse);
      expect(provider.hasConflicts, isFalse);
      expect(provider.conflictState.canContinue, isFalse);
    });
  });

  group('GitPanelWidget 集成云端入口', () {
    testWidgets('320dp 手机宽度打开抽屉时 Git 面板不溢出', (tester) async {
      // 端到端验证：真实 Drawer 布局下的可用宽度比单独渲染同步条更窄
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 3,
          behind: 2,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GitProvider>.value(value: gitProvider),
            ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
            ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
            ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const Scaffold(
              drawer: CodeEditorDrawer(),
              body: Center(child: Text('Main Editor')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // 切到 Git 页签
      await tester.tap(find.byIcon(Icons.alt_route_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GitSyncBar), findsOneWidget);
      // 云按钮收拢了全部同步动作，收紧后主行只留远程名 + 一个按钮
      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
      expect(find.text('抓取'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Git 面板头部包含同步工具条', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(
          branch: 'main',
          upstream: 'origin/main',
          ahead: 1,
          behind: 1,
        ),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.byType(GitSyncBar), findsOneWidget);
      expect(find.byKey(const ValueKey('git_sync_cloud_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('更多操作菜单包含远程仓库管理', (tester) async {
      seedRepo(
        tracking: const GitBranchTracking(branch: 'main', upstream: 'origin/main'),
      );

      await tester.pumpWidget(buildApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多操作'));
      await tester.pumpAndSettle();

      expect(find.text('远程仓库管理'), findsWidgets);
    });
  });
}
