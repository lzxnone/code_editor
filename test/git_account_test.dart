import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/git_account.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/git_account_service.dart';
import 'package:code_editor/services/internal_engine_service.dart';
import 'package:code_editor/views/git_account_management_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GitAccount Model Tests', () {
    test('Serializes to and from JSON correctly', () {
      final now = DateTime.now();
      final account = GitAccount(
        id: 'acc_1',
        platform: GitPlatform.github,
        username: 'alice',
        displayName: 'Alice Developer',
        email: 'alice@example.com',
        authType: GitAuthType.token,
        token: 'ghp_secret12345',
        serverUrl: 'https://github.com',
        avatarUrl: 'https://avatars.githubusercontent.com/u/12345',
        isDefault: true,
        createdAt: now,
      );

      final json = account.toJson();
      expect(json['id'], 'acc_1');
      expect(json['platform'], 'github');
      expect(json['username'], 'alice');
      expect(json['token'], 'ghp_secret12345');
      expect(json['isDefault'], true);

      final parsed = GitAccount.fromJson(json);
      expect(parsed.id, account.id);
      expect(parsed.platform, GitPlatform.github);
      expect(parsed.username, 'alice');
      expect(parsed.displayName, 'Alice Developer');
      expect(parsed.email, 'alice@example.com');
      expect(parsed.token, 'ghp_secret12345');
      expect(parsed.isDefault, true);
    });

    test('GitPlatform parsing handles fallback', () {
      expect(GitPlatform.fromString('github'), GitPlatform.github);
      expect(GitPlatform.fromString('gitee'), GitPlatform.gitee);
      expect(GitPlatform.fromString('gitlab'), GitPlatform.gitlab);
      expect(GitPlatform.fromString('unknown'), GitPlatform.github);
    });
  });

  group('GitAccountService Tests', () {
    late Directory tempDir;
    late GitAccountService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('git_account_test_');
      service = GitAccountService.instance;
      service.customBaseDir = tempDir;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Initial load returns empty list', () async {
      final accounts = await service.loadAccounts(forceReload: true);
      expect(accounts, isEmpty);
    });

    test('Saves, sets default, and deletes accounts correctly', () async {
      final acc1 = GitAccount(
        id: 'acc_1',
        platform: GitPlatform.github,
        username: 'alice',
        serverUrl: 'https://github.com',
        token: 'token1',
        createdAt: DateTime.now(),
      );

      final acc2 = GitAccount(
        id: 'acc_2',
        platform: GitPlatform.github,
        username: 'bob',
        serverUrl: 'https://github.com',
        token: 'token2',
        createdAt: DateTime.now(),
      );

      final acc3 = GitAccount(
        id: 'acc_3',
        platform: GitPlatform.gitee,
        username: 'charlie',
        serverUrl: 'https://gitee.com',
        token: 'token3',
        createdAt: DateTime.now(),
      );

      await service.saveAccount(acc1);
      await service.saveAccount(acc2);
      await service.saveAccount(acc3);

      expect(service.accounts.length, 3);
      // acc1 was the first GitHub account, so it became default
      final loaded1 = service.accounts.firstWhere((a) => a.id == 'acc_1');
      expect(loaded1.isDefault, true);

      // Change default GitHub account to acc2
      await service.setDefaultAccount('acc_2');
      final updated1 = service.accounts.firstWhere((a) => a.id == 'acc_1');
      final updated2 = service.accounts.firstWhere((a) => a.id == 'acc_2');
      expect(updated1.isDefault, false);
      expect(updated2.isDefault, true);

      // Gitee account default is independent
      final updated3 = service.accounts.firstWhere((a) => a.id == 'acc_3');
      expect(updated3.isDefault, true);

      // Match account by URL
      final matchedGitHub = service.findAccountForUrl('https://github.com/org/repo.git');
      expect(matchedGitHub?.id, 'acc_2');

      final matchedGitee = service.findAccountForUrl('https://gitee.com/user/project.git');
      expect(matchedGitee?.id, 'acc_3');

      // Delete account
      await service.deleteAccount('acc_1');
      expect(service.accounts.length, 2);
      expect(service.accounts.any((a) => a.id == 'acc_1'), false);
    });

    test('SSH key persistence survives container reset', () async {
      // 1. Simulate container with rootfs
      final rootfsDir = Directory('${tempDir.path}/rootfs');
      final containerSshDir = Directory('${rootfsDir.path}/root/.ssh');
      containerSshDir.createSync(recursive: true);
      final pubFile = File('${containerSshDir.path}/id_ed25519.pub');
      final privFile = File('${containerSshDir.path}/id_ed25519');
      pubFile.writeAsStringSync('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGo4 test@key');
      privFile.writeAsStringSync('dummy_private_key_content');

      File('${rootfsDir.path}/.installed').createSync();
      InternalEngineService.instance.customEngineDir = rootfsDir;

      // 2. Reading public key should back it up to host persistent directory
      final key = await service.getSshPublicKey();
      expect(key, 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGo4 test@key');

      final hostSshDir = await service.getPersistentSshDir();
      final hostPubFile = File('${hostSshDir.path}/id_ed25519.pub');
      expect(hostPubFile.existsSync(), isTrue);
      expect(hostPubFile.readAsStringSync().trim(), 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGo4 test@key');

      // 3. Simulate container rebuild / wipe (/root/.ssh is completely deleted)
      containerSshDir.deleteSync(recursive: true);
      expect(pubFile.existsSync(), isFalse);

      // 4. Calling getSshPublicKey again should restore key from persistent storage
      final restoredKey = await service.getSshPublicKey();
      expect(restoredKey, 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGo4 test@key');
      expect(pubFile.existsSync(), isTrue);
    });
  });

  group('GitAccountManagementView Localization and UI Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('git_acc_ui_test_');
      GitAccountService.instance.customBaseDir = tempDir;
      InternalEngineService.instance.customEngineDir = tempDir;
      DistroManager().customBaseDir = tempDir;
      await GitAccountService.instance.loadAccounts(forceReload: true);
    });

    tearDown(() {
      GitAccountService.instance.customBaseDir = null;
      InternalEngineService.instance.customEngineDir = null;
      DistroManager().customBaseDir = null;
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('Renders in English correctly with no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GitAccountManagementView(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Git Accounts'), findsOneWidget);
      expect(find.text('Hosted Accounts'), findsOneWidget);
      expect(find.text('SSH Keys'), findsOneWidget);
      expect(find.text('No Git Accounts Connected'), findsOneWidget);
    });

    testWidgets('Renders in Chinese correctly with no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GitAccountManagementView(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Git 账号管理'), findsOneWidget);
      expect(find.text('托管账号'), findsOneWidget);
      expect(find.text('SSH 密钥'), findsOneWidget);
      expect(find.text('暂未绑定 Git 账号'), findsOneWidget);
    });

    testWidgets('Renders Account Card in English correctly with no overflow on narrow screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testAccount = GitAccount(
        id: 'acc_narrow',
        platform: GitPlatform.github,
        username: 'superlongusernameexample',
        displayName: 'Super Long User Name Example',
        email: 'superlongdeveloperemail@example.com',
        authType: GitAuthType.token,
        token: 'token123',
        serverUrl: 'https://github.com',
        isDefault: true,
        createdAt: DateTime.now(),
      );
      await tester.runAsync(() async {
        await GitAccountService.instance.saveAccount(testAccount);
      });

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GitAccountManagementView(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Super Long User Name Example'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Personal Access Token'), findsOneWidget);
    });
  });
}
