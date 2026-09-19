import 'dart:io';

import 'package:code_editor/l10n/app_localizations.dart';
import 'package:code_editor/models/git_model.dart';
import 'package:code_editor/services/distro_manager.dart';
import 'package:code_editor/services/git_service.dart';
import 'package:code_editor/utils/git_error_mapper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录每一次流式执行的调用参数，便于断言生成的 git 参数是否正确
class _StreamCall {
  final String executable;
  final String? containerWorkDir;
  _StreamCall(this.executable, this.containerWorkDir);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  /// 已捕获的流式调用
  late List<_StreamCall> calls;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('git_remote_test_');
    calls = [];
    GitService.instance.resetForTesting();
    // 让环境探测直接通过，避免依赖真实 git 安装
    GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
      if (args.contains('--version')) {
        return ProcessResult(0, 0, 'git version 2.45.0\n', '');
      }
      return ProcessResult(0, 0, '', '');
    };
  });

  tearDown(() {
    GitService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  /// 安装一个假的流式执行器，返回指定结果
  void fakeStream({
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
    List<String>? stdoutChunks,
  }) {
    GitService.instance.streamRunner = ({
      required String executable,
      required List<String> arguments,
      required String workspacePath,
      required String? containerWorkDir,
      void Function(String chunk)? onOutput,
      HeadlessCancelToken? cancelToken,
      Duration timeout = const Duration(minutes: 5),
    }) async {
      calls.add(_StreamCall(executable, containerWorkDir));
      if (stdoutChunks != null && onOutput != null) {
        for (final chunk in stdoutChunks) {
          onOutput(chunk);
        }
      }
      return ProcessResult(1, exitCode, stdout, stderr);
    };
  }

  group('路径映射', () {
    test('mapToContainerPath 在非 Android 或未注入映射时原样返回', () {
      final service = GitService.instance;
      // 单元测试跑在宿主机上，没有 /workspace 这层挂载
      expect(service.mapToContainerPath('/tmp/proj', '/tmp/proj'), equals('/tmp/proj'));
    });

    test('mapToContainerPath 可通过注入覆写并支持嵌套仓库', () {
      final service = GitService.instance;
      service.containerPathMapper = (hostPath) {
        if (hostPath == '/root/proj') return '/workspace';
        if (hostPath == '/root/proj/packages/core') return '/workspace/packages/core';
        return '/workspace';
      };

      expect(service.mapToContainerPath('/root/proj', '/root/proj'), equals('/workspace'));
      expect(
        service.mapToContainerPath('/root/proj/packages/core', '/root/proj'),
        equals('/workspace/packages/core'),
      );
    });
  });

  group('guest 命令组装', () {
    test('注入 GIT_TERMINAL_PROMPT 与禁交互配置，防止无 TTY 时挂起', () {
      final cmd = GitService.instance.buildGuestGitCommand(['fetch', '--progress', 'origin']);

      expect(cmd, contains('GIT_TERMINAL_PROMPT=0'));
      expect(cmd, contains('credential.interactive=false'));
      expect(cmd, contains('core.askPass='));
      expect(cmd, contains('safe.directory=*'));
      expect(cmd, contains('fetch --progress origin'));
    });

    test('注入 SSH BatchMode 与 accept-new 主机指纹策略', () {
      final cmd = GitService.instance.buildGuestGitCommand(['push', 'origin', 'main']);

      expect(cmd, contains('GIT_SSH_COMMAND='));
      expect(cmd, contains('BatchMode=yes'));
      expect(cmd, contains('StrictHostKeyChecking=accept-new'));
      expect(cmd, contains('IdentitiesOnly=yes'));
      expect(cmd, contains('/root/.ssh/id_ed25519'));
    });

    test('包含特殊字符的参数被安全转义（不破坏命令结构）', () {
      final cmd = GitService.instance.buildGuestGitCommand(
        ['remote', 'add', 'my remote', 'https://example.com/a b.git'],
      );
      // 含空格 → 单引号包裹
      expect(cmd, contains("'my remote'"));
      expect(cmd, contains("'https://example.com/a b.git'"));
    });
  });

  group('进度解析', () {
    test('parseProgressPercent 解析常见 git 进度行', () {
      final service = GitService.instance;
      expect(service.parseProgressPercent('Receiving objects:  45% (450/1000), 1.2 MiB'), equals(45));
      expect(service.parseProgressPercent('Writing objects: 100% (12/12), done.'), equals(100));
      expect(service.parseProgressPercent('Resolving deltas:   7% (7/100)'), equals(7));
      // 非进度行 → null（由 UI 展示不确定态）
      expect(service.parseProgressPercent('From github.com:owner/repo'), isNull);
      expect(service.parseProgressPercent('Counting objects: 3, done.'), isNull);
    });

    test('parseProgressPercent 对越界百分比做钳制', () {
      expect(GitService.instance.parseProgressPercent('Weird: 999%'), equals(100));
    });

    test('isProgressLine 过滤 remote: 日志行与空行', () {
      final service = GitService.instance;
      expect(service.isProgressLine('Receiving objects: 45%'), isTrue);
      expect(service.isProgressLine('Writing objects: 100%'), isTrue);
      expect(service.isProgressLine('remote: Enumerating objects'), isFalse);
      expect(service.isProgressLine('   '), isFalse);
      expect(service.isProgressLine('From github.com:owner/repo'), isTrue);
    });
  });

  group('remote -v 解析', () {
    test('解析单个 origin 的 fetch/push 相同地址', () {
      const output = 'origin\thttps://github.com/owner/repo.git (fetch)\n'
          'origin\thttps://github.com/owner/repo.git (push)\n';

      final remotes = GitService.instance.parseRemotes(output);
      expect(remotes.length, equals(1));
      expect(remotes.first.name, equals('origin'));
      expect(remotes.first.fetchUrl, equals('https://github.com/owner/repo.git'));
      // 与 fetch 相同则不重复保存
      expect(remotes.first.pushUrl, isNull);
      expect(remotes.first.effectivePushUrl, equals('https://github.com/owner/repo.git'));
      expect(remotes.first.isHttps, isTrue);
      expect(remotes.first.isSsh, isFalse);
      expect(remotes.first.host, equals('github.com'));
      expect(remotes.first.repositoryPath, equals('owner/repo.git'));
    });

    test('解析 fetch 与 push 地址不同时的双地址', () {
      const output = 'origin\thttps://github.com/owner/repo.git (fetch)\n'
          'origin\tgit@github.com:owner/repo.git (push)\n';

      final remotes = GitService.instance.parseRemotes(output);
      expect(remotes.length, equals(1));
      expect(remotes.first.fetchUrl, equals('https://github.com/owner/repo.git'));
      expect(remotes.first.pushUrl, equals('git@github.com:owner/repo.git'));
      expect(remotes.first.effectivePushUrl, equals('git@github.com:owner/repo.git'));
    });

    test('解析多个 remote 并保持出现顺序', () {
      const output = 'upstream\thttps://github.com/up/repo.git (fetch)\n'
          'upstream\thttps://github.com/up/repo.git (push)\n'
          'origin\tgit@github.com:me/repo.git (fetch)\n'
          'origin\tgit@github.com:me/repo.git (push)\n';

      final remotes = GitService.instance.parseRemotes(output);
      expect(remotes.map((r) => r.name).toList(), equals(['upstream', 'origin']));
      expect(remotes[1].isSsh, isTrue);
      // scp 风格地址的 host 解析
      expect(remotes[1].host, equals('github.com'));
      expect(remotes[1].repositoryPath, equals('me/repo.git'));
    });

    test('空输出返回空列表，且忽略非法行', () {
      final service = GitService.instance;
      expect(service.parseRemotes(''), isEmpty);
      expect(service.parseRemotes('garbage line without parens\n'), isEmpty);
    });
  });

  group('分支追踪状态解析', () {
    test('porcelain v2 解析上游与 ahead/behind', () {
      const output = '# branch.oid abc123\n'
          '# branch.head main\n'
          '# branch.upstream origin/main\n'
          '# branch.ab +3 -2\n'
          '1 M. N... 100644 100644 100644 aaa bbb file.dart\n';

      final tracking = GitService.instance.parseBranchTracking(output);
      expect(tracking.branch, equals('main'));
      expect(tracking.upstream, equals('origin/main'));
      expect(tracking.ahead, equals(3));
      expect(tracking.behind, equals(2));
      expect(tracking.hasUpstream, isTrue);
      expect(tracking.isDiverged, isTrue);
      expect(tracking.needsPush, isTrue);
      expect(tracking.needsPull, isTrue);
      expect(tracking.isUpToDate, isFalse);
      expect(tracking.remoteName, equals('origin'));
      expect(tracking.upstreamBranch, equals('main'));
    });

    test('porcelain v2 无上游时 hasUpstream 为 false', () {
      const output = '# branch.oid abc123\n'
          '# branch.head feature/local\n';

      final tracking = GitService.instance.parseBranchTracking(output);
      expect(tracking.branch, equals('feature/local'));
      expect(tracking.hasUpstream, isFalse);
      expect(tracking.needsPush, isFalse);
      expect(tracking.remoteName, isNull);
    });

    test('porcelain v2 detached HEAD 不覆盖兜底分支名', () {
      const output = '# branch.oid abc123\n'
          '# branch.head (detached)\n'
          '# branch.ab +0 -0\n';

      final tracking = GitService.instance.parseBranchTracking(output, fallbackBranch: 'main');
      expect(tracking.branch, equals('main'));
      expect(tracking.ahead, equals(0));
      expect(tracking.behind, equals(0));
    });

    test('porcelain v1 简写解析 ahead/behind', () {
      const output = '## main...origin/main [ahead 1, behind 2]\n'
          ' M file.dart\n';

      final tracking = GitService.instance.parseBranchTracking(output);
      expect(tracking.branch, equals('main'));
      expect(tracking.upstream, equals('origin/main'));
      expect(tracking.ahead, equals(1));
      expect(tracking.behind, equals(2));
    });

    test('porcelain v1 上游被删除时标记 isGone', () {
      const output = '## feature/old...origin/feature/old [gone]\n';

      final tracking = GitService.instance.parseBranchTracking(output);
      expect(tracking.isGone, isTrue);
      expect(tracking.upstream, equals('origin/feature/old'));
      expect(tracking.ahead, equals(0));
      expect(tracking.behind, equals(0));
    });

    test('porcelain v1 无上游分支（无 ... 分隔）', () {
      const output = '## feature/new\n';

      final tracking = GitService.instance.parseBranchTracking(output);
      expect(tracking.branch, equals('feature/new'));
      expect(tracking.hasUpstream, isFalse);
    });

    test('仅领先时 isUpToDate 为 false、needsPull 为 false', () {
      const tracking = GitBranchTracking(branch: 'main', upstream: 'origin/main', ahead: 2);
      expect(tracking.needsPush, isTrue);
      expect(tracking.needsPull, isFalse);
      expect(tracking.isDiverged, isFalse);
      expect(tracking.isUpToDate, isFalse);
    });

    test('完全同步时 isUpToDate 为 true', () {
      const tracking = GitBranchTracking(branch: 'main', upstream: 'origin/main');
      expect(tracking.isUpToDate, isTrue);
      expect(tracking.needsPush, isFalse);
      expect(tracking.needsPull, isFalse);
    });
  });

  group('远端命令参数生成', () {
    test('fetch 默认带 --progress 与 --prune', () async {
      fakeStream();
      await GitService.instance.fetch(tempDir.path, remote: 'origin');

      expect(calls.length, equals(1));
      final cmd = calls.first.executable;
      expect(cmd, contains('fetch --progress --prune origin'));
    });

    test('fetch 可关闭 prune', () async {
      fakeStream();
      await GitService.instance.fetch(tempDir.path, remote: 'origin', prune: false);

      expect(calls.first.executable, contains('fetch --progress origin'));
      expect(calls.first.executable, isNot(contains('--prune')));
    });

    test('pull 使用 --rebase 且不自动 autostash', () async {
      fakeStream();
      await GitService.instance.pullRebase(tempDir.path, remote: 'origin', branch: 'main');

      final cmd = calls.first.executable;
      expect(cmd, contains('pull --progress --rebase origin main'));
      expect(cmd, isNot(contains('--autostash')));
    });

    test('push 普通推送不带任何强制参数', () async {
      fakeStream();
      await GitService.instance.push(tempDir.path, remote: 'origin', branch: 'main');

      final cmd = calls.first.executable;
      expect(cmd, contains('push --progress origin main'));
      expect(cmd, isNot(contains('--force')));
      expect(cmd, isNot(contains('--set-upstream')));
    });

    test('强推一律使用 --force-with-lease 而非 --force', () async {
      fakeStream();
      await GitService.instance.push(
        tempDir.path,
        remote: 'origin',
        branch: 'main',
        forceWithLease: true,
      );

      final cmd = calls.first.executable;
      expect(cmd, contains('--force-with-lease'));
      // 关键安全断言：绝不生成裸 --force
      expect(cmd, isNot(RegExp(r'--force(?![-\w])')));
    });

    test('首次发布分支使用 --set-upstream', () async {
      fakeStream();
      await GitService.instance.push(
        tempDir.path,
        remote: 'origin',
        branch: 'feature/new',
        setUpstream: true,
      );

      final cmd = calls.first.executable;
      expect(cmd, contains('--set-upstream'));
      expect(cmd, contains('origin feature/new'));
    });

    test('checkRemoteAuth 使用 ls-remote 校验连通性', () async {
      fakeStream();
      await GitService.instance.checkRemoteAuth(
        tempDir.path,
        'https://github.com/owner/repo.git',
      );

      expect(calls.first.executable, contains('ls-remote'));
      expect(calls.first.executable, contains('https://github.com/owner/repo.git'));
    });

    test('checkRemoteAuth 空地址直接失败且不执行命令', () async {
      fakeStream();
      final res = await GitService.instance.checkRemoteAuth(tempDir.path, '   ');
      expect(res.success, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('命令结果与取消', () {
    test('非零退出码映射为失败并保留 stderr', () async {
      fakeStream(exitCode: 128, stderr: 'fatal: could not read Username');
      final res = await GitService.instance.fetch(tempDir.path, remote: 'origin');

      expect(res.success, isFalse);
      expect(res.exitCode, equals(128));
      expect(res.stderr, contains('could not read Username'));
      expect(res.cancelled, isFalse);
    });

    test('成功时回传 stdout', () async {
      fakeStream(stdout: 'From github.com:owner/repo\n');
      final res = await GitService.instance.fetch(tempDir.path, remote: 'origin');

      expect(res.success, isTrue);
      expect(res.stdout, contains('From github.com:owner/repo'));
    });

    test('进度回调收到解析后的百分比', () async {
      fakeStream(stdoutChunks: [
        'Receiving objects:  45% (450/1000)\n',
        'remote: some server log\n',
        'Receiving objects: 100% (1000/1000), done.\n',
      ]);

      final seen = <GitOperationProgress>[];
      await GitService.instance.fetch(
        tempDir.path,
        remote: 'origin',
        onProgress: seen.add,
      );

      expect(seen.length, equals(2));
      expect(seen[0].percent, equals(45));
      expect(seen[0].phase, equals('fetch'));
      expect(seen[1].percent, equals(100));
    });

    test('Git 未安装时不执行命令并给出错误', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        throw const ProcessException('git', ['--version'], 'No such file', 2);
      };
      GitService.instance.invalidateEnvStatus();
      fakeStream();

      final res = await GitService.instance.fetch(tempDir.path, remote: 'origin');
      expect(res.success, isFalse);
      expect(calls, isEmpty);
    });
  });

  group('远端仓库管理命令', () {
    late List<List<String>> executed;

    setUp(() {
      executed = [];
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        executed.add(args);
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };
    });

    test('addRemote 生成正确参数', () async {
      await GitService.instance.addRemote(tempDir.path, 'origin', 'https://github.com/a/b.git');
      expect(executed.last, equals(['remote', 'add', 'origin', 'https://github.com/a/b.git']));
    });

    test('addRemote 支持独立推送地址', () async {
      await GitService.instance.addRemote(
        tempDir.path,
        'origin',
        'https://github.com/a/b.git',
        pushUrl: 'git@github.com:a/b.git',
      );
      expect(executed.last, equals(['remote', 'set-url', '--push', 'origin', 'git@github.com:a/b.git']));
    });

    test('addRemote 拒绝空名称或空地址', () async {
      final r1 = await GitService.instance.addRemote(tempDir.path, '  ', 'https://x/y.git');
      expect(r1.success, isFalse);
      final r2 = await GitService.instance.addRemote(tempDir.path, 'origin', '  ');
      expect(r2.success, isFalse);
      expect(executed.any((a) => a.contains('add')), isFalse);
    });

    test('removeRemote 与 pruneRemote 生成正确参数', () async {
      await GitService.instance.removeRemote(tempDir.path, 'origin');
      expect(executed.last, equals(['remote', 'remove', 'origin']));

      await GitService.instance.pruneRemote(tempDir.path, 'origin');
      expect(executed.last, equals(['remote', 'prune', 'origin']));
    });

    test('renameRemote 生成正确参数并拒绝同名', () async {
      await GitService.instance.renameRemote(tempDir.path, 'origin', 'upstream');
      expect(executed.last, equals(['remote', 'rename', 'origin', 'upstream']));

      final same = await GitService.instance.renameRemote(tempDir.path, 'origin', 'origin');
      expect(same.success, isFalse);
    });

    test('setRemoteUrl 区分普通地址与推送地址', () async {
      await GitService.instance.setRemoteUrl(tempDir.path, 'origin', 'https://new/url.git');
      expect(executed.last, equals(['remote', 'set-url', 'origin', 'https://new/url.git']));

      await GitService.instance.setRemoteUrl(
        tempDir.path,
        'origin',
        'git@new/url.git',
        push: true,
      );
      expect(executed.last, equals(['remote', 'set-url', '--push', 'origin', 'git@new/url.git']));
    });

    test('getRemotes 解析输出', () async {
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        return ProcessResult(
          0,
          0,
          'origin\thttps://github.com/a/b.git (fetch)\norigin\thttps://github.com/a/b.git (push)\n',
          '',
        );
      };

      final remotes = await GitService.instance.getRemotes(tempDir.path);
      expect(remotes.length, equals(1));
      expect(remotes.first.name, equals('origin'));
    });
  });

  group('GitErrorMapper 错误分类', () {
    late AppLocalizations l10nZh;
    late AppLocalizations l10nEn;

    setUp(() async {
      l10nZh = await AppLocalizations.delegate.load(const Locale('zh'));
      l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('识别认证失败（HTTP 401）', () {
      final info = GitErrorMapper.describe('fatal: Authentication failed for https://github.com/');
      expect(info.kind, equals(GitOperationErrorKind.authFailed));
      expect(info.needsAccountFix, isTrue);
      expect(info.kind.message(l10nZh), contains('认证失败'));
      expect(info.kind.suggestion(l10nZh), isNotEmpty);
    });

    test('错误文案具备中英双语（不再硬编码中文）', () {
      // 回归测试：GitErrorMapper 原先硬编码中文，绕过了项目的 l10n 体系
      const kind = GitOperationErrorKind.writePermissionDenied;
      expect(kind.message(l10nZh), equals('当前账号对该仓库没有写权限'));
      expect(kind.message(l10nEn), contains('no write access'));
      expect(kind.suggestion(l10nEn), contains('fork'));
    });

    test('每种错误类型都有非空的本地化文案', () {
      for (final kind in GitOperationErrorKind.values) {
        if (kind == GitOperationErrorKind.none) continue;
        expect(kind.message(l10nZh), isNotEmpty, reason: '${kind.name} 缺少中文说明');
        expect(kind.message(l10nEn), isNotEmpty, reason: '${kind.name} 缺少英文说明');
      }
    });

    test('区分平台已禁用密码认证', () {
      final info = GitErrorMapper.describe(
        'remote: Support for password authentication was removed on August 13, 2021.',
      );
      expect(info.kind, equals(GitOperationErrorKind.passwordAuthDisabled));
      expect(info.needsAccountFix, isTrue);
    });

    test('识别网络不可达', () {
      final info = GitErrorMapper.describe('fatal: unable to access: Could not resolve host: github.com');
      expect(info.kind, equals(GitOperationErrorKind.networkUnreachable));
      // 不应被误判为认证问题
      expect(info.needsAccountFix, isFalse);
    });

    test('识别 SSH 公钥被拒', () {
      final info = GitErrorMapper.describe('git@github.com: Permission denied (publickey).');
      expect(info.kind, equals(GitOperationErrorKind.sshPublicKeyDenied));
    });

    test('识别主机指纹未确认', () {
      final info = GitErrorMapper.describe('Host key verification failed.');
      expect(info.kind, equals(GitOperationErrorKind.hostKeyUnverified));
    });

    test('识别推送被拒并提供 Pull 后重试', () {
      final info = GitErrorMapper.describe(
        '! [rejected]        main -> main (non-fast-forward)\n'
        'error: failed to push some refs to origin',
      );
      expect(info.kind, equals(GitOperationErrorKind.nonFastForward));
      expect(info.canPullThenPush, isTrue);
    });

    test('强推租约失败优先于普通推送被拒', () {
      final info = GitErrorMapper.describe(
        '! [rejected]        main -> main (stale info)\n'
        'error: failed to push some refs to origin',
      );
      expect(info.kind, equals(GitOperationErrorKind.staleForcePush));
      expect(info.canRefreshThenRetry, isTrue);
      expect(info.canPullThenPush, isFalse);
    });

    test('识别 rebase 冲突', () {
      final info = GitErrorMapper.describe(
        'CONFLICT (content): Merge conflict in lib/main.dart\n'
        'error: could not apply abc1234... feat',
      );
      expect(info.kind, equals(GitOperationErrorKind.conflictDetected));
      expect(info.kind.suggestion(l10nZh), contains('rebase --abort'));
      expect(
        GitErrorMapper.isConflict('CONFLICT (content): Merge conflict in a.dart'),
        isTrue,
      );
    });

    test('识别本地改动会被覆盖', () {
      final info = GitErrorMapper.describe(
        'error: Your local changes to the following files would be overwritten by merge:',
      );
      expect(info.kind, equals(GitOperationErrorKind.localChangesWouldBeOverwritten));
    });

    test('识别未设置上游分支', () {
      final info = GitErrorMapper.describe(
        'fatal: The current branch feat has no upstream branch.',
      );
      expect(info.kind, equals(GitOperationErrorKind.noUpstreamConfigured));
    });

    test('识别远端仓库不存在', () {
      final info = GitErrorMapper.describe('remote: Repository not found.');
      expect(info.kind, equals(GitOperationErrorKind.repositoryNotFound));
    });

    test('识别引用锁冲突', () {
      final info = GitErrorMapper.describe(
        "fatal: Unable to create '/proj/.git/index.lock': File exists.",
      );
      expect(info.kind, equals(GitOperationErrorKind.refLockFailed));
    });

    test('识别磁盘空间不足', () {
      final info = GitErrorMapper.describe('fatal: write error: No space left on device');
      expect(info.kind, equals(GitOperationErrorKind.outOfSpace));
    });

    test('stderr 为空时回退解析 stdout', () {
      final info = GitErrorMapper.describe('', stdout: 'fatal: Authentication failed');
      expect(info.kind, equals(GitOperationErrorKind.authFailed));
    });

    test('完全无输出时归类为操作未完成', () {
      final info = GitErrorMapper.describe('');
      expect(info.kind, equals(GitOperationErrorKind.operationIncomplete));
      expect(info.kind.message(l10nZh), isNotEmpty);
    });

    test('未归类错误保留真实错误行便于排查', () {
      final info = GitErrorMapper.describe('fatal: something entirely unexpected happened');
      expect(info.kind, equals(GitOperationErrorKind.unknown));
      expect(info.rawDetail, contains('something entirely unexpected'));
    });

    // ---------------- HTTP 状态码细分（不做统一归并）----------------

    test('HTTP 407 单独归类为代理需要认证', () {
      final info = GitErrorMapper.describe(
        'fatal: unable to access ... : The requested URL returned error: 407',
      );
      expect(info.kind, equals(GitOperationErrorKind.proxyAuthRequired));
      // 不应与"令牌无效"混为一谈
      expect(info.kind, isNot(equals(GitOperationErrorKind.authFailed)));
      expect(info.needsAccountFix, isFalse);
    });

    test('HTTP 429 单独归类为限流', () {
      final info = GitErrorMapper.describe(
        'fatal: unable to access ... : The requested URL returned error: 429',
      );
      expect(info.kind, equals(GitOperationErrorKind.rateLimited));
    });

    test('HTTP 422 单独归类为请求被拒', () {
      final info = GitErrorMapper.describe(
        'fatal: unable to access ... : The requested URL returned error: 422',
      );
      expect(info.kind, equals(GitOperationErrorKind.requestRejected));
    });

    test('未列举的 HTTP 状态码保留原始码值', () {
      final info = GitErrorMapper.describe(
        'fatal: unable to access ... : The requested URL returned error: 502',
      );
      expect(info.kind, equals(GitOperationErrorKind.httpError));
      expect(info.rawDetail, equals('502'));
    });

    test('401/403/404/407/422/429 各自归入不同类型', () {
      const samples = {
        '401': GitOperationErrorKind.authFailed,
        '403': GitOperationErrorKind.writePermissionDenied,
        '404': GitOperationErrorKind.repositoryNotFound,
        '407': GitOperationErrorKind.proxyAuthRequired,
        '422': GitOperationErrorKind.requestRejected,
        '429': GitOperationErrorKind.rateLimited,
      };
      for (final entry in samples.entries) {
        final info = GitErrorMapper.describe(
          'fatal: unable to access ... : The requested URL returned error: ${entry.key}',
        );
        expect(
          info.kind,
          equals(entry.value),
          reason: 'HTTP ${entry.key} 应归类为 ${entry.value.name}',
        );
      }
    });

    test('输出只有进度行时不再把进度当作错误原因', () {
      // 真实事故：fetch 被超时打断，输出只剩进度，UI 却显示
      // "Git 操作失败 / remote: Enumerating objects: 2233, done."
      final info = GitErrorMapper.describe(
        'remote: Enumerating objects: 2233, done.\n'
        'remote: Counting objects: 100% (2233/2233), done.',
      );
      expect(info.kind, equals(GitOperationErrorKind.operationIncomplete));
      expect(info.kind.message(l10nZh), contains('没有返回具体错误信息'));
      // 关键：绝不能把进度行当错误展示
      expect(info.rawDetail, isNull);
      expect(info.kind.suggestion(l10nZh), isNot(contains('Enumerating objects')));
      expect(info.kind.suggestion(l10nZh), isNot(contains('Counting objects')));
    });

    test('纯进度输出即便带百分比也不被当作错误', () {
      final info = GitErrorMapper.describe(
        'Receiving objects:  45% (450/1000)\n'
        'Resolving deltas: 100% (7/7), done.',
      );
      expect(info.kind, equals(GitOperationErrorKind.operationIncomplete));
    });

    test('进度与真实错误混杂时挑出真实错误', () {
      final info = GitErrorMapper.describe(
        'remote: Enumerating objects: 2233, done.\n'
        'fatal: the remote end hung up unexpectedly',
      );
      expect(info.kind, equals(GitOperationErrorKind.unknown));
      expect(info.rawDetail, contains('remote end hung up unexpectedly'));
    });

    test('推送上游仓库被拒时提示 Fork，而不是甩锅给令牌', () {
      // 真实事故：origin 指向 ggml-org/llama.cpp（别人的仓库），
      // 原来的实现把 403 一律归为"令牌无效"，把排查方向带偏
      final info = GitErrorMapper.describe(
        'remote: Permission to ggml-org/llama.cpp.git denied to lzxnone.\n'
        'fatal: unable to access ... : The requested URL returned error: 403',
      );
      expect(info.kind, equals(GitOperationErrorKind.writePermissionDenied));
      expect(info.kind.message(l10nZh), contains('没有写权限'));
      expect(info.kind.suggestion(l10nZh), contains('Fork'));
      expect(info.fixAction, equals(GitErrorFixAction.openAccountManagement));
    });
  });

  group('远端分支解析与检出', () {
    test('解析 branch -r 输出并跳过 origin/HEAD 符号引用', () {
      // 用 --format=%(HEAD)|%(refname:short)，origin/HEAD 只会输出自己的名字
      // （箭头 -> 是 `git branch -r` 默认格式才有的，指定 --format 后不会出现）
      const stdout = '*|origin/main\n'
          ' |origin/feature/login\n'
          ' |origin/HEAD\n';

      final branches = GitService.instance.parseRemoteBranches(stdout);
      expect(branches.length, equals(2));
      expect(branches[0].name, equals('origin/main'));
      expect(branches[0].remoteName, equals('origin'));
      expect(branches[0].branchName, equals('main'));
      expect(branches[0].isCheckedOut, isTrue);
      expect(branches[1].name, equals('origin/feature/login'));
      expect(branches[1].isCheckedOut, isFalse);
      // origin/HEAD 不应出现（它是符号引用，不是可检出的分支）
      expect(branches.any((b) => b.name.endsWith('/HEAD')), isFalse);
    });

    test('兼容制表符分隔与 refs/remotes/ 完整引用', () {
      // `%(HEAD)` 前导空格的数量由 git 决定，因此解析必须容忍制表符
      const stdout = '*\trefs/remotes/origin/main\n'
          ' \torigin/dev\n';

      final branches = GitService.instance.parseRemoteBranches(stdout);
      expect(branches.length, equals(2));
      expect(branches[0].name, equals('origin/main'));
      expect(branches[0].isCheckedOut, isTrue);
      expect(branches[1].name, equals('origin/dev'));
    });

    test('多远程下分别解析出各自的远程名', () {
      const stdout = ' |upstream/master\n'
          ' |origin/master\n';

      final branches = GitService.instance.parseRemoteBranches(stdout);
      expect(
        branches.map((b) => b.remoteName).toList(),
        equals(['upstream', 'origin']),
      );
    });

    test('空输出与非法行不产生条目', () {
      final service = GitService.instance;
      expect(service.parseRemoteBranches(''), isEmpty);
      expect(service.parseRemoteBranches('\n  \n'), isEmpty);
      // 没有远程前缀的行无法判断归属，直接忽略
      expect(service.parseRemoteBranches(' \tjustbranch\t\n'), isEmpty);
    });

    test('本地无同名分支时以 --track 创建', () async {
      final executed = <List<String>>[];
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        executed.add(args);
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.contains('branch') && args.contains('--format=%(refname:short)')) {
          return ProcessResult(0, 0, 'master\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      final res = await GitService.instance.checkoutRemoteBranch(
        tempDir.path,
        'origin',
        'feature/login',
      );

      expect(res.success, isTrue);
      expect(
        executed.last,
        equals(['checkout', '-b', 'feature/login', '--track', 'origin/feature/login']),
      );
    });

    test('本地已有同名分支时直接切换，不重复创建', () async {
      final executed = <List<String>>[];
      GitService.instance.processRunner = (exec, args, {workingDirectory}) async {
        executed.add(args);
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'git version 2.45.0\n', '');
        }
        if (args.contains('branch') && args.contains('--format=%(refname:short)')) {
          return ProcessResult(0, 0, 'master\nfeature/login\n', '');
        }
        return ProcessResult(0, 0, '', '');
      };

      await GitService.instance.checkoutRemoteBranch(
        tempDir.path,
        'origin',
        'feature/login',
      );

      expect(executed.last, equals(['checkout', 'feature/login']));
    });

    test('分支名为空时直接失败', () async {
      final res = await GitService.instance.checkoutRemoteBranch(
        tempDir.path,
        'origin',
        '   ',
      );
      expect(res.success, isFalse);
    });
  });

  group('仓库自检解析', () {
    test('干净仓库判定为健康', () {
      final report = GitService.instance.parseFsckReport(
        'Checking object directories: 100% (256/256), done.\n',
        '',
        exitCode: 0,
      );
      expect(report.isHealthy, isTrue);
      expect(report.hasObjectLoss, isFalse);
      expect(report.problemCount, equals(0));
    });

    test('识别对象丢失 —— 正是导致 Error building trees 的元凶', () {
      final report = GitService.instance.parseFsckReport(
        'missing blob 26354cddec953ec05564851aed002b23ba9af4\n'
            'broken link from    tree 1234567\n'
            '              to    blob 26354cddec953ec05564851aed002b23ba9af4\n',
        '',
        exitCode: 2,
      );
      expect(report.hasObjectLoss, isTrue);
      expect(report.isHealthy, isFalse);
      expect(report.problemCount, greaterThan(0));
      expect(report.missing.length, equals(3));
    });

    test('悬空对象不算问题，仅作提示', () {
      final report = GitService.instance.parseFsckReport(
        'dangling blob abc123\n'
            'dangling commit def456\n',
        '',
        exitCode: 0,
      );
      // dangling 是正常现象：仓库仍然健康，不应吓到用户
      expect(report.isHealthy, isTrue);
      expect(report.hasObjectLoss, isFalse);
      expect(report.dangling.length, equals(2));
      expect(report.problemCount, equals(0));
    });

    test('stderr 中的问题同样被归类', () {
      final report = GitService.instance.parseFsckReport(
        '',
        'error: unable to read tree 1234567\n',
        exitCode: 2,
      );
      expect(report.hasObjectLoss, isTrue);
      expect(report.corrupt, isNotEmpty);
    });

    test('无问题但退出码非 0 时视为未能完成', () {
      final report = GitService.instance.parseFsckReport('', '', exitCode: -1);
      expect(report.isHealthy, isFalse);
      // 但这不是对象丢失，处置建议完全不同
      expect(report.hasObjectLoss, isFalse);
    });
  });

  group('克隆参数生成', () {
    test('基础克隆生成 clone --progress <url> <dir>', () async {
      fakeStream();
      await GitService.instance.clone(
        tempDir.path,
        'https://github.com/a/b.git',
        'b',
      );

      final cmd = calls.first.executable;
      expect(cmd, contains('clone --progress'));
      expect(cmd, contains('https://github.com/a/b.git b'));
      expect(cmd, isNot(contains('--depth')));
      expect(cmd, isNot(contains('--branch')));
    });

    test('支持指定分支与浅克隆深度', () async {
      fakeStream();
      await GitService.instance.clone(
        tempDir.path,
        'https://github.com/a/b.git',
        'b',
        branch: 'dev',
        depth: 1,
      );

      final cmd = calls.first.executable;
      expect(cmd, contains('--depth 1'));
      expect(cmd, contains('--branch dev'));
    });

    test('地址或目录名为空时拒绝执行', () async {
      fakeStream();
      final r1 = await GitService.instance.clone(tempDir.path, '  ', 'b');
      expect(r1.success, isFalse);
      final r2 = await GitService.instance.clone(
        tempDir.path,
        'https://x/y.git',
        '  ',
      );
      expect(r2.success, isFalse);
      expect(calls, isEmpty);
    });
  });
}
