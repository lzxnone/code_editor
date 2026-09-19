import 'package:path/path.dart' as p;

/// Git 文件状态类别
enum GitFileStatusType {
  untracked, // 未跟踪 (??)
  modified,  // 已修改 ( M / M )
  added,     // 新增 (A )
  deleted,   // 已删除 ( D / D )
  renamed,   // 重命名 (R )
  copied,    // 复制 (C )
  typeChange,// 类型变更 (T )
  unmerged,  // 冲突未合并 (UU / AA / DD 等)
  ignored,   // 忽略 (!!)
  unknown,   // 未知
}

/// Git 文件变更条目
class GitFileStatus {
  final String path;
  final String relativePath;
  final GitFileStatusType statusType;
  final bool isStaged;
  final String? originalPath; // 用于重命名/复制的源路径

  const GitFileStatus({
    required this.path,
    required this.relativePath,
    required this.statusType,
    this.isStaged = false,
    this.originalPath,
  });

  String get fileName => p.basename(relativePath);

  String get directoryPath {
    final dir = p.dirname(relativePath);
    return dir == '.' ? '' : dir;
  }
}

/// 推送目标远程的解析来源
///
/// 用于在 UI 上解释「为什么推送会发到这个远程」，避免多远程或 fork 场景下
/// 用户对推送去向了哪个仓库产生误解。
enum GitRemoteSource {
  /// 无可用远程
  none,

  /// 分支级配置 `branch.<name>.pushRemote`
  pushRemote,

  /// 仓库级配置 `remote.pushDefault`
  pushDefault,

  /// 当前分支的上游远程（`git status` 的 branch.upstream）
  upstream,

  /// 分支配置 `branch.<name>.remote`（尚未建立上游追踪时）
  branchRemote,

  /// 兜底：优先名为 origin 的远程，否则取列表第一个
  fallback,

  /// 用户在本会话中手动指定（优先级最高，不落盘）
  manualOverride,
}

/// 处于中断状态的 Git 操作（决定「继续」到底指什么）
enum GitPendingOperation {
  none,
  rebase,
  merge,
  cherryPick,
  revert,
}

/// 冲突类型（对应 `git status --porcelain` 的 XY 两位状态组合）
enum GitConflictType {
  /// UU —— 双方都修改了同一文件的同一区域，最常见
  bothModified,

  /// AA —— 双方都新增了同一文件
  bothAdded,

  /// DU —— 对方删除、我们修改
  deletedByUs,

  /// UD —— 我们删除、对方修改
  deletedByThem,

  /// AU —— 我们新增、对方已存在
  addedByUs,

  /// UA —— 对方新增、我们已存在
  addedByThem,

  /// DD —— 双方都删除（少见）
  bothDeleted,

  unknown,
}

/// 一个存在冲突的文件
class GitConflictedFile {
  final String relativePath;
  final String absolutePath;
  final GitConflictType type;

  /// 二进制文件无法用 `<<<<<<<` 标记表达，只能整文件选一边
  final bool isBinary;

  const GitConflictedFile({
    required this.relativePath,
    required this.absolutePath,
    required this.type,
    this.isBinary = false,
  });

  /// 是否可通过编辑文本标记来解决
  bool get canEditManually => !isBinary && type != GitConflictType.bothDeleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitConflictedFile &&
          runtimeType == other.runtimeType &&
          relativePath == other.relativePath &&
          type == other.type;

  @override
  int get hashCode => Object.hash(relativePath, type);

  @override
  String toString() => 'GitConflictedFile($relativePath, ${type.name})';
}

/// 冲突整体状态
class GitConflictState {
  final GitPendingOperation operation;
  final List<GitConflictedFile> files;

  const GitConflictState({
    required this.operation,
    this.files = const [],
  });

  static const GitConflictState idle = GitConflictState(
    operation: GitPendingOperation.none,
  );

  /// 是否有操作处于中断状态（未必有冲突文件：可能冲突已解决待继续）
  bool get isPending => operation != GitPendingOperation.none;

  /// 是否仍有未解决的文件
  bool get hasUnresolvedFiles => files.isNotEmpty;

  /// 冲突文件数
  int get conflictCount => files.length;

  /// 全部解决后才可以「继续」
  bool get canContinue => isPending && files.isEmpty;

  @override
  String toString() =>
      'GitConflictState(${operation.name}, files=${files.length})';
}

/// 远端追踪分支（`origin/feature-x` 这类）
///
/// 与 [GitRemote] 不同：后者是"远程仓库"（一个名字 + 地址），
/// 这里指的是远端仓库里的**某一条分支**在本地留下的追踪引用。
class GitRemoteBranch {
  /// 完整引用名（如 `origin/feature-x`）
  final String name;

  /// 所属远程仓库名（如 `origin`）
  final String remoteName;

  /// 远端分支名（如 `feature-x`）
  final String branchName;

  /// 是否已被某个本地分支检出（`git branch -r` 中的 `*`）
  final bool isCheckedOut;

  /// 同名的本地分支名 —— 即基于此远端分支创建后本地会叫这个名字
  String get localBranchName => branchName;

  const GitRemoteBranch({
    required this.name,
    required this.remoteName,
    required this.branchName,
    this.isCheckedOut = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRemoteBranch &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'GitRemoteBranch($name${isCheckedOut ? ", checkedOut" : ""})';
}

/// 仓库完整性自检结果（`git fsck`）
class GitFsckReport {
  /// 对象库是否健康（无缺失、无损坏且退出码为 0）
  final bool isHealthy;

  /// 是否存在对象丢失 —— 这是会导致提交失败（Error building trees）的严重问题
  final bool hasObjectLoss;

  /// 缺失/断链的对象描述
  final List<String> missing;

  /// 损坏的对象或无法归类的错误行
  final List<String> corrupt;

  /// 悬空对象（正常现象，不影响使用）
  final List<String> dangling;

  final int exitCode;

  const GitFsckReport({
    required this.isHealthy,
    required this.hasObjectLoss,
    this.missing = const [],
    this.corrupt = const [],
    this.dangling = const [],
    this.exitCode = 0,
  });

  /// 需要用户关注的问题总数（不含 dangling）
  int get problemCount => missing.length + corrupt.length;

  @override
  String toString() =>
      'GitFsckReport(healthy=$isHealthy, missing=${missing.length}, '
      'corrupt=${corrupt.length}, dangling=${dangling.length})';
}

/// Git 远程仓库描述符（name / fetchUrl / pushUrl）
class GitRemote {
  final String name;

  /// 拉取地址（`git remote -v` 的 fetch 行）
  final String fetchUrl;

  /// 推送地址：仅当与 [fetchUrl] 不同时才非空
  final String? pushUrl;

  const GitRemote({
    required this.name,
    required this.fetchUrl,
    this.pushUrl,
  });

  /// 推送实际使用的地址（未单独配置则回退到 fetch 地址）
  String get effectivePushUrl => pushUrl ?? fetchUrl;

  /// 是否为 SSH 协议地址（`git@host:path` 或 `ssh://`）
  bool get isSsh =>
      fetchUrl.startsWith('git@') ||
      fetchUrl.startsWith('ssh://') ||
      fetchUrl.startsWith('git+ssh://');

  /// 是否为 HTTPS 协议地址（走 ~/.git-credentials 免密）
  bool get isHttps =>
      fetchUrl.startsWith('https://') || fetchUrl.startsWith('http://');

  /// 提取主机名（供账号匹配与展示）
  String? get host {
    final uri = Uri.tryParse(fetchUrl);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    // 兼容 scp 风格 `git@github.com:owner/repo.git`
    final match = RegExp(r'^[^@]+@([^:]+):').firstMatch(fetchUrl);
    return match?.group(1);
  }

  /// 提取仓库路径（如 `owner/repo.git`）
  String? get repositoryPath {
    final uri = Uri.tryParse(fetchUrl);
    if (uri != null && uri.path.isNotEmpty) {
      return uri.path.replaceFirst(RegExp(r'^/+'), '');
    }
    final match = RegExp(r'^[^@]+@[^:]+:(.+)$').firstMatch(fetchUrl);
    return match?.group(1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRemote &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          fetchUrl == other.fetchUrl &&
          pushUrl == other.pushUrl;

  @override
  int get hashCode => Object.hash(name, fetchUrl, pushUrl);

  @override
  String toString() => 'GitRemote($name: $fetchUrl)';
}

/// 本地分支的上游追踪状态（ahead/behind 是云端功能 UI 的中枢信号）
class GitBranchTracking {
  /// 本地分支名
  final String branch;

  /// 上游引用（如 `origin/main`）；为 null 表示尚未设置上游
  final String? upstream;

  /// 领先上游的提交数
  final int ahead;

  /// 落后上游的提交数
  final int behind;

  /// 上游分支已被远端删除（`git status` 中的 `[gone]`）
  final bool isGone;

  const GitBranchTracking({
    required this.branch,
    this.upstream,
    this.ahead = 0,
    this.behind = 0,
    this.isGone = false,
  });

  /// 是否已设置上游追踪分支
  bool get hasUpstream => upstream != null && upstream!.isNotEmpty;

  /// 本地与远端均已产生新提交（需要先 pull 再 push）
  bool get isDiverged => ahead > 0 && behind > 0;

  /// 是否需要推送到远端
  bool get needsPush => hasUpstream && ahead > 0;

  /// 是否需要从远端拉取
  bool get needsPull => hasUpstream && behind > 0;

  /// 是否与上游完全同步
  bool get isUpToDate => hasUpstream && ahead == 0 && behind == 0;

  /// 上游对应的远程仓库名（如 `origin`）
  String? get remoteName {
    if (!hasUpstream) return null;
    final idx = upstream!.indexOf('/');
    return idx > 0 ? upstream!.substring(0, idx) : null;
  }

  /// 上游对应的分支名（如 `main`）
  String? get upstreamBranch {
    if (!hasUpstream) return null;
    final idx = upstream!.indexOf('/');
    return idx >= 0 && idx + 1 < upstream!.length ? upstream!.substring(idx + 1) : null;
  }

  /// 未设置上游时的初始状态
  factory GitBranchTracking.noUpstream(String branch) =>
      GitBranchTracking(branch: branch);

  @override
  String toString() =>
      'GitBranchTracking($branch -> ${upstream ?? "none"}, +$ahead/-$behind)';
}

/// 云端操作的实时进度（驱动面板内联进度条）
class GitOperationProgress {
  /// 操作类型标识：fetch / pull / push / clone
  final String phase;

  /// 0~100 的百分比；无法解析时为 null（UI 应展示不确定态进度条）
  final int? percent;

  /// 原始输出行，供"查看详情"展开
  final String raw;

  const GitOperationProgress({
    required this.phase,
    this.percent,
    this.raw = '',
  });

  @override
  String toString() => 'GitOperationProgress($phase, ${percent ?? "-"}%)';
}

/// Git 仓库信息（支持根仓库及子模块/嵌套仓库）
class GitRepositoryInfo {
  final String rootPath;
  final String name;
  final bool isRoot;
  final String? currentBranch;

  /// 已配置的远程仓库列表
  final List<GitRemote> remotes;

  /// 当前分支的上游追踪状态
  final GitBranchTracking? tracking;

  const GitRepositoryInfo({
    required this.rootPath,
    required this.name,
    this.isRoot = false,
    this.currentBranch,
    this.remotes = const [],
    this.tracking,
  });

  GitRepositoryInfo copyWith({
    String? rootPath,
    String? name,
    bool? isRoot,
    String? currentBranch,
    List<GitRemote>? remotes,
    GitBranchTracking? tracking,
  }) {
    return GitRepositoryInfo(
      rootPath: rootPath ?? this.rootPath,
      name: name ?? this.name,
      isRoot: isRoot ?? this.isRoot,
      currentBranch: currentBranch ?? this.currentBranch,
      remotes: remotes ?? this.remotes,
      tracking: tracking ?? this.tracking,
    );
  }

  /// 是否已配置任何远程仓库
  bool get hasRemote => remotes.isNotEmpty;

  /// 默认远程仓库（优先 origin，否则取第一个）
  GitRemote? get defaultRemote {
    if (remotes.isEmpty) return null;
    for (final r in remotes) {
      if (r.name == 'origin') return r;
    }
    return remotes.first;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRepositoryInfo &&
          runtimeType == other.runtimeType &&
          rootPath == other.rootPath;

  @override
  int get hashCode => rootPath.hashCode;
}

/// Git 命令行执行结果
class GitCommandResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;

  const GitCommandResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  factory GitCommandResult.error(String message, {int exitCode = -1}) {
    return GitCommandResult(
      success: false,
      exitCode: exitCode,
      stdout: '',
      stderr: message,
    );
  }
}

/// Git 提交记录与图表节点模型
class GitCommit {
  final String hash;
  final String shortHash;
  final List<String> parentHashes;
  final String authorName;
  final String authorEmail;
  final DateTime authorDate;
  final String relativeDate;
  final String subject;
  final List<String> refs; // e.g. ["HEAD -> main", "origin/main", "tag: v1.0.0"]

  /// 线性图表拓扑布局字段
  final int lane; // 列通道索引 (0, 1, 2...)
  final List<int> activeLanes; // 经过当前行的活跃通道列表
  final List<int> outgoingLanes; // 当前节点连接向父节点的通道列表

  const GitCommit({
    required this.hash,
    required this.shortHash,
    required this.parentHashes,
    required this.authorName,
    required this.authorEmail,
    required this.authorDate,
    required this.relativeDate,
    required this.subject,
    this.refs = const [],
    this.lane = 0,
    this.activeLanes = const [],
    this.outgoingLanes = const [],
  });

  bool get isHead => refs.any((r) => r.startsWith('HEAD'));

  GitCommit copyWith({
    String? hash,
    String? shortHash,
    List<String>? parentHashes,
    String? authorName,
    String? authorEmail,
    DateTime? authorDate,
    String? relativeDate,
    String? subject,
    List<String>? refs,
    int? lane,
    List<int>? activeLanes,
    List<int>? outgoingLanes,
  }) {
    return GitCommit(
      hash: hash ?? this.hash,
      shortHash: shortHash ?? this.shortHash,
      parentHashes: parentHashes ?? this.parentHashes,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      authorDate: authorDate ?? this.authorDate,
      relativeDate: relativeDate ?? this.relativeDate,
      subject: subject ?? this.subject,
      refs: refs ?? this.refs,
      lane: lane ?? this.lane,
      activeLanes: activeLanes ?? this.activeLanes,
      outgoingLanes: outgoingLanes ?? this.outgoingLanes,
    );
  }
}
