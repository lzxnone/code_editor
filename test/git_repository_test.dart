import 'dart:io';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/git_model.dart';
import 'package:code_editor/models/project_history.dart';
import 'package:code_editor/providers/git_provider.dart';
import 'package:code_editor/providers/project_provider.dart';
import 'package:code_editor/providers/run_provider.dart';
import 'package:code_editor/providers/search_provider.dart';
import 'package:code_editor/providers/settings_provider.dart';
import 'package:code_editor/providers/tab_provider.dart';
import 'package:code_editor/services/git_service.dart';
import 'package:code_editor/services/internal_project_service.dart';
import 'package:code_editor/utils/git_diff_helper.dart';
import 'package:code_editor/widgets/code_editor_drawer.dart';
import 'package:code_editor/widgets/git/git_diff_page.dart';
import 'package:code_editor/widgets/git/git_panel_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempBaseDir;
  late Directory testProjectDir;
  late ProjectProvider projectProvider;
  late TabProvider tabProvider;
  late SettingsProvider settingsProvider;
  late RunProvider runProvider;
  late SearchProvider searchProvider;
  late GitProvider gitProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GitService.instance.resetForTesting();
    tempBaseDir = Directory.systemTemp.createTempSync('git_repository_test_');
    testProjectDir = Directory(p.join(tempBaseDir.path, 'git_test_project'))..createSync(recursive: true);

    InternalProjectService.instance.customProjectsDir =
        Directory(p.join(tempBaseDir.path, 'files', 'projects'));

    projectProvider = ProjectProvider();
    tabProvider = TabProvider()..bindProjectProvider(projectProvider);
    settingsProvider = SettingsProvider();
    runProvider = RunProvider();
    searchProvider = SearchProvider()..bindRootPath(testProjectDir.path);
    gitProvider = GitProvider();

    await projectProvider.switchProject(
      ProjectHistory(
        rootPath: testProjectDir.path,
        lastOpenedFilePath: null,
      ),
    );
  });

  tearDown(() {
    GitService.instance.resetForTesting();
    InternalProjectService.instance.customProjectsDir = null;
    if (tempBaseDir.existsSync()) {
      try {
        tempBaseDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Widget buildTestApp({Widget? home}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProjectProvider>.value(value: projectProvider),
        ChangeNotifierProvider<TabProvider>.value(value: tabProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<RunProvider>.value(value: runProvider),
        ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
        ChangeNotifierProvider<GitProvider>.value(value: gitProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: home ??
            const Scaffold(
              drawer: CodeEditorDrawer(),
              body: Center(child: Text('Main Editor')),
            ),
      ),
    );
  }

  group('GitService Unit Tests', () {
    test('checkGitInstalled reports true when git --version succeeds', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        return ProcessResult(1, 1, '', 'unknown');
      };

      final status = await GitService.instance.checkGitInstalled(forceRefresh: true);
      expect(status.isInstalled, isTrue);
      expect(status.version, contains('git version 2.45.0'));
    });

    test('checkGitInstalled reports false when git executable is not found', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        throw const ProcessException('git', ['--version'], 'No such file or directory', 2);
      };

      final status = await GitService.instance.checkGitInstalled(forceRefresh: true);
      expect(status.isInstalled, isFalse);
      expect(status.errorMessage, contains('No such file or directory'));
    });

    test('installGit runs process and refreshes environment status', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('install-git')) {
          return ProcessResult(0, 0, 'Git installed\n', '');
        }
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final result = await GitService.instance.installGit();
      expect(result.success, isTrue);

      final status = await GitService.instance.checkGitInstalled();
      expect(status.isInstalled, isTrue);
    });

    test('isGitRepository correctly checks existence of .git directory or file', () {
      final repoDir = Directory(p.join(testProjectDir.path, 'repo1'))..createSync();
      expect(GitService.instance.isGitRepository(repoDir.path), isFalse);

      // Create .git directory
      Directory(p.join(repoDir.path, '.git')).createSync();
      expect(GitService.instance.isGitRepository(repoDir.path), isTrue);

      // Create submodule with .git file
      final submoduleDir = Directory(p.join(testProjectDir.path, 'submodule'))..createSync();
      File(p.join(submoduleDir.path, '.git')).writeAsStringSync('gitdir: ../.git/modules/sub');
      expect(GitService.instance.isGitRepository(submoduleDir.path), isTrue);
    });

    test('detectRepositories discovers both root repo and nested/submodule repos', () async {
      // 1. Root repo
      Directory(p.join(testProjectDir.path, '.git')).createSync();

      // 2. Nested repo inside packages/core
      final nestedDir = Directory(p.join(testProjectDir.path, 'packages', 'core'))..createSync(recursive: true);
      Directory(p.join(nestedDir.path, '.git')).createSync();

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('branch') || args.contains('symbolic-ref')) {
          return ProcessResult(0, 0, 'main\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final repos = await GitService.instance.detectRepositories(testProjectDir.path);
      expect(repos.length, equals(2));

      final root = repos.firstWhere((r) => r.isRoot);
      expect(root.rootPath, equals(p.normalize(testProjectDir.path)));
      expect(root.currentBranch, equals('main'));

      final nested = repos.firstWhere((r) => !r.isRoot);
      expect(nested.rootPath, equals(p.normalize(nestedDir.path)));
      expect(nested.name, equals(p.normalize('packages/core')));
    });

    test('getGitStatus parses porcelain status output accurately', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.contains('status')) {
          final stdout =
              '?? untracked.dart\n'
              ' M modified_worktree.dart\n'
              'M  staged_modified.dart\n'
              'MM both_modified.dart\n'
              'A  staged_new.dart\n'
              ' D deleted.dart\n'
              'R  old.dart -> new.dart\n';
          return ProcessResult(0, 0, stdout, '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final statuses = await GitService.instance.getGitStatus(testProjectDir.path);
      expect(statuses.length, equals(8));

      // Untracked
      final untracked = statuses.firstWhere((s) => s.relativePath == 'untracked.dart');
      expect(untracked.statusType, equals(GitFileStatusType.untracked));
      expect(untracked.isStaged, isFalse);

      // Worktree modified
      final modifiedWorktree = statuses.firstWhere((s) => s.relativePath == 'modified_worktree.dart');
      expect(modifiedWorktree.statusType, equals(GitFileStatusType.modified));
      expect(modifiedWorktree.isStaged, isFalse);

      // Staged modified
      final stagedMod = statuses.firstWhere((s) => s.relativePath == 'staged_modified.dart');
      expect(stagedMod.statusType, equals(GitFileStatusType.modified));
      expect(stagedMod.isStaged, isTrue);

      // Staged added
      final added = statuses.firstWhere((s) => s.relativePath == 'staged_new.dart');
      expect(added.statusType, equals(GitFileStatusType.added));
      expect(added.isStaged, isTrue);

      // Staged renamed
      final renamed = statuses.firstWhere((s) => s.relativePath == 'new.dart');
      expect(renamed.statusType, equals(GitFileStatusType.renamed));
      expect(renamed.isStaged, isTrue);
      expect(renamed.originalPath, equals('old.dart'));
    });

    test('getLog parses commit history and computes graph lanes accurately', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('log')) {
          final stdout =
              'commit1\x00c1\x00commit2\x00Author 1\x00a1@test.com\x001700000000\x002 days ago\x00feat: initial\x00HEAD -> main, origin/main\n'
              'commit2\x00c2\x00\x00Author 2\x00a2@test.com\x001699990000\x003 days ago\x00chore: init repo\x00\n';
          return ProcessResult(0, 0, stdout, '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final commits = await GitService.instance.getLog(testProjectDir.path);
      expect(commits.length, equals(2));
      expect(commits[0].hash, equals('commit1'));
      expect(commits[0].shortHash, equals('c1'));
      expect(commits[0].subject, equals('feat: initial'));
      expect(commits[0].isHead, isTrue);
      expect(commits[0].refs, contains('HEAD -> main'));
      expect(commits[0].lane, equals(0));
      expect(commits[1].hash, equals('commit2'));
      expect(commits[1].shortHash, equals('c2'));
    });

    test('GitService tag operations execute correct git arguments', () async {
      final executedArgs = <List<String>>[];
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        executedArgs.add(args);
        if (args.contains('tag') && args.contains('-l')) {
          return ProcessResult(0, 0, 'v1.0.0\nv1.1.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final tags = await GitService.instance.getTags(testProjectDir.path);
      expect(tags, equals(['v1.0.0', 'v1.1.0']));

      final createRes = await GitService.instance.createTag(testProjectDir.path, 'v1.2.0', message: 'Release 1.2');
      expect(createRes.success, isTrue);
      expect(executedArgs.last, equals(['tag', '-a', 'v1.2.0', '-m', 'Release 1.2']));

      final deleteRes = await GitService.instance.deleteTag(testProjectDir.path, 'v1.0.0');
      expect(deleteRes.success, isTrue);
      expect(executedArgs.last, equals(['tag', '-d', 'v1.0.0']));

      final checkoutRes = await GitService.instance.checkoutTag(testProjectDir.path, 'v1.1.0');
      expect(checkoutRes.success, isTrue);
      expect(executedArgs.last, equals(['checkout', 'v1.1.0']));
    });
  });

  group('GitProvider Unit Tests', () {
    test('bindRootPath clears and refreshes state', () async {
      gitProvider.setStateForTesting(
        rootPath: '/old/path',
        repositories: [
          const GitRepositoryInfo(rootPath: '/old/path', name: 'old', isRoot: true),
        ],
        currentRepoPath: '/old/path',
        currentBranch: 'dev',
      );

      expect(gitProvider.hasRepository, isTrue);
      expect(gitProvider.currentBranch, equals('dev'));

      gitProvider.bindRootPath(null);
      expect(gitProvider.hasRepository, isFalse);
      expect(gitProvider.currentRepoPath, isNull);
    });

    test('createTag, deleteTag, and switchTag update provider state', () async {
      final repoPath = p.normalize(testProjectDir.path);
      gitProvider.setStateForTesting(
        rootPath: repoPath,
        currentRepoPath: repoPath,
        currentBranch: 'main',
        tags: ['v1.0.0'],
      );

      var currentTagsOutput = 'v1.0.0\nv2.0.0\n';
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('tag') && args.contains('-l')) {
          return ProcessResult(0, 0, currentTagsOutput, '');
        }
        if (args.contains('checkout')) {
          return ProcessResult(0, 0, 'Note: checking out v2.0.0.\nHEAD is now at 1234567\n', '');
        }
        if (args.contains('symbolic-ref') || args.contains('branch')) {
          return ProcessResult(0, 0, 'detached (1234567)\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final createRes = await gitProvider.createTag('v2.0.0');
      expect(createRes.success, isTrue);
      expect(gitProvider.tags, equals(['v1.0.0', 'v2.0.0']));

      final switchRes = await gitProvider.switchTag('v2.0.0');
      expect(switchRes.success, isTrue);

      currentTagsOutput = 'v2.0.0\n';
      final deleteRes = await gitProvider.deleteTag('v1.0.0');
      expect(deleteRes.success, isTrue);
      expect(gitProvider.tags, equals(['v2.0.0']));
    });

    test('initRepository sets isInitializing, runs init, and refreshes', () async {
      gitProvider.setStateForTesting(rootPath: testProjectDir.path);

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.contains('init')) {
          Directory(p.join(testProjectDir.path, '.git')).createSync();
          return ProcessResult(0, 0, 'Initialized empty Git repository\n', '');
        }
        if (args.contains('branch') || args.contains('symbolic-ref')) {
          return ProcessResult(0, 0, 'main\n', '');
        }
        if (args.contains('status')) {
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      expect(gitProvider.hasRepository, isFalse);
      final res = await gitProvider.initRepository();
      expect(res.success, isTrue);
      expect(gitProvider.hasRepository, isTrue);
      expect(gitProvider.currentRepo?.isRoot, isTrue);
      expect(gitProvider.currentBranch, equals('main'));
    });

    test('switchRepository switches current repo and loads details', () async {
      final path1 = p.normalize('/repo1');
      final path2 = p.normalize('/repo2');
      final repo1 = GitRepositoryInfo(rootPath: path1, name: 'repo1', isRoot: true, currentBranch: 'main');
      final repo2 = GitRepositoryInfo(rootPath: path2, name: 'repo2', isRoot: false, currentBranch: 'feature');

      gitProvider.setStateForTesting(
        rootPath: path1,
        repositories: [repo1, repo2],
        currentRepoPath: path1,
        currentBranch: 'main',
      );

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (workingDirectory == path2 && args.contains('branch')) {
          return ProcessResult(0, 0, 'feature\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      expect(gitProvider.currentRepoPath, equals(path1));
      await gitProvider.switchRepository(path2);
      expect(gitProvider.currentRepoPath, equals(path2));
    });
  });

  group('GitPanelWidget UI Tests', () {
    testWidgets('Displays no project view when project is null or empty', (tester) async {
      projectProvider.setHistoryForTesting(const ProjectHistory(rootPath: null, lastOpenedFilePath: null));
      gitProvider.bindRootPath(null);

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.text('当前未打开项目'), findsOneWidget);
    });

    testWidgets('Displays Git install guidance view without not-found warning or code box, provides install button', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: false,
        repositories: [],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // 不再指明 "未检测到 Git" / "Git not found"
      expect(find.text('未检测到 Git'), findsNothing);
      // 副文本和终端代码框已移除
      expect(find.text('apt update && apt install -y git'), findsNothing);
      // 温和提示需要安装 Git
      expect(find.text('需要安装 Git'), findsOneWidget);
      // 在下面主动提供【安装 Git】按钮
      expect(find.text('安装 Git'), findsOneWidget);
    });

    testWidgets('Tapping install Git button pops blocking dialog and executes installation', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: false,
        repositories: [],
        isLoading: false,
      );

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('install-git')) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return ProcessResult(0, 0, 'Git installed successfully\n', '');
        }
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      final installButton = find.text('安装 Git');
      expect(installButton, findsOneWidget);

      // Tap install button
      await tester.tap(installButton);
      await tester.pump();

      // Verify synchronous blocking dialog is shown with text while installing
      expect(find.text('正在安装 Git...'), findsOneWidget);

      // Await completion of installation and dialog dismissal
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is dismissed
      expect(find.text('正在安装 Git...'), findsNothing);

      // Drain toast timer
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Displays uninitialized view with prominent button when repo is not initialized', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [],
        isLoading: false,
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.text('当前工程尚未初始化为 Git 仓库'), findsOneWidget);
      expect(find.text('初始化 Git 仓库'), findsOneWidget);
    });

    testWidgets('Tapping initialize button pops blocking dialog and executes git init', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [],
        isLoading: false,
      );

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('init')) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          Directory(p.join(testProjectDir.path, '.git')).createSync();
          return ProcessResult(0, 0, 'Initialized empty Git repository\n', '');
        }
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.contains('branch') || args.contains('symbolic-ref')) {
          return ProcessResult(0, 0, 'main\n', '');
        }
        if (args.contains('status')) {
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      final initButton = find.text('初始化 Git 仓库');
      expect(initButton, findsOneWidget);

      // Tap initialize button
      await tester.tap(initButton);
      await tester.pump();

      // Verify synchronous blocking dialog is shown with text while initializing
      expect(find.text('正在初始化 Git 仓库...'), findsOneWidget);

      // Await completion of initialization and dialog dismissal
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is dismissed
      expect(find.text('正在初始化 Git 仓库...'), findsNothing);

      // Now repo is initialized!
      expect(gitProvider.hasRepository, isTrue);
      expect(find.text('main'), findsOneWidget);
      expect(find.text('暂无任何文件更改'), findsOneWidget);

      // Drain toast timer so no pending timers remain
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Displays changes and opens file on tap when repository has changes', (tester) async {
      final changeItem = GitFileStatus(
        path: p.normalize(p.join(testProjectDir.path, 'lib', 'main.dart')),
        relativePath: 'lib/main.dart',
        statusType: GitFileStatusType.modified,
        isStaged: false,
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        changedFiles: [changeItem],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.text('更改'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('lib'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.byIcon(Icons.undo_rounded), findsWidgets);

      // Tapping file calls openFile on TabProvider
      await tester.tap(find.text('main.dart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Displays dropdown switcher when multiple repositories are detected', (tester) async {
      final repo1 = GitRepositoryInfo(
        rootPath: p.normalize(testProjectDir.path),
        name: 'root_project',
        isRoot: true,
        currentBranch: 'main',
      );
      final repo2 = GitRepositoryInfo(
        rootPath: p.normalize(p.join(testProjectDir.path, 'packages', 'core')),
        name: 'packages/core',
        isRoot: false,
        currentBranch: 'dev',
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [repo1, repo2],
        currentRepoPath: repo1.rootPath,
        currentBranch: 'main',
        changedFiles: [],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Dropdown button should show the active repository name
      expect(find.text('root_project'), findsOneWidget);
      expect(find.byTooltip('切换仓库'), findsOneWidget);

      // Open dropdown menu
      await tester.tap(find.byTooltip('切换仓库'));
      await tester.pumpAndSettle();

      // Should show both repositories in menu
      expect(find.text('packages/core'), findsOneWidget);
    });

    testWidgets('ActivityBar displays badge with changed files count', (tester) async {
      final item1 = GitFileStatus(
        path: p.normalize(p.join(testProjectDir.path, 'lib', 'a.dart')),
        relativePath: 'lib/a.dart',
        statusType: GitFileStatusType.modified,
        isStaged: false,
      );
      final item2 = GitFileStatus(
        path: p.normalize(p.join(testProjectDir.path, 'lib', 'b.dart')),
        relativePath: 'lib/b.dart',
        statusType: GitFileStatusType.added,
        isStaged: true,
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        changedFiles: [item1, item2],
      );

      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Badge on ActivityBar Git item displays "2"
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('Staged changes displays with unstage button and commit box', (tester) async {
      final stagedItem = GitFileStatus(
        path: p.normalize(p.join(testProjectDir.path, 'lib', 'staged.dart')),
        relativePath: 'lib/staged.dart',
        statusType: GitFileStatusType.added,
        isStaged: true,
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        changedFiles: [stagedItem],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.text('暂存的更改'), findsOneWidget);
      expect(find.text('staged.dart'), findsOneWidget);
      expect(find.byTooltip('取消暂存更改'), findsOneWidget);
      expect(find.byTooltip('全部取消暂存更改'), findsOneWidget);
      expect(find.text('提交'), findsOneWidget);
    });

    testWidgets('CodeEditorDrawer switches to Git tab (index 2) seamlessly', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [],
        isLoading: false,
      );

      await tester.pumpWidget(buildTestApp());
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Switch to Git tab (icon Icons.alt_route_rounded)
      await tester.tap(find.byIcon(Icons.alt_route_rounded));
      await tester.pumpAndSettle();

      expect(CodeEditorDrawer.lastSelectedTabIndex, equals(2));
      expect(find.byType(GitPanelWidget), findsOneWidget);
      expect(find.text('当前工程尚未初始化为 Git 仓库'), findsOneWidget);
    });

    testWidgets('GitPanelWidget displays Graph section with commit history and details dialog', (tester) async {
      final commit1 = GitCommit(
        hash: 'abcdef1234567890abcdef1234567890abcdef12',
        shortHash: 'abcdef1',
        parentHashes: const ['1234567'],
        authorName: 'TestDev',
        authorEmail: 'dev@test.com',
        authorDate: DateTime.now(),
        relativeDate: '10 minutes ago',
        subject: 'feat: add git graph support',
        refs: const ['HEAD -> main'],
        lane: 0,
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        changedFiles: [],
        commits: [commit1],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Check Graph section header
      expect(find.text('图表'), findsOneWidget);
      expect(find.text('feat: add git graph support'), findsOneWidget);
      expect(find.text('abcdef1'), findsOneWidget);
      expect(find.text('main'), findsWidgets);

      // Tap on commit to open details modal
      await tester.tap(find.text('feat: add git graph support'));
      await tester.pumpAndSettle();

      expect(find.text('提交详情'), findsOneWidget);
      expect(find.text('TestDev <dev@test.com>'), findsOneWidget);
      expect(find.byTooltip('复制哈希'), findsOneWidget);
    });

    testWidgets('GitPanelWidget displays branch selector in separate row and more actions menu', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        branches: ['main', 'feature/login'],
        tags: ['v1.0.0'],
        changedFiles: [],
        stashCount: 1,
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Branch button exists with branch name and stash count indicator
      expect(find.text('main'), findsOneWidget);
      expect(find.text('stash: 1'), findsOneWidget);

      // Tap branch button to open anchored popup menu
      await tester.tap(find.text('main'));
      await tester.pumpAndSettle();

      // Dropdown menu has Radio toggle for 分支 and 标签
      expect(find.text('分支'), findsWidgets);
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('feature/login'), findsOneWidget);

      // Tap 标签 radio to switch list to tags
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();

      // Should now show tags list
      expect(find.text('v1.0.0'), findsOneWidget);

      // Tap outside to dismiss the menu
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // More actions menu icon exists next to branch bar
      expect(find.byKey(const ValueKey('branch_row_more_button')), findsOneWidget);

      // Open more actions menu (since last selected was Tag, it offers Tag actions)
      await tester.tap(find.byKey(const ValueKey('branch_row_more_button')));
      await tester.pumpAndSettle();

      expect(find.text('创建新标签'), findsOneWidget);
      expect(find.text('删除标签'), findsOneWidget);
    });

    testWidgets('Long pressing a changed file item opens context menu with actions', (tester) async {
      final untrackedItem = GitFileStatus(
        path: p.normalize(p.join(testProjectDir.path, 'untracked.txt')),
        relativePath: 'untracked.txt',
        statusType: GitFileStatusType.untracked,
        isStaged: false,
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        changedFiles: [untrackedItem],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.text('untracked.txt'), findsOneWidget);

      // Long press file item to trigger BottomSheet context menu
      await tester.longPress(find.text('untracked.txt'));
      await tester.pumpAndSettle();

      expect(find.text('暂存更改'), findsOneWidget);
      expect(find.text('放弃更改'), findsOneWidget);
      expect(find.text('添加到 .gitignore'), findsOneWidget);
      expect(find.text('打开文件'), findsOneWidget);
    });

    testWidgets('Tapping 创建新标签 opens dialog and creates tag', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        branches: ['main'],
        tags: [],
        changedFiles: [],
      );

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('tag') && args.contains('v1.0.0')) {
          return ProcessResult(0, 0, '', '');
        }
        if (args.contains('tag') && args.contains('-l')) {
          return ProcessResult(0, 0, 'v1.0.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Open selector and switch to Tag
      await tester.tap(find.text('main'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Tap more button
      await tester.tap(find.byKey(const ValueKey('branch_row_more_button')));
      await tester.pumpAndSettle();

      // Tap 创建新标签
      await tester.tap(find.text('创建新标签'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);
      final dialogTextFields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      expect(dialogTextFields, findsNWidgets(2));

      // Enter tag name
      await tester.enterText(dialogTextFields.first, 'v1.0.0');
      await tester.pumpAndSettle();

      // Tap confirm
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // Provider tags updated
      expect(gitProvider.tags, contains('v1.0.0'));

      // Drain toast timer
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('GitPanelWidget restores collapsed state and draft commit message from in-memory cache', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        branches: ['main'],
        changedFiles: [],
      );

      // Mount GitPanelWidget
      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Enter draft commit message
      final commitInput = find.byType(TextField).first;
      await tester.enterText(commitInput, 'WIP: in-memory draft message');
      await tester.pumpAndSettle();

      // Collapse "更改" section
      expect(find.text('暂无任何文件更改'), findsOneWidget);
      await tester.tap(find.text('更改'));
      await tester.pumpAndSettle();
      expect(find.text('暂无任何文件更改'), findsNothing);

      // Unmount GitPanelWidget (simulating switching away or closing drawer)
      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();

      // Re-mount GitPanelWidget
      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Verify draft commit message is restored from memory
      expect(find.text('WIP: in-memory draft message'), findsOneWidget);

      // Verify collapsed state is restored from memory
      expect(find.text('暂无任何文件更改'), findsNothing);
    });

    testWidgets('GitPanelWidget efficiently handles thousands of tags with virtualization and search', (tester) async {
      final manyTags = List.generate(2000, (i) => 'v$i.0.0');
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        branches: ['main'],
        tags: manyTags,
        changedFiles: [],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Open selector and switch to Tag
      await tester.tap(find.text('main'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();

      // Search input appears because tags count > 5
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '搜索标签...',
      );
      expect(searchField, findsOneWidget);

      // Filter with search query
      await tester.enterText(searchField, 'v199');
      await tester.pumpAndSettle();

      expect(find.text('v199.0.0'), findsOneWidget);

      // Tap tag outside
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Branch search box is always visible and row icon switches only when selecting a specific tag', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        branches: ['main', 'feature/login'],
        tags: ['v1.0.0'],
        changedFiles: [],
      );

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('checkout') && args.contains('v1.0.0')) {
          return ProcessResult(0, 0, '', '');
        }
        if (args.contains('describe') && args.contains('--exact-match')) {
          return ProcessResult(0, 0, 'v1.0.0\n', '');
        }
        if (args.contains('tag') && args.contains('-l')) {
          return ProcessResult(0, 0, 'v1.0.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Initially on branch 'main': row icon is call_split_rounded
      expect(find.byIcon(Icons.call_split_rounded), findsWidgets);
      expect(find.byIcon(Icons.local_offer_outlined), findsNothing);

      // Open selector dropdown
      await tester.tap(find.text('main'));
      await tester.pumpAndSettle();

      // Branch search box is visible even with only 2 branches
      final branchSearchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '搜索分支...',
      );
      expect(branchSearchField, findsOneWidget);

      // Filter branches
      await tester.enterText(branchSearchField, 'login');
      await tester.pumpAndSettle();
      expect(find.text('feature/login'), findsOneWidget);

      // Switch to Tag mode inside dialog
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();

      // Crucial: The row button behind still shows call_split_rounded, NOT converted to local_offer_outlined yet!
      expect(gitProvider.isCurrentRefTag, isFalse);

      // Tap on specific tag 'v1.0.0' to checkout tag
      await tester.tap(find.text('v1.0.0'));
      await tester.pumpAndSettle();

      // Now row button has converted to tag icon and displays 'v1.0.0'
      expect(gitProvider.isCurrentRefTag, isTrue);
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.byIcon(Icons.local_offer_outlined), findsWidgets);

      // Drain toast timer
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Delete tag and branch dialogs contain search input and filter items in real-time', (tester) async {
      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        branches: ['main', 'feat/auth', 'feat/profile'],
        tags: ['v1.0.0', 'v2.0.0', 'release-2026'],
        changedFiles: [],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Open more actions menu
      await tester.tap(find.byKey(const ValueKey('branch_row_more_button')));
      await tester.pumpAndSettle();

      // Tap '删除分支'
      await tester.tap(find.text('删除分支'));
      await tester.pumpAndSettle();

      // Verify search input exists in delete branch dialog
      final branchSearch = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '搜索分支...',
      );
      expect(branchSearch, findsOneWidget);

      // Filter branches
      await tester.enterText(branchSearch, 'auth');
      await tester.pumpAndSettle();
      expect(find.text('feat/auth'), findsOneWidget);
      expect(find.text('feat/profile'), findsNothing);

      // Cancel dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Open more actions menu again
      await tester.tap(find.byKey(const ValueKey('branch_row_more_button')));
      await tester.pumpAndSettle();

      // Tap '删除标签'
      await tester.tap(find.text('删除标签'));
      await tester.pumpAndSettle();

      // Verify search input exists in delete tag dialog
      final tagSearch = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '搜索标签...',
      );
      expect(tagSearch, findsOneWidget);

      // Filter tags
      await tester.enterText(tagSearch, 'release');
      await tester.pumpAndSettle();
      expect(find.text('release-2026'), findsOneWidget);
      expect(find.text('v1.0.0'), findsNothing);

      // Cancel dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    test('GitDiffHelper computeSplitDiff and toUnifiedDiff', () {
      const orig = 'line1\nline2\nline3\nline4';
      const mod = 'line1\nline2_modified\nline3\nline4\nline5';

      final split = GitDiffHelper.computeSplitDiff(orig, mod);
      expect(split.leftLines.length, equals(split.rightLines.length));
      expect(split.additionsCount, equals(2));
      expect(split.deletionsCount, equals(1));
      expect(split.changeRowIndices.isNotEmpty, isTrue);

      final unified = GitDiffHelper.toUnifiedDiff(orig, mod);
      expect(unified.any((l) => l.type == DiffLineType.added), isTrue);
      expect(unified.any((l) => l.type == DiffLineType.deleted), isTrue);
      expect(unified.any((l) => l.type == DiffLineType.unchanged), isTrue);
    });

    testWidgets('Clicking file in Git panel opens GitDiffPage', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('status')) {
          return ProcessResult(0, 0, ' M test_file.dart\n', '');
        }
        if (args.contains('rev-parse')) {
          return ProcessResult(0, 0, '${testProjectDir.path}\n', '');
        }
        if (args.contains('show')) {
          return ProcessResult(0, 0, 'void main() {\n  print("old");\n}\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final file = File(p.join(testProjectDir.path, 'test_file.dart'));
      file.writeAsStringSync('void main() {\n  print("new");\n}\n');

      final changedItem = GitFileStatus(
        path: file.path,
        relativePath: 'test_file.dart',
        statusType: GitFileStatusType.modified,
        isStaged: false,
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentRepoPath: testProjectDir.path,
        currentBranch: 'main',
        changedFiles: [changedItem],
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      expect(find.text('test_file.dart'), findsOneWidget);

      await tester.tap(find.text('test_file.dart'));
      await tester.pumpAndSettle();

      expect(find.byType(GitDiffPage), findsOneWidget);
      expect(find.text('原始版本'), findsOneWidget);
      expect(find.text('修改版本'), findsOneWidget);

      final toggleButton = find.byTooltip('单屏内联');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      final splitToggleButton = find.byTooltip('双屏分栏');
      expect(splitToggleButton, findsOneWidget);
      await tester.tap(splitToggleButton);
      await tester.pumpAndSettle();

      expect(find.text('原始版本'), findsOneWidget);
      expect(find.text('修改版本'), findsOneWidget);

      // 验证双指捏合缩放手势与实时字号气泡
      final center = tester.getCenter(find.text('原始版本'));
      final touch1 = await tester.startGesture(center + const Offset(0, 100), pointer: 1);
      final touch2 = await tester.startGesture(center + const Offset(100, 100), pointer: 2);
      await tester.pump();

      await touch2.moveTo(center + const Offset(200, 100));
      await tester.pump();

      expect(find.textContaining('pt'), findsOneWidget);

      await touch1.up();
      await touch2.up();
      await tester.pumpAndSettle();

      expect(find.textContaining('pt'), findsNothing);

      // 验证极限拖拽分割线至最左侧/最右侧（代码区被压缩至看不见），彻底杜绝 RenderFlex 水平溢出
      final centerScreen = tester.getCenter(find.byType(GitDiffPage));
      await tester.dragFrom(centerScreen, const Offset(-380, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.dragFrom(centerScreen, const Offset(380, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GitPanelWidget displays commit pagination footer and expand all button', (tester) async {
      final commit1 = GitCommit(
        hash: 'abcdef1234567890',
        shortHash: 'abcdef1',
        subject: 'feat: commit 1',
        authorName: 'TestDev',
        authorEmail: 'dev@test.com',
        authorDate: DateTime.now(),
        relativeDate: '2 hours ago',
        parentHashes: [],
        refs: ['HEAD -> main'],
        lane: 0,
        activeLanes: [],
        outgoingLanes: [],
      );

      gitProvider.setStateForTesting(
        rootPath: testProjectDir.path,
        gitInstalled: true,
        repositories: [
          GitRepositoryInfo(
            rootPath: testProjectDir.path,
            name: 'git_test_project',
            isRoot: true,
            currentBranch: 'main',
          ),
        ],
        currentBranch: 'main',
        commits: [commit1],
        totalCommitsCount: 15,
      );

      await tester.pumpWidget(buildTestApp(home: const Scaffold(body: GitPanelWidget())));
      await tester.pumpAndSettle();

      // Verify CustomScrollView is present (virtualized rendering)
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify Expand All button in Graph section header
      expect(find.byTooltip('全部展开'), findsOneWidget);

      // Verify lazy loading footer shows loaded vs total
      expect(find.text('已显示 1 / 15 个提交'), findsOneWidget);
      expect(find.text('加载更多提交 (14)'), findsOneWidget);

      // When all commits are loaded
      gitProvider.setStateForTesting(
        totalCommitsCount: 1,
      );
      await tester.pumpAndSettle();

      expect(find.text('已显示全部 1 个提交'), findsOneWidget);
    });
  });
}

