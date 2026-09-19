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

/// 云端（网络）Git 操作的执行结果，附带完整原始输出供 UI 展开详情
class GitRemoteCommandResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;

  /// 命令是否因用户取消而中止
  final bool cancelled;

  const GitRemoteCommandResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.cancelled = false,
  });

  factory GitRemoteCommandResult.error(String message, {int exitCode = -1}) {
    return GitRemoteCommandResult(
      success: false,
      exitCode: exitCode,
      stdout: '',
      stderr: message,
    );
  }

  factory GitRemoteCommandResult.cancelled() => const GitRemoteCommandResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: '',
        cancelled: true,
      );

  /// 合并后的输出，供错误映射使用
  String get combinedOutput => '$stderr\n$stdout';
}

/// 需要实时输出回调与取消能力的命令执行器签名（可注入以便测试）
typedef GitStreamRunner = Future<ProcessResult?> Function({
  required String executable,
  required List<String> arguments,
  required String workspacePath,
  required String? containerWorkDir,
  void Function(String chunk)? onOutput,
  HeadlessCancelToken? cancelToken,
  Duration timeout,
});

/// Git 核心服务层（单例模式，封装底层命令行交互与文件系统快速探测）
class GitService {
  static final GitService instance = GitService._internal();
  GitService._internal();

  /// 允许在测试环境下自定义或注入命令处理器
  @visibleForTesting
  Future<ProcessResult> Function(String executable, List<String> arguments, {String? workingDirectory})?
      processRunner;

  /// 允许在测试环境下注入云端命令的流式执行器（跳过真实 PRoot 容器）
  @visibleForTesting
  GitStreamRunner? streamRunner;

  /// 允许在测试环境下覆写宿主路径 → 容器内路径的映射
  @visibleForTesting
  String Function(String hostPath)? containerPathMapper;

  /// 自定义 Git 可执行程序路径（默认从系统 PATH 查找 'git'）
  String gitExecutable = 'git';

  /// 缓存的 Git 环境可用状态
  GitEnvironmentStatus? _cachedEnvStatus;

  /// 清除 Git 运行环境检测缓存（在容器重置、重装或安装 Git 后调用）
  void invalidateEnvStatus() {
    _cachedEnvStatus = null;
  }

  /// 重置测试环境状态与进程注入
  void resetForTesting() {
    processRunner = null;
    streamRunner = null;
    containerPathMapper = null;
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
      final success = await engine.installPackage(
        'apt-get update && apt-get install -y git openssh-client',
        onOutput: onProgress,
      );
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

  // ==========================================================================
  //  云端（远程仓库）操作
  //
  //  设计要点：
  //  1. 容器启动配置使用 `/usr/bin/env -i` 完全隔离环境变量，因此从 Dart 侧
  //     传给 proot 进程的 environment 无法抵达容器内的 git。所有环境相关设置
  //     （GIT_TERMINAL_PROMPT / GIT_SSH_COMMAND 等）必须内联进 guest 命令串。
  //  2. 由于没有 PTY，git 需要凭据时会尝试读取终端并长时间挂起。
  //     GIT_TERMINAL_PROMPT=0 让其在缺少凭据时立即失败并给出可识别的报错。
  //  3. 非 TTY 下 git 默认关闭进度输出，网络命令必须显式传 --progress。
  // ==========================================================================

  /// 容器内 SSH 客户端参数：仅使用指定私钥、禁用交互，并自动接受首次出现的主机指纹
  ///
  /// `BatchMode=yes` 保证密钥不被接受时立即失败而不是挂起等待密码输入；
  /// `StrictHostKeyChecking=accept-new` 避免首次推送必然撞上 "Host key verification failed"。
  static const String containerSshCommand =
      'ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes '
      '-o IdentitiesOnly=yes -o ConnectTimeout=20 -i /root/.ssh/id_ed25519';

  /// 宿主仓库路径 → 容器内路径（工程根挂载到 /workspace）
  ///
  /// 直接跑在宿主平台的测试环境里没有 /workspace 这层映射，此时原样返回。
  @visibleForTesting
  String mapToContainerPath(String repoPath, String? rootPath) {
    if (containerPathMapper != null) {
      return containerPathMapper!(repoPath);
    }
    if (!Platform.isAndroid || rootPath == null || rootPath.trim().isEmpty) {
      return repoPath;
    }
    final normalizedRepo = p.normalize(repoPath);
    final normalizedRoot = p.normalize(rootPath);
    if (normalizedRepo == normalizedRoot) return '/workspace';
    // 嵌套仓库（子模块）→ /workspace/<相对路径>
    if (p.isWithin(normalizedRoot, normalizedRepo)) {
      final relative = p.relative(normalizedRepo, from: normalizedRoot);
      return '/workspace/$relative'.replaceAll(r'\', '/');
    }
    return '/workspace';
  }

  /// 组装容器内实际执行的 git 命令串：注入禁交互环境与 SSH 参数
  @visibleForTesting
  String buildGuestGitCommand(List<String> args) {
    final body = args.map(_escapeShellArg).join(' ');
    // 注意：GIT_SSH_COMMAND 必须带引号，避免其中的 ssh 参数被当作独立命令
    return 'GIT_TERMINAL_PROMPT=0 '
        'GIT_SSH_COMMAND="$containerSshCommand" '
        'git -c safe.directory=* -c credential.interactive=false -c core.askPass= $body';
  }

  /// 从 git 进度输出行解析阶段名与百分比
  ///
  /// 形如 `Receiving objects:  45% (450/1000), 1.2 MiB | 300 KiB/s`。
  /// 无法解析出百分比时返回 null，由 UI 展示不确定态进度。
  @visibleForTesting
  int? parseProgressPercent(String line) {
    final match = RegExp(r'(\d{1,3})%').firstMatch(line);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null) return null;
    return value.clamp(0, 100);
  }

  /// 判断输出行是否为值得展示的进度行
  @visibleForTesting
  bool isProgressLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('remote:')) return false;
    // 形如 `Receiving objects: ...` / `Writing objects: ...` / `Counting objects: ...`
    if (RegExp(r'^[A-Z][A-Za-z ]+:\s').hasMatch(t)) return true;
    if (t.startsWith('From ') || t.startsWith('To ')) return true;
    if (t.contains('->') && (t.contains('new branch') || t.contains('new tag'))) return true;
    return false;
  }

  /// 云端网络命令的默认超时
  ///
  /// 大仓库（如 llama.cpp 这类上万提交的项目）在 Android + PRoot 下抓取/推送
  /// 的 packfile 很容易超过 5 分钟；超时会被 sigkill，表现为"进度走到一半就没了"。
  /// 因此放宽到 15 分钟 —— UI 侧始终提供取消按钮，用户不必干等。
  static const Duration remoteNetworkTimeout = Duration(minutes: 15);

  /// 执行一条云端 git 命令（带进度回调与取消能力）
  Future<GitRemoteCommandResult> runRemoteGitCommand(
    String repoPath,
    List<String> args, {
    String? rootPath,
    Duration timeout = remoteNetworkTimeout,
    void Function(GitOperationProgress progress)? onProgress,
    HeadlessCancelToken? cancelToken,
  }) async {
    final env = await checkGitInstalled();
    if (!env.isInstalled) {
      return GitRemoteCommandResult.error(
        env.errorMessage ?? '未检测到 Git 命令行工具，请先在内置容器中安装 git',
      );
    }

    final containerCmd = buildGuestGitCommand(args);
    final containerWorkDir = mapToContainerPath(repoPath, rootPath);

    void emit(String chunk) {
      if (onProgress == null) return;
      for (final line in chunk.split('\n')) {
        if (!isProgressLine(line)) continue;
        onProgress(GitOperationProgress(
          phase: _phaseOf(args),
          percent: parseProgressPercent(line),
          raw: line.trim(),
        ));
      }
    }

    try {
      final ProcessResult? res;
      if (streamRunner != null) {
        res = await streamRunner!(
          executable: containerCmd,
          arguments: const [],
          workspacePath: repoPath,
          containerWorkDir: containerWorkDir,
          onOutput: emit,
          cancelToken: cancelToken,
          timeout: timeout,
        );
      } else {
        final runner = _defaultStreamRunner;
        res = await runner(
          executable: containerCmd,
          arguments: const [],
          workspacePath: repoPath,
          containerWorkDir: containerWorkDir,
          onOutput: emit,
          cancelToken: cancelToken,
          timeout: timeout,
        );
      }

      // 取消：可能是取消令牌在流程中被触发，也可能是命令自身因超时被杀
      if (cancelToken?.isCancelled ?? false) {
        return GitRemoteCommandResult.cancelled();
      }
      if (res == null) {
        return GitRemoteCommandResult.error('云端命令执行失败：容器引擎无响应');
      }

      return GitRemoteCommandResult(
        success: res.exitCode == 0,
        exitCode: res.exitCode,
        stdout: res.stdout.toString(),
        stderr: res.stderr.toString(),
      );
    } catch (e) {
      return GitRemoteCommandResult.error('云端命令异常: $e');
    }
  }

  /// 从参数推断当前操作阶段（驱动 UI 文案）
  String _phaseOf(List<String> args) {
    if (args.isEmpty) return 'git';
    if (args.contains('fetch')) return 'fetch';
    if (args.contains('pull')) return 'pull';
    if (args.contains('push')) return 'push';
    if (args.contains('clone')) return 'clone';
    if (args.contains('ls-remote')) return 'auth';
    if (args.contains('remote')) return 'remote';
    return args.first;
  }

  /// 默认流式执行器：把命令投递到 PRoot 容器（或宿主回退）执行
  ///
  /// 注意 [arguments] 为空，最终命令已内联在 [executable] 中，
  /// 因为 runHeadlessCommand 只接受单一命令串。
  Future<ProcessResult?> _defaultStreamRunnerImpl({
    required String executable,
    required List<String> arguments,
    required String workspacePath,
    required String? containerWorkDir,
    void Function(String chunk)? onOutput,
    HeadlessCancelToken? cancelToken,
    Duration timeout = remoteNetworkTimeout,
  }) async {
    final fullCommand = arguments.isEmpty
        ? executable
        : '$executable ${arguments.map(_escapeShellArg).join(' ')}';

    if (Platform.isAndroid) {
      final engine = InternalEngineService.instance;
      if (await engine.isEngineInstalled()) {
        final rootfs = await engine.getRootfsDir();
        final res = await DistroManager().runHeadlessCommand(
          systemName: DistroRepository.defaultSystemName,
          customRootDir: rootfs,
          workspacePath: workspacePath,
          command: fullCommand,
          timeout: timeout,
          cancelToken: cancelToken,
          onStdout: onOutput,
        );
        if (res != null) return res;
      }
    }

    // 宿主回退（桌面调试场景），环境变量已内联在命令串前缀中
    if (cancelToken != null) {
      return DistroManager().runHeadlessCommand(
        systemName: 'host',
        command: fullCommand,
        timeout: timeout,
        cancelToken: cancelToken,
        onStdout: onOutput,
      );
    }
    return Process.run(
      Platform.isWindows ? 'cmd' : '/bin/sh',
      Platform.isWindows ? ['/c', fullCommand] : ['-c', fullCommand],
      workingDirectory: workspacePath,
    );
  }

  /// 默认流式执行器实例（延迟绑定，便于测试替换）
  GitStreamRunner get _defaultStreamRunner => _defaultStreamRunnerImpl;

  // ------------------------------ 远端仓库管理 ------------------------------

  /// 列出所有远端仓库 (`git remote -v`)
  Future<List<GitRemote>> getRemotes(String repoPath) async {
    final res = await runGitCommand(['remote', '-v'], workingDir: repoPath);
    if (!res.success) return [];
    return parseRemotes(res.stdout);
  }

  /// 解析 `git remote -v` 输出
  @visibleForTesting
  List<GitRemote> parseRemotes(String stdout) {
    // 保持出现顺序：fetch 行确立顺序，push 行补充 pushUrl
    final order = <String>[];
    final fetchUrls = <String, String>{};
    final pushUrls = <String, String>{};

    for (final line in LineSplitter.split(stdout)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 形如 `origin\thttps://github.com/a/b.git (fetch)`
      final match = RegExp(r'^(\S+)\s+(\S+)\s+\((fetch|push)\)$').firstMatch(trimmed);
      if (match == null) continue;
      final name = match.group(1)!;
      final url = match.group(2)!;
      final kind = match.group(3)!;
      if (!order.contains(name)) order.add(name);
      if (kind == 'fetch') {
        fetchUrls[name] = url;
      } else {
        pushUrls[name] = url;
      }
    }

    final remotes = <GitRemote>[];
    for (final name in order) {
      final fetchUrl = fetchUrls[name] ?? pushUrls[name];
      if (fetchUrl == null) continue;
      final pushUrl = pushUrls[name];
      remotes.add(GitRemote(
        name: name,
        fetchUrl: fetchUrl,
        // 仅在与 fetch 地址不同时才保留，避免 UI 重复展示
        pushUrl: (pushUrl != null && pushUrl != fetchUrl) ? pushUrl : null,
      ));
    }
    return remotes;
  }

  /// 添加远端仓库 (`git remote add <name> <url>`)
  Future<GitCommandResult> addRemote(
    String repoPath,
    String name,
    String url, {
    String? pushUrl,
  }) async {
    final cleanName = name.trim();
    final cleanUrl = url.trim();
    if (cleanName.isEmpty) return GitCommandResult.error('远端名称不能为空');
    if (cleanUrl.isEmpty) return GitCommandResult.error('远端地址不能为空');

    final res = await runGitCommand(
      ['remote', 'add', cleanName, cleanUrl],
      workingDir: repoPath,
    );
    if (!res.success) return res;

    if (pushUrl != null && pushUrl.trim().isNotEmpty && pushUrl.trim() != cleanUrl) {
      return runGitCommand(
        ['remote', 'set-url', '--push', cleanName, pushUrl.trim()],
        workingDir: repoPath,
      );
    }
    return res;
  }

  /// 移除远端仓库 (`git remote remove <name>`)
  Future<GitCommandResult> removeRemote(String repoPath, String name) async {
    return runGitCommand(['remote', 'remove', name.trim()], workingDir: repoPath);
  }

  /// 重命名远端仓库 (`git remote rename <old> <new>`)
  Future<GitCommandResult> renameRemote(
    String repoPath,
    String oldName,
    String newName,
  ) async {
    final cleanNew = newName.trim();
    if (cleanNew.isEmpty) return GitCommandResult.error('新的远端名称不能为空');
    if (oldName.trim() == cleanNew) {
      return GitCommandResult.error('新名称与原名相同');
    }
    return runGitCommand(
      ['remote', 'rename', oldName.trim(), cleanNew],
      workingDir: repoPath,
    );
  }

  /// 修改远端地址 (`git remote set-url [--push] <name> <url>`)
  Future<GitCommandResult> setRemoteUrl(
    String repoPath,
    String name,
    String url, {
    bool push = false,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return GitCommandResult.error('远端地址不能为空');
    final args = ['remote', 'set-url'];
    if (push) args.add('--push');
    args.addAll([name.trim(), cleanUrl]);
    return runGitCommand(args, workingDir: repoPath);
  }

  /// 清理远端已删除的追踪分支 (`git remote prune <name>`)
  Future<GitCommandResult> pruneRemote(String repoPath, String name) async {
    return runGitCommand(['remote', 'prune', name.trim()], workingDir: repoPath);
  }

  // ------------------------------ 网络同步操作 ------------------------------

  /// 抓取远端更新 (`git fetch --progress [--prune] <remote>`)
  ///
  /// 默认开启 `--prune`，与 VS Code / GitHub Desktop 行为一致，避免远端已删除的
  /// 分支长期残留。不传 `--tags`，避免意外拉入大量标签。
  Future<GitRemoteCommandResult> fetch(
    String repoPath, {
    String? rootPath,
    String? remote,
    bool prune = true,
    void Function(GitOperationProgress progress)? onProgress,
    HeadlessCancelToken? cancelToken,
    Duration timeout = remoteNetworkTimeout,
  }) async {
    final args = ['fetch', '--progress'];
    if (prune) args.add('--prune');
    if (remote != null && remote.trim().isNotEmpty) args.add(remote.trim());
    return runRemoteGitCommand(
      repoPath,
      args,
      rootPath: rootPath,
      timeout: timeout,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// 拉取并变基 (`git pull --progress --rebase <remote> <branch>`)
  ///
  /// 采用 rebase 以保持历史线性。调用方需在外层处理未提交改动（提交或贮藏）。
  Future<GitRemoteCommandResult> pullRebase(
    String repoPath, {
    String? rootPath,
    String? remote,
    String? branch,
    bool autostash = false,
    void Function(GitOperationProgress progress)? onProgress,
    HeadlessCancelToken? cancelToken,
    Duration timeout = remoteNetworkTimeout,
  }) async {
    final args = ['pull', '--progress', '--rebase'];
    if (autostash) args.add('--autostash');
    if (remote != null && remote.trim().isNotEmpty) args.add(remote.trim());
    if (branch != null && branch.trim().isNotEmpty) args.add(branch.trim());
    return runRemoteGitCommand(
      repoPath,
      args,
      rootPath: rootPath,
      timeout: timeout,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// 推送到远端 (`git push --progress [--set-upstream] [--force-with-lease] ...`)
  ///
  /// 强制推送一律使用 `--force-with-lease`：当远端已被他人更新时会被拒绝，
  /// 而不是静默覆盖别人的提交。
  Future<GitRemoteCommandResult> push(
    String repoPath, {
    String? rootPath,
    String? remote,
    String? branch,
    bool setUpstream = false,
    bool forceWithLease = false,
    void Function(GitOperationProgress progress)? onProgress,
    HeadlessCancelToken? cancelToken,
    Duration timeout = remoteNetworkTimeout,
  }) async {
    final args = ['push', '--progress'];
    if (forceWithLease) args.add('--force-with-lease');
    if (setUpstream) args.add('--set-upstream');
    if (remote != null && remote.trim().isNotEmpty) args.add(remote.trim());
    if (branch != null && branch.trim().isNotEmpty) args.add(branch.trim());
    return runRemoteGitCommand(
      repoPath,
      args,
      rootPath: rootPath,
      timeout: timeout,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// 放弃进行中的 rebase (`git rebase --abort`)
  ///
  /// 冲突后必须给用户一条明确的退出路径，否则仓库会卡在 rebase 中间状态。
  Future<GitCommandResult> abortRebase(String repoPath) async {
    return runGitCommand(['rebase', '--abort'], workingDir: repoPath);
  }

  /// 是否正处于 rebase 中间状态（存在 .git/rebase-merge 或 .git/rebase-apply）
  bool isRebaseInProgress(String repoPath) {
    try {
      return Directory(p.join(repoPath, '.git', 'rebase-merge')).existsSync() ||
          Directory(p.join(repoPath, '.git', 'rebase-apply')).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 验证远端连通性与认证是否可用 (`git ls-remote <url> HEAD`)
  /// 比"推送失败后再猜错误码"友好得多，用于账号管理页的自检按钮。
  Future<GitRemoteCommandResult> checkRemoteAuth(
    String repoPath,
    String url, {
    String? rootPath,
    HeadlessCancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      return GitRemoteCommandResult.error('远端地址不能为空');
    }
    return runRemoteGitCommand(
      repoPath,
      ['ls-remote', '--exit-code', cleanUrl, 'HEAD'],
      rootPath: rootPath,
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  // ---------------------------- 远程目标解析 ----------------------------

  /// 读取某个配置键的值；未设置时返回 null
  ///
  /// `git config <key>` 在键不存在时以非 0 退出，这是正常情况而非错误。
  Future<String?> getConfigValue(String repoPath, String key) async {
    final res = await runGitCommand(['config', key], workingDir: repoPath);
    if (!res.success) return null;
    final value = res.stdout.trim();
    return value.isEmpty ? null : value;
  }

  /// 读取某分支的推送远程 (`branch.<name>.pushRemote`)
  Future<String?> getBranchPushRemote(String repoPath, String branch) async {
    if (branch.trim().isEmpty) return null;
    return getConfigValue(repoPath, 'branch.${branch.trim()}.pushRemote');
  }

  /// 读取全局推送默认远程 (`remote.pushDefault`)
  Future<String?> getRemotePushDefault(String repoPath) async {
    return getConfigValue(repoPath, 'remote.pushDefault');
  }

  /// 读取某分支的抓取/上游远程 (`branch.<name>.remote`)
  Future<String?> getBranchRemote(String repoPath, String branch) async {
    if (branch.trim().isEmpty) return null;
    return getConfigValue(repoPath, 'branch.${branch.trim()}.remote');
  }

  // ---------------------------- 远端分支 ----------------------------

  /// 列出所有远端追踪分支 (`git branch -r`)
  ///
  /// `git fetch` 之后如果界面上看不到远端分支，用户会以为"抓取没生效"。
  /// 这里连同「已被哪个本地分支检出」一起解析出来，供分支选择器分区展示
  /// 并支持基于远端分支创建本地分支。
  ///
  /// 使用固定分隔符 `|` 而非制表符：制表符与 `%(HEAD)` 的前导空格混在一起后
  /// 无法可靠切列（`' *\tname'` 里到底有几个前导空格由 git 决定）。
  Future<List<GitRemoteBranch>> getRemoteBranches(String repoPath) async {
    final res = await runGitCommand(
      ['branch', '-r', '--format=%(HEAD)|%(refname:short)'],
      workingDir: repoPath,
    );
    if (!res.success) return [];
    return parseRemoteBranches(res.stdout);
  }

  /// 解析 `git branch -r --format=%(HEAD)|%(refname:short)` 输出
  @visibleForTesting
  List<GitRemoteBranch> parseRemoteBranches(String stdout) {
    final branches = <GitRemoteBranch>[];
    for (final rawLine in LineSplitter.split(stdout)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // 第一段是 HEAD 标记（'*' 表示已被某个本地分支检出）
      final marker = line.split('|').first.trim();
      final name = _lastRefSegment(line);
      if (name.isEmpty) continue;
      // 跳过 `origin/HEAD -> origin/main` 这类符号引用行
      if (name.endsWith('/HEAD')) continue;
      // `refs/remotes/origin/main` 这种完整引用先去掉 refs/remotes/ 前缀
      final cleaned = name.startsWith('refs/remotes/')
          ? name.substring('refs/remotes/'.length)
          : name;

      final slash = cleaned.indexOf('/');
      if (slash <= 0) continue;

      branches.add(GitRemoteBranch(
        name: cleaned,
        remoteName: cleaned.substring(0, slash),
        branchName: cleaned.substring(slash + 1),
        isCheckedOut: marker.startsWith('*'),
      ));
    }
    return branches;
  }

  /// 取 `%(HEAD)|%(refname:short)` 一行中最靠右的一段作为引用名
  ///
  /// 兼容 `(HEAD detached at x)`、`origin/HEAD -> origin/main` 这类
  /// 左侧带额外说明的输出。
  String _lastRefSegment(String line) {
    final segments = line
        .split(RegExp(r'[|\t]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return '';
    return segments.last;
  }

  /// 基于远端分支创建并检出一个同名本地分支
  ///
  /// 若同名本地分支已存在则直接切换过去（`git checkout <branch>` 会自动
  /// 建立追踪关系），否则用 `git checkout -b <branch> <remote>/<branch>`
  /// 以远端分支为起点创建。
  Future<GitCommandResult> checkoutRemoteBranch(
    String repoPath,
    String remoteName,
    String branchName, {
    bool forceCreate = false,
  }) async {
    final local = branchName.trim();
    if (local.isEmpty) return GitCommandResult.error('分支名称不能为空');

    if (!forceCreate) {
      final existing = await getLocalBranches(repoPath);
      if (existing.contains(local)) {
        return runGitCommand(['checkout', local], workingDir: repoPath);
      }
    }
    return runGitCommand(
      ['checkout', '-b', local, '--track', '${remoteName.trim()}/$local'],
      workingDir: repoPath,
    );
  }

  // ---------------------------- 仓库自检 ----------------------------

  /// 仓库完整性自检 (`git fsck --no-progress`)
  ///
  /// 目的：`.git/objects` 中的对象在 PRoot 容器重建等场景下可能丢失，
  /// 若不做检查，用户只会在某次提交时撞上 "invalid object ... building trees"，
  /// 且完全不知道原因。这里把问题提前暴露出来。
  ///
  /// 只读，不修改任何内容（不自动 `fsck --lost-found`，避免留下 .git/lost-found）。
  Future<GitFsckReport> fsck(
    String repoPath, {
    Duration timeout = const Duration(minutes: 2),
    HeadlessCancelToken? cancelToken,
  }) async {
    final res = await runGitCommand(
      ['fsck', '--no-progress'],
      workingDir: repoPath,
      timeout: timeout,
    );
    // git fsck 发现问题时以非 0 退出，但输出仍是有效报告，因此照常解析
    return parseFsckReport(res.stdout, res.stderr, exitCode: res.exitCode);
  }

  /// 解析 `git fsck` 输出
  @visibleForTesting
  GitFsckReport parseFsckReport(
    String stdout,
    String stderr, {
    required int exitCode,
  }) {
    final missing = <String>[];
    final corrupt = <String>[];
    final dangling = <String>[];

    /// 例行输出不是问题，绝不能被归类为损坏 —— 否则干净的仓库会被告知"已损坏"
    bool isNoise(String t) {
      if (t.startsWith('Checking ') || t.startsWith('checking ')) return true;
      if (t.startsWith('notice:')) return true;
      if (t.startsWith('fatal:')) return true;
      // 进度行 `Checking object directories: 100% (256/256), done.`
      if (t.contains('%') && t.endsWith('done.')) return true;
      return false;
    }

    void classify(String line) {
      final t = line.trim();
      if (t.isEmpty) return;
      if (isNoise(t)) return;

      // 只有明确的 missing/broken/无法读取才算对象库受损
      if (t.startsWith('missing ') ||
          t.startsWith('broken link') ||
          t.startsWith('unable to read') ||
          t.startsWith('invalid ')) {
        missing.add(t);
        return;
      }
      if (t.startsWith('error:')) {
        corrupt.add(t);
        return;
      }
      if (t.startsWith('dangling ') || t.startsWith('unreachable ')) {
        dangling.add(t);
        return;
      }
      // `broken link from ...` 的续行形如 `              to    blob <sha>`，
      // 属于同一个问题的组成部分，归入 missing 而不是"无法归类"
      if (t.startsWith('to ')) {
        missing.add(t);
        return;
      }
      corrupt.add(t);
    }

    for (final line in LineSplitter.split(stdout)) {
      classify(line);
    }
    for (final line in LineSplitter.split(stderr)) {
      classify(line);
    }

    return GitFsckReport(
      // 有 missing/corrupt 即视为对象库受损；dangling 只是提示，不影响使用
      isHealthy: missing.isEmpty && corrupt.isEmpty && exitCode == 0,
      hasObjectLoss: missing.isNotEmpty || corrupt.isNotEmpty,
      missing: List.unmodifiable(missing),
      corrupt: List.unmodifiable(corrupt),
      dangling: List.unmodifiable(dangling),
      exitCode: exitCode,
    );
  }

  // ---------------------------- 克隆 ----------------------------

  /// 克隆远端仓库到工作区内的某个子目录
  ///
  /// 实现说明：容器里宿主工程目录被挂载为 `/workspace`，且不支持额外挂载点，
  /// 因此把克隆父目录（项目根）作为 workspacePath，在容器内克隆到
  /// `/workspace/<目录名>` —— 其写回宿主的正是期望位置。
  Future<GitRemoteCommandResult> clone(
    String parentDir,
    String url,
    String targetDirName, {
    String? rootPath,
    String? branch,
    int? depth,
    void Function(GitOperationProgress progress)? onProgress,
    HeadlessCancelToken? cancelToken,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final cleanUrl = url.trim();
    final cleanName = targetDirName.trim();
    if (cleanUrl.isEmpty) {
      return GitRemoteCommandResult.error('仓库地址不能为空');
    }
    if (cleanName.isEmpty) {
      return GitRemoteCommandResult.error('目标目录名不能为空');
    }

    final args = ['clone', '--progress'];
    if (depth != null && depth > 0) args.addAll(['--depth', '$depth']);
    if (branch != null && branch.trim().isNotEmpty) {
      args.addAll(['--branch', branch.trim()]);
    }
    args.addAll([cleanUrl, cleanName]);

    return runRemoteGitCommand(
      parentDir,
      args,
      rootPath: rootPath,
      timeout: timeout,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  // ---------------------------- 上游追踪与领先/落后 ----------------------------

  /// 读取当前分支的上游追踪状态 (`git status -sb --porcelain=v2 --branch`)
  ///
  /// 一次进程调用同时拿到分支名、上游、ahead/behind，避免为领先/落后单独开进程。
  Future<GitBranchTracking> getBranchTracking(String repoPath) async {
    final res = await runGitCommand(
      ['status', '-sb', '--porcelain=v2', '--branch'],
      workingDir: repoPath,
    );
    if (!res.success) {
      final branch = await getCurrentBranch(repoPath);
      return GitBranchTracking.noUpstream(branch);
    }
    return parseBranchTracking(res.stdout, fallbackBranch: null);
  }

  /// 解析 `git status --porcelain=v2 --branch` 输出中的追踪信息
  ///
  /// 兼容两种格式：
  /// - porcelain v2: `# branch.head main` / `# branch.upstream origin/main` / `# branch.ab +1 -2`
  /// - porcelain v1 (`-sb` 简写): `## main...origin/main [ahead 1, behind 2]` / `## main...origin/main [gone]`
  @visibleForTesting
  GitBranchTracking parseBranchTracking(String stdout, {String? fallbackBranch}) {
    String? branch = fallbackBranch;
    String? upstream;
    int ahead = 0;
    int behind = 0;
    bool gone = false;

    for (final line in LineSplitter.split(stdout)) {
      final t = line.trim();
      if (t.isEmpty) continue;

      if (t.startsWith('# branch.head ')) {
        final value = t.substring('# branch.head '.length).trim();
        // detached HEAD 会返回 (detached)
        if (value.isNotEmpty && value != '(detached)') branch = value;
        continue;
      }
      if (t.startsWith('# branch.upstream ')) {
        final value = t.substring('# branch.upstream '.length).trim();
        if (value.isNotEmpty) upstream = value;
        continue;
      }
      if (t.startsWith('# branch.ab ')) {
        final m = RegExp(r'\+(\d+)\s+-(\d+)').firstMatch(t);
        if (m != null) {
          ahead = int.tryParse(m.group(1)!) ?? 0;
          behind = int.tryParse(m.group(2)!) ?? 0;
        }
        continue;
      }

      // 兼容 porcelain v1 的 `## ...` 行
      if (t.startsWith('## ')) {
        final body = t.substring(3).trim();
        // 去掉 [ahead 1, behind 2] / [gone] 尾巴
        final bracketIdx = body.indexOf(' [');
        final namePart = bracketIdx >= 0 ? body.substring(0, bracketIdx) : body;
        final bracketPart = bracketIdx >= 0 ? body.substring(bracketIdx + 1) : '';

        if (namePart.contains('...')) {
          final parts = namePart.split('...');
          branch ??= parts[0].trim();
          final up = parts.length > 1 ? parts[1].trim() : '';
          if (up.isNotEmpty) upstream = up;
        } else {
          branch ??= namePart.trim();
        }

        if (bracketPart.contains('gone')) {
          gone = true;
        }
        final m = RegExp(r'ahead (\d+)').firstMatch(bracketPart);
        if (m != null) ahead = int.tryParse(m.group(1)!) ?? 0;
        final mb = RegExp(r'behind (\d+)').firstMatch(bracketPart);
        if (mb != null) behind = int.tryParse(mb.group(1)!) ?? 0;
        continue;
      }
    }

    return GitBranchTracking(
      branch: branch ?? 'main',
      upstream: upstream,
      ahead: ahead,
      behind: behind,
      isGone: gone,
    );
  }
}
