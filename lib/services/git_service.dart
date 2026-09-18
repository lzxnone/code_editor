import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/distro_manifest.dart';
import '../models/git_model.dart';
import 'distro_manager.dart';
import 'internal_engine_service.dart';
import 'toolchain_service.dart';

/// Git 运行环境状态
class GitEnvironmentStatus {
  final bool isInstalled;
  final String? version;
  final String? errorMessage;

  const GitEnvironmentStatus({
    required this.isInstalled,
    this.version,
    this.errorMessage,
  });
}

/// Git 核心服务层（单例模式，封装底层命令行交互与文件系统快速探测）
class GitService {
  static final GitService instance = GitService._internal();
  GitService._internal();

  /// 允许在测试环境下自定义或注入命令处理器
  @visibleForTesting
  Future<ProcessResult> Function(String executable, List<String> arguments, {String? workingDirectory})?
      processRunner;

  /// 自定义 Git 可执行程序路径（默认从系统 PATH 查找 'git'）
  String gitExecutable = 'git';

  /// 缓存的 Git 环境可用状态
  GitEnvironmentStatus? _cachedEnvStatus;

  /// 重置测试环境状态与进程注入
  void resetForTesting() {
    processRunner = null;
    _cachedEnvStatus = null;
  }

  /// 快速检查系统或容器中是否存在 Git 命令行工具
  Future<GitEnvironmentStatus> checkGitInstalled({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedEnvStatus != null) {
      return _cachedEnvStatus!;
    }

    // 1. 如果测试环境注入了 processRunner，优先走注入的 runner
    if (processRunner != null) {
      try {
        final res = await processRunner!(gitExecutable, ['--version']);
        if (res.exitCode == 0) {
          _cachedEnvStatus = GitEnvironmentStatus(
            isInstalled: true,
            version: res.stdout.toString().trim(),
          );
        } else {
          _cachedEnvStatus = GitEnvironmentStatus(
            isInstalled: false,
            errorMessage: res.stderr.toString().trim(),
          );
        }
        return _cachedEnvStatus!;
      } catch (e) {
        _cachedEnvStatus = GitEnvironmentStatus(
          isInstalled: false,
          errorMessage: e.toString(),
        );
        return _cachedEnvStatus!;
      }
    }

    // 2. Android 真实设备环境：双重探测机制（优先探测内置 Ubuntu 容器环境）
    if (Platform.isAndroid) {
      final engine = InternalEngineService.instance;
      if (await engine.isEngineInstalled()) {
        final rootfs = await engine.getRootfsDir();
        // 物理根文件系统快速探测（毫秒级，直接检测 /usr/bin/git 等文件物理存在）
        final physicallyInstalled = ToolchainService.isToolInstalledInRootfs(rootfs, 'git');
        if (!physicallyInstalled) {
          _cachedEnvStatus = const GitEnvironmentStatus(
            isInstalled: false,
            errorMessage: '内置开发环境尚未安装 Git',
          );
          return _cachedEnvStatus!;
        }

        // 物理存在，进一步尝试在容器中执行 git --version 获取详细版本字符串
        try {
          final res = await _runProcess(gitExecutable, ['--version']);
          if (res.exitCode == 0) {
            final versionStr = res.stdout.toString().trim();
            _cachedEnvStatus = GitEnvironmentStatus(
              isInstalled: true,
              version: versionStr.isNotEmpty ? versionStr : 'git (installed)',
            );
          } else {
            // 物理文件已在 rootfs 中，即便进程拉取临时异常也确凿判定为已安装
            _cachedEnvStatus = const GitEnvironmentStatus(
              isInstalled: true,
              version: 'git (installed in engine)',
            );
          }
        } catch (_) {
          _cachedEnvStatus = const GitEnvironmentStatus(
            isInstalled: true,
            version: 'git (installed in engine)',
          );
        }

        // 异步确保配置 safe.directory 与默认用户信息
        ensureGitUserConfigured();

        return _cachedEnvStatus!;
      } else {
        _cachedEnvStatus = const GitEnvironmentStatus(
          isInstalled: false,
          errorMessage: '内置开发引擎尚未初始化',
        );
        return _cachedEnvStatus!;
      }
    }

    // 3. 桌面平台 (Windows / macOS / Linux) 标准 PATH 检测
    try {
      final res = await _runProcess(gitExecutable, ['--version']);
      if (res.exitCode == 0) {
        final versionStr = res.stdout.toString().trim();
        _cachedEnvStatus = GitEnvironmentStatus(
          isInstalled: true,
          version: versionStr,
        );
        return _cachedEnvStatus!;
      } else {
        _cachedEnvStatus = GitEnvironmentStatus(
          isInstalled: false,
          errorMessage: res.stderr.toString().trim(),
        );
        return _cachedEnvStatus!;
      }
    } on ProcessException catch (e) {
      _cachedEnvStatus = GitEnvironmentStatus(
        isInstalled: false,
        errorMessage: e.message,
      );
      return _cachedEnvStatus!;
    } catch (e) {
      _cachedEnvStatus = GitEnvironmentStatus(
        isInstalled: false,
        errorMessage: e.toString(),
      );
      return _cachedEnvStatus!;
    }
  }

  /// 自动确保 Git 基础配置就绪（safe.directory 豁免 + 默认提交者占位符 + 避免 link2symlink 逃逸）
  Future<void> ensureGitUserConfigured() async {
    try {
      await _runProcess('git', ['config', '--global', '--add', 'safe.directory', '*']);
      // 核心修复：强制 Git 使用 rename 而非 link() 创建对象，
      // 根除 PRoot --link2symlink 将对象伪装软链接放入容器内部 rootfs/.l2s，
      // 保证容器重建时项目目录内的 Git loose objects 绝不会丢失！
      await _runProcess('git', ['config', '--global', 'core.createObject', 'rename']);
      final nameCheck = await _runProcess('git', ['config', '--global', 'user.name']);
      if (nameCheck.stdout.toString().trim().isEmpty) {
        await _runProcess('git', ['config', '--global', 'user.name', 'CodeEditor User']);
      }
      final emailCheck = await _runProcess('git', ['config', '--global', 'user.email']);
      if (emailCheck.stdout.toString().trim().isEmpty) {
        await _runProcess('git', ['config', '--global', 'user.email', 'user@codeeditor.local']);
      }
    } catch (_) {}
  }

  /// 统一安全的 Git 命令执行封装
  Future<GitCommandResult> runGitCommand(
    List<String> args, {
    required String workingDir,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final env = await checkGitInstalled();
    if (!env.isInstalled) {
      return GitCommandResult.error(
        env.errorMessage ?? '未检测到 Git 命令行工具，请先在系统或容器中安装 git',
      );
    }

    try {
      final res = await _runProcess(
        gitExecutable,
        args,
        workingDirectory: workingDir,
      ).timeout(timeout, onTimeout: () {
        throw ProcessException(
          gitExecutable,
          args,
          'Git 命令执行超时 (${timeout.inSeconds}s)',
          -1,
        );
      });

      final stdout = res.stdout.toString();
      final stderr = res.stderr.toString();
      return GitCommandResult(
        success: res.exitCode == 0,
        exitCode: res.exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } on ProcessException catch (e) {
      return GitCommandResult.error(e.message, exitCode: e.errorCode);
    } catch (e) {
      return GitCommandResult.error(e.toString());
    }
  }

  /// 快速检查指定目录是否为 Git 仓库（轻量级文件系统探测，无进程开销）
  bool isGitRepository(String dirPath) {
    try {
      final dotGit = p.join(dirPath, '.git');
      return Directory(dotGit).existsSync() || File(dotGit).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 探测工作区中存在的所有 Git 仓库（支持主仓库与子模块/嵌套仓库）
  Future<List<GitRepositoryInfo>> detectRepositories(
    String rootPath, {
    int maxDepth = 2,
  }) async {
    final normalizedRoot = p.normalize(rootPath);
    final List<GitRepositoryInfo> repos = [];

    // 1. 首先检查工程根目录自身是否是 Git 仓库
    if (isGitRepository(normalizedRoot)) {
      final branch = await getCurrentBranch(normalizedRoot);
      repos.add(GitRepositoryInfo(
        rootPath: normalizedRoot,
        name: p.basename(normalizedRoot).isEmpty ? normalizedRoot : p.basename(normalizedRoot),
        isRoot: true,
        currentBranch: branch,
      ));
    }

    // 2. 浅层递归扫描子目录中的嵌套仓库或子模块 (Submodules)
    final rootDir = Directory(normalizedRoot);
    if (rootDir.existsSync()) {
      await _scanSubRepositories(rootDir, normalizedRoot, 1, maxDepth, repos);
    }

    return repos;
  }

  /// 递归扫描子仓库
  Future<void> _scanSubRepositories(
    Directory dir,
    String rootPath,
    int currentDepth,
    int maxDepth,
    List<GitRepositoryInfo> outRepos,
  ) async {
    if (currentDepth > maxDepth) return;

    try {
      final entries = dir.listSync(followLinks: false);
      for (final entry in entries) {
        if (entry is! Directory) continue;
        final name = p.basename(entry.path);

        // 跳过高频临时、依赖与隐藏目录
        if (name.startsWith('.') ||
            name == 'node_modules' ||
            name == 'build' ||
            name == '.dart_tool' ||
            name == 'Pods' ||
            name == 'DerivedData' ||
            name == 'target') {
          continue;
        }

        final subPath = p.normalize(entry.path);
        if (isGitRepository(subPath)) {
          final branch = await getCurrentBranch(subPath);
          final relativeName = p.relative(subPath, from: rootPath);
          final info = GitRepositoryInfo(
            rootPath: subPath,
            name: relativeName,
            isRoot: false,
            currentBranch: branch,
          );
          if (!outRepos.contains(info)) {
            outRepos.add(info);
          }
        } else {
          // 未发现 .git 则继续向下探测一层
          await _scanSubRepositories(entry, rootPath, currentDepth + 1, maxDepth, outRepos);
        }
      }
    } catch (_) {}
  }

  /// 初始化本地 Git 仓库
  Future<GitCommandResult> initRepository(
    String path, {
    String defaultBranch = 'main',
  }) async {
    final targetDir = Directory(path);
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (e) {
        return GitCommandResult.error('创建仓库目录失败: $e');
      }
    }

    // 尝试带 -b 参数直接初始化默认分支名
    var result = await runGitCommand(
      ['init', '-b', defaultBranch],
      workingDir: path,
    );

    // 如果 Git 版本较老不支持 init -b，退化为普通 init 并重命名/创建分支
    if (!result.success && result.stderr.contains('unknown switch `b\'')) {
      result = await runGitCommand(['init'], workingDir: path);
      if (result.success) {
        await runGitCommand(['checkout', '-b', defaultBranch], workingDir: path);
      }
    }

    return result;
  }

  /// 安装 Git
  Future<GitCommandResult> installGit({
    void Function(String output)? onProgress,
  }) async {
    // 1. 如果设置了测试注入的 processRunner
    if (processRunner != null) {
      final res = await _runProcess(gitExecutable, ['install-git']);
      if (res.exitCode == 0) {
        _cachedEnvStatus = null;
        await checkGitInstalled(forceRefresh: true);
        return GitCommandResult(
          success: true,
          exitCode: 0,
          stdout: res.stdout.toString(),
          stderr: '',
        );
      } else {
        return GitCommandResult.error(
          res.stderr.toString().isNotEmpty ? res.stderr.toString() : '安装 Git 失败',
          exitCode: res.exitCode,
        );
      }
    }

    // 2. 内置引擎环境安装 (Ubuntu PRoot)
    final engine = InternalEngineService.instance;
    if (await engine.isEngineInstalled()) {
      final success = await engine.installPackage('git', onOutput: onProgress);
      if (success) {
        _cachedEnvStatus = null;
        final env = await checkGitInstalled(forceRefresh: true);
        if (env.isInstalled) {
          await ensureGitUserConfigured();
          return const GitCommandResult(
            success: true,
            exitCode: 0,
            stdout: 'Git 安装成功',
            stderr: '',
          );
        }
      }
      return GitCommandResult.error('通过引擎安装 Git 失败');
    }

    // 3. 宿主 Linux / Termux 环境下尝试通过包管理器安装
    if (!Platform.isWindows && !Platform.isIOS) {
      try {
        final res = await Process.run(
          'apt-get',
          ['install', '-y', 'git'],
          runInShell: true,
        );
        if (res.exitCode == 0) {
          _cachedEnvStatus = null;
          await checkGitInstalled(forceRefresh: true);
          return GitCommandResult(
            success: true,
            exitCode: 0,
            stdout: res.stdout.toString(),
            stderr: '',
          );
        }
      } catch (_) {}
    }

    return GitCommandResult.error('当前环境不支持自动安装 Git，请在内置引擎或终端中手动安装');
  }

  /// 获取仓库当前检出信息（分支名或标签名，以及是否为标签）
  Future<({String name, bool isTag})> getCurrentRefInfo(String repoPath) async {
    // 优先尝试从 git 命令行获取当前分支
    final res = await runGitCommand(
      ['branch', '--show-current'],
      workingDir: repoPath,
    );
    if (res.success && res.stdout.trim().isNotEmpty) {
      return (name: res.stdout.trim(), isTag: false);
    }

    // 尝试检查 HEAD 是否精确匹配某个本地/远程标签
    final tagRes = await runGitCommand(
      ['describe', '--tags', '--exact-match', 'HEAD'],
      workingDir: repoPath,
    );
    if (tagRes.success && tagRes.stdout.trim().isNotEmpty) {
      return (name: tagRes.stdout.trim(), isTag: true);
    }

    // 尝试 symbolic-ref
    final symRes = await runGitCommand(
      ['symbolic-ref', '--short', 'HEAD'],
      workingDir: repoPath,
    );
    if (symRes.success && symRes.stdout.trim().isNotEmpty) {
      return (name: symRes.stdout.trim(), isTag: false);
    }

    // 针对新初始化尚未进行任何 commit 的空仓库，命令行可能返回空，直接从 .git/HEAD 文件解析
    try {
      final headFile = File(p.join(repoPath, '.git', 'HEAD'));
      if (headFile.existsSync()) {
        final content = headFile.readAsStringSync().trim();
        if (content.startsWith('ref: refs/heads/')) {
          return (name: content.substring('ref: refs/heads/'.length).trim(), isTag: false);
        }
      }
    } catch (_) {}

    // 尝试获取 Detached HEAD 哈希
    final revRes = await runGitCommand(
      ['rev-parse', '--short', 'HEAD'],
      workingDir: repoPath,
    );
    if (revRes.success && revRes.stdout.trim().isNotEmpty) {
      return (name: 'detached (${revRes.stdout.trim()})', isTag: false);
    }

    return (name: 'main', isTag: false);
  }

  /// 获取仓库当前分支名称（兼容新建未提交仓库从 .git/HEAD 兜底解析）
  Future<String> getCurrentBranch(String repoPath) async {
    final info = await getCurrentRefInfo(repoPath);
    return info.name;
  }

  /// 获取本地分支列表
  Future<List<String>> getLocalBranches(String repoPath) async {
    final res = await runGitCommand(
      ['branch', '--format=%(refname:short)'],
      workingDir: repoPath,
    );
    if (!res.success) {
      final fbRes = await runGitCommand(['branch'], workingDir: repoPath);
      if (!fbRes.success) return [];
      return LineSplitter.split(fbRes.stdout)
          .map((line) => line.replaceAll('*', '').trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return LineSplitter.split(res.stdout)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 切换分支 (`git checkout <branchName>`)
  Future<GitCommandResult> checkoutBranch(String repoPath, String branchName) async {
    return runGitCommand(['checkout', branchName], workingDir: repoPath);
  }

  /// 创建新分支 (`git checkout -b <branchName>` 或 `git branch <branchName>`)
  Future<GitCommandResult> createBranch(
    String repoPath,
    String branchName, {
    bool checkout = true,
  }) async {
    if (checkout) {
      return runGitCommand(['checkout', '-b', branchName], workingDir: repoPath);
    } else {
      return runGitCommand(['branch', branchName], workingDir: repoPath);
    }
  }

  /// 删除本地分支 (`git branch -d` / `-D`)，支持强力清理坏损无对象分支
  Future<GitCommandResult> deleteBranch(
    String repoPath,
    String branchName, {
    bool force = false,
  }) async {
    final res = await runGitCommand(
      ['branch', force ? '-D' : '-d', branchName],
      workingDir: repoPath,
    );
    if (res.success) return res;

    // 针对树对象损坏或缺失的分支（如 fatal: reference is not a tree），
    // 允许通过物理删除 .git/refs/heads/<branchName> 解除阻断
    if (force ||
        res.stderr.contains('reference is not a tree') ||
        res.stderr.contains('not a valid object name') ||
        res.stderr.contains('unable to resolve reference')) {
      try {
        final refFile = File(p.join(repoPath, '.git', 'refs', 'heads', branchName));
        if (refFile.existsSync()) {
          refFile.deleteSync();
          return const GitCommandResult(
            success: true,
            exitCode: 0,
            stdout: 'Deleted damaged branch reference',
            stderr: '',
          );
        }
      } catch (_) {}
    }

    return res;
  }

  /// 获取本地标签列表 (`git tag -l`)
  Future<List<String>> getTags(String repoPath) async {
    final res = await runGitCommand(['tag', '-l'], workingDir: repoPath);
    if (!res.success || res.stdout.trim().isEmpty) return [];
    return LineSplitter.split(res.stdout)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 创建标签 (`git tag <name>` 或 `git tag -a <name> -m <msg>`)
  Future<GitCommandResult> createTag(
    String repoPath,
    String tagName, {
    String? message,
  }) async {
    if (tagName.trim().isEmpty) {
      return GitCommandResult.error('标签名称不能为空');
    }
    final cleanName = tagName.trim();
    if (message != null && message.trim().isNotEmpty) {
      return runGitCommand(['tag', '-a', cleanName, '-m', message.trim()], workingDir: repoPath);
    }
    return runGitCommand(['tag', cleanName], workingDir: repoPath);
  }

  /// 删除本地标签 (`git tag -d <name>`)
  Future<GitCommandResult> deleteTag(String repoPath, String tagName) async {
    return runGitCommand(['tag', '-d', tagName.trim()], workingDir: repoPath);
  }

  /// 检出指定标签 (`git checkout <name>`)
  Future<GitCommandResult> checkoutTag(String repoPath, String tagName) async {
    return runGitCommand(['checkout', tagName.trim()], workingDir: repoPath);
  }

  /// 获取仓库当前工作区变更状态列表 (git status --porcelain -uall)
  Future<List<GitFileStatus>> getGitStatus(String repoPath) async {
    final result = await runGitCommand(
      ['status', '--porcelain', '-uall'],
      workingDir: repoPath,
    );

    if (!result.success) {
      return [];
    }

    final lines = LineSplitter.split(result.stdout);
    final List<GitFileStatus> items = [];

    for (final line in lines) {
      if (line.length < 4) continue;
      final x = line[0];
      final y = line[1];
      final pathPart = line.substring(3).trim();

      String rawPath = pathPart;
      String? originalPath;
      if (pathPart.contains(' -> ')) {
        final parts = pathPart.split(' -> ');
        originalPath = _unquote(parts[0].trim());
        rawPath = _unquote(parts[1].trim());
      } else {
        rawPath = _unquote(rawPath);
      }

      final fullPath = p.normalize(p.join(repoPath, rawPath));

      // 暂存区状态 (Index / Staged)
      if (x != ' ' && x != '?' && x != '!') {
        items.add(GitFileStatus(
          path: fullPath,
          relativePath: rawPath,
          statusType: _mapStatusCode(x),
          isStaged: true,
          originalPath: originalPath,
        ));
      }

      // 工作区未暂存状态 (Worktree / Unstaged)
      if (y != ' ' && y != '?' && y != '!') {
        items.add(GitFileStatus(
          path: fullPath,
          relativePath: rawPath,
          statusType: _mapStatusCode(y),
          isStaged: false,
          originalPath: originalPath,
        ));
      }

      // 未跟踪文件 (Untracked ??)
      if (x == '?' && y == '?') {
        items.add(GitFileStatus(
          path: fullPath,
          relativePath: rawPath,
          statusType: GitFileStatusType.untracked,
          isStaged: false,
        ));
      }
    }

    return items;
  }

  /// 暂存单个文件的更改 (`git add -- <relativePath>`)
  Future<GitCommandResult> stageFile(String repoPath, String relativePath) async {
    return runGitCommand(['add', '--', relativePath], workingDir: repoPath);
  }

  /// 取消暂存单个文件的更改 (`git restore --staged` / `git reset HEAD`)
  Future<GitCommandResult> unstageFile(String repoPath, String relativePath) async {
    final res = await runGitCommand(
      ['restore', '--staged', '--', relativePath],
      workingDir: repoPath,
    );
    if (res.success) return res;

    // 针对老版本 Git 退化回退使用 reset HEAD
    return runGitCommand(['reset', 'HEAD', '--', relativePath], workingDir: repoPath);
  }

  /// 全部暂存所有更改 (`git add -A`)
  Future<GitCommandResult> stageAll(String repoPath) async {
    return runGitCommand(['add', '-A'], workingDir: repoPath);
  }

  /// 全部取消暂存所有更改 (`git restore --staged .` / `git reset HEAD`)
  Future<GitCommandResult> unstageAll(String repoPath) async {
    final res = await runGitCommand(['restore', '--staged', '.'], workingDir: repoPath);
    if (res.success) return res;

    // 针对老版本 Git 退化回退使用 reset HEAD
    return runGitCommand(['reset', 'HEAD'], workingDir: repoPath);
  }

  /// 放弃单个文件的更改 (`git restore` / `git checkout` 或未跟踪物理删除)
  Future<GitCommandResult> discardFile(
    String repoPath,
    String relativePath, {
    required bool isUntracked,
    bool isStaged = false,
  }) async {
    if (isUntracked) {
      final fullPath = p.normalize(p.join(repoPath, relativePath));
      try {
        final file = File(fullPath);
        if (file.existsSync()) {
          file.deleteSync();
          return const GitCommandResult(success: true, exitCode: 0, stdout: 'Deleted', stderr: '');
        }
        final dir = Directory(fullPath);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
          return const GitCommandResult(success: true, exitCode: 0, stdout: 'Deleted', stderr: '');
        }
        return const GitCommandResult(success: true, exitCode: 0, stdout: '', stderr: '');
      } catch (e) {
        return GitCommandResult.error('删除未跟踪文件失败: $e');
      }
    }

    if (isStaged) {
      var res = await runGitCommand(['restore', '--staged', '--worktree', '--', relativePath], workingDir: repoPath);
      if (res.success) return res;
      await runGitCommand(['restore', '--staged', '--', relativePath], workingDir: repoPath);
      await runGitCommand(['reset', 'HEAD', '--', relativePath], workingDir: repoPath);
      res = await runGitCommand(['restore', '--', relativePath], workingDir: repoPath);
      if (res.success) return res;
      return runGitCommand(['checkout', '--', relativePath], workingDir: repoPath);
    }

    // 已跟踪未暂存文件执行 restore，回退 fallback 到 checkout
    final res = await runGitCommand(['restore', '--', relativePath], workingDir: repoPath);
    if (res.success) return res;

    return runGitCommand(['checkout', '--', relativePath], workingDir: repoPath);
  }

  /// 放弃所有未暂存更改 (恢复工作区已跟踪文件修改并清理未跟踪新文件)
  Future<GitCommandResult> discardAllUnstaged(String repoPath) async {
    var res = await runGitCommand(['restore', '.'], workingDir: repoPath);
    if (!res.success) {
      res = await runGitCommand(['checkout', '--', '.'], workingDir: repoPath);
    }
    await runGitCommand(['clean', '-fd'], workingDir: repoPath);
    return res;
  }

  /// 放弃所有已暂存更改 (取消暂存并还原至 HEAD)
  Future<GitCommandResult> discardAllStaged(String repoPath) async {
    var res = await runGitCommand(['restore', '--staged', '--worktree', '.'], workingDir: repoPath);
    if (!res.success) {
      await runGitCommand(['restore', '--staged', '.'], workingDir: repoPath);
      await runGitCommand(['reset', 'HEAD'], workingDir: repoPath);
      res = await runGitCommand(['restore', '.'], workingDir: repoPath);
      if (!res.success) {
        res = await runGitCommand(['checkout', '--', '.'], workingDir: repoPath);
      }
    }
    return res;
  }

  /// 撤销上一次提交，保留暂存区与工作区更改 (`git reset --soft HEAD~1`)
  Future<GitCommandResult> undoLastCommit(String repoPath) async {
    return runGitCommand(['reset', '--soft', 'HEAD~1'], workingDir: repoPath);
  }

  /// 提交更改 (`git commit -m <message>` 或 `git commit --amend -m <message>`)
  Future<GitCommandResult> commit(
    String repoPath,
    String message, {
    bool amend = false,
  }) async {
    if (message.trim().isEmpty) {
      return GitCommandResult.error('提交信息不能为空');
    }
    final args = ['commit'];
    if (amend) {
      args.add('--amend');
    }
    args.addAll(['-m', message.trim()]);
    return runGitCommand(args, workingDir: repoPath);
  }

  /// 贮藏当前工作区更改 (`git stash push` 或 `git stash push -m <msg>`)
  Future<GitCommandResult> stash(String repoPath, {String? message}) async {
    final args = ['stash', 'push'];
    if (message != null && message.trim().isNotEmpty) {
      args.addAll(['-m', message.trim()]);
    }
    return runGitCommand(args, workingDir: repoPath);
  }

  /// 恢复最近贮藏 (`git stash pop`)
  Future<GitCommandResult> stashPop(String repoPath) async {
    return runGitCommand(['stash', 'pop'], workingDir: repoPath);
  }

  /// 获取当前贮藏栈条目数量 (`git stash list`)
  Future<int> getStashCount(String repoPath) async {
    final res = await runGitCommand(['stash', 'list'], workingDir: repoPath);
    if (!res.success || res.stdout.trim().isEmpty) return 0;
    return LineSplitter.split(res.stdout).where((l) => l.trim().isNotEmpty).length;
  }

  /// 将相对路径添加到 .gitignore
  Future<bool> addToGitignore(String repoPath, String relativePath) async {
    try {
      final gitignoreFile = File(p.join(repoPath, '.gitignore'));
      final normalized = relativePath.replaceAll('\\', '/');
      String content = '';
      if (gitignoreFile.existsSync()) {
        content = gitignoreFile.readAsStringSync();
      }
      final lines = LineSplitter.split(content).map((l) => l.trim()).toList();
      if (lines.contains(normalized) || lines.contains('/$normalized')) {
        return true;
      }
      final appendContent = content.endsWith('\n') || content.isEmpty
          ? '$normalized\n'
          : '\n$normalized\n';
      gitignoreFile.writeAsStringSync(appendContent, mode: FileMode.append);
      return true;
    } catch (e) {
      debugPrint('[GitService] 添加到 .gitignore 异常: $e');
      return false;
    }
  }

  /// 获取指定引用或索引区中的文件历史内容 (如 `git show HEAD:file.txt` 或 `git show :0:file.txt`)
  Future<String?> getFileContentAtRef(
    String repoPath,
    String ref,
    String relativePath,
  ) async {
    final normalized = relativePath.replaceAll('\\', '/');
    final res = await runGitCommand(
      ['show', '$ref:$normalized'],
      workingDir: repoPath,
    );
    if (!res.success) {
      return null;
    }
    return res.stdout;
  }

  /// 获取变更文件的基准版本内容 (用于 Diff 对比)
  Future<String?> getFileBaseContent(String repoPath, GitFileStatus file) async {
    // 1. 未跟踪文件没有基准内容
    if (file.statusType == GitFileStatusType.untracked) {
      return '';
    }

    // 2. 如果是暂存区文件，对比的是 HEAD 上的内容
    if (file.isStaged) {
      final content = await getFileContentAtRef(repoPath, 'HEAD', file.originalPath ?? file.relativePath);
      return content ?? '';
    }

    // 3. 如果是未暂存文件，优先对比暂存区版本 (:0)，若无则对比 HEAD
    final stagedContent = await getFileContentAtRef(repoPath, ':0', file.originalPath ?? file.relativePath);
    if (stagedContent != null) {
      return stagedContent;
    }
    final headContent = await getFileContentAtRef(repoPath, 'HEAD', file.originalPath ?? file.relativePath);
    return headContent ?? '';
  }

  /// 获取变更文件的当前修改内容 (用于 Diff 对比)
  Future<String> getFileModifiedContent(String repoPath, GitFileStatus file) async {
    if (file.statusType == GitFileStatusType.deleted) {
      return '';
    }
    // 如果是暂存区文件，读取暂存区版本内容 (:0)
    if (file.isStaged) {
      final content = await getFileContentAtRef(repoPath, ':0', file.relativePath);
      if (content != null) return content;
    }
    // 否则直接读取本地工作区磁盘文件
    try {
      final f = File(file.path);
      if (f.existsSync()) {
        return f.readAsStringSync();
      }
    } catch (_) {}
    return '';
  }

  /// 获取当前分支/HEAD的提交总数
  Future<int> getTotalCommitsCount(String repoPath) async {
    try {
      final res = await _runProcess(
        gitExecutable,
        ['rev-list', '--count', 'HEAD'],
        workingDirectory: repoPath,
      );
      if (res.exitCode == 0) {
        final text = res.stdout.toString().trim();
        return int.tryParse(text) ?? 0;
      }
    } catch (e) {
      debugPrint('[GitService] 获取提交总数失败: $e');
    }
    return 0;
  }

  /// 获取仓库提交历史记录并计算图表拓扑布局
  Future<List<GitCommit>> getLog(
    String repoPath, {
    int maxCount = 50,
  }) async {
    try {
      final res = await _runProcess(
        gitExecutable,
        [
          'log',
          '-n',
          maxCount.toString(),
          '--format=%H%x00%h%x00%P%x00%an%x00%ae%x00%at%x00%ar%x00%s%x00%D',
        ],
        workingDirectory: repoPath,
      );

      // 仓库尚无提交（如新建空分支/空仓库），git log 返回非 0，正常返回空列表
      if (res.exitCode != 0) {
        return [];
      }

      final raw = res.stdout.toString().trim();
      if (raw.isEmpty) return [];

      final lines = raw.split('\n');
      final rawCommits = <GitCommit>[];

      for (final line in lines) {
        final cleanLine = line.trim();
        if (cleanLine.isEmpty) continue;

        final parts = cleanLine.split('\x00');
        if (parts.length < 8) continue;

        final hash = parts[0].trim();
        final shortHash = parts[1].trim();
        final parentsRaw = parts[2].trim();
        final parentHashes = parentsRaw.isEmpty ? <String>[] : parentsRaw.split(' ').where((p) => p.isNotEmpty).toList();
        final authorName = parts[3].trim();
        final authorEmail = parts[4].trim();
        final timestampSec = int.tryParse(parts[5].trim()) ?? 0;
        final authorDate = DateTime.fromMillisecondsSinceEpoch(timestampSec * 1000);
        final relativeDate = parts[6].trim();
        final subject = parts[7].trim();
        final refsRaw = parts.length > 8 ? parts[8].trim() : '';
        final refs = refsRaw.isEmpty
            ? <String>[]
            : refsRaw
                .split(',')
                .map((r) => r.trim())
                .where((r) => r.isNotEmpty)
                .toList();

        rawCommits.add(GitCommit(
          hash: hash,
          shortHash: shortHash,
          parentHashes: parentHashes,
          authorName: authorName,
          authorEmail: authorEmail,
          authorDate: authorDate,
          relativeDate: relativeDate,
          subject: subject,
          refs: refs,
        ));
      }

      return computeGraphLanes(rawCommits);
    } catch (e) {
      debugPrint('[GitService] 获取 Git 提交历史异常: $e');
      return [];
    }
  }

  /// 计算 Git 图表通道拓扑关系 (为每个提交分配 lane，计算 pass-through 和连线)
  static List<GitCommit> computeGraphLanes(List<GitCommit> rawCommits) {
    final List<GitCommit> result = [];
    final List<String?> activeLanes = [];

    for (final commit in rawCommits) {
      // 1. 查找此 commit 是否已有分配的 lane
      int lane = activeLanes.indexOf(commit.hash);
      if (lane == -1) {
        // 分配一个空闲 lane 或者追加新 lane
        lane = activeLanes.indexOf(null);
        if (lane == -1) {
          lane = activeLanes.length;
          activeLanes.add(commit.hash);
        } else {
          activeLanes[lane] = commit.hash;
        }
      }

      // 此时穿过这一行的活跃 lanes（不为 null 的通道）
      final currentActive = <int>[];
      for (int i = 0; i < activeLanes.length; i++) {
        if (activeLanes[i] != null) {
          currentActive.add(i);
        }
      }

      // 2. 为此 commit 的父提交更新 activeLanes
      final outgoing = <int>[];
      if (commit.parentHashes.isNotEmpty) {
        // 第一个父提交继续占用当前 lane
        activeLanes[lane] = commit.parentHashes.first;
        outgoing.add(lane);

        // 其他父提交（如有 merge 节点）
        for (int p = 1; p < commit.parentHashes.length; p++) {
          final parentHash = commit.parentHashes[p];
          int pLane = activeLanes.indexOf(parentHash);
          if (pLane == -1) {
            pLane = activeLanes.indexOf(null);
            if (pLane == -1) {
              pLane = activeLanes.length;
              activeLanes.add(parentHash);
            } else {
              activeLanes[pLane] = parentHash;
            }
          }
          outgoing.add(pLane);
        }
      } else {
        // 根提交（没有父提交），释放该 lane
        activeLanes[lane] = null;
      }

      // 清理尾部连续为 null 的通道
      while (activeLanes.isNotEmpty && activeLanes.last == null) {
        activeLanes.removeLast();
      }

      result.add(commit.copyWith(
        lane: lane,
        activeLanes: currentActive,
        outgoingLanes: outgoing,
      ));
    }
    return result;
  }

  /// 状态码映射
  GitFileStatusType _mapStatusCode(String code) {
    switch (code) {
      case 'M':
        return GitFileStatusType.modified;
      case 'A':
        return GitFileStatusType.added;
      case 'D':
        return GitFileStatusType.deleted;
      case 'R':
        return GitFileStatusType.renamed;
      case 'C':
        return GitFileStatusType.copied;
      case 'T':
        return GitFileStatusType.typeChange;
      case 'U':
        return GitFileStatusType.unmerged;
      case '!':
        return GitFileStatusType.ignored;
      case '?':
        return GitFileStatusType.untracked;
      default:
        return GitFileStatusType.unknown;
    }
  }

  String _unquote(String s) {
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  String _escapeShellArg(String arg) {
    if (RegExp(r'^[a-zA-Z0-9_\.\-\/=:]+$').hasMatch(arg)) {
      return arg;
    }
    return "'${arg.replaceAll("'", r"'\''")}'";
  }

  Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (processRunner != null) {
      return processRunner!(executable, arguments, workingDirectory: workingDirectory);
    }

    // 1. Android 真实设备环境下，优先在内置 Ubuntu PRoot / Chroot 容器中执行
    if (Platform.isAndroid) {
      final engine = InternalEngineService.instance;
      if (await engine.isEngineInstalled()) {
        final rootfs = await engine.getRootfsDir();
        final escapedArgs = arguments.map(_escapeShellArg).join(' ');
        // 自动注入 safe.directory 避免 Android/PRoot 跨 UID 权限所有权检查报错
        final fullCmd = (executable == 'git' || executable.endsWith('/git'))
            ? 'git -c safe.directory=* $escapedArgs'.trim()
            : '$executable $escapedArgs'.trim();

        try {
          final res = await DistroManager().runHeadlessCommand(
            systemName: DistroRepository.defaultSystemName,
            customRootDir: rootfs,
            workspacePath: workingDirectory,
            command: fullCmd,
            timeout: timeout,
          );
          if (res != null) {
            return res;
          }
        } catch (e) {
          debugPrint('[GitService] 容器引擎命令执行异常: $e');
        }
      }
    }

    // 2. 桌面平台 (Windows / macOS / Linux) 或 Android 降级回退
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
  }
}
