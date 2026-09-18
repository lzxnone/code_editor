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

/// Git 仓库信息（支持根仓库及子模块/嵌套仓库）
class GitRepositoryInfo {
  final String rootPath;
  final String name;
  final bool isRoot;
  final String? currentBranch;

  const GitRepositoryInfo({
    required this.rootPath,
    required this.name,
    this.isRoot = false,
    this.currentBranch,
  });

  GitRepositoryInfo copyWith({
    String? rootPath,
    String? name,
    bool? isRoot,
    String? currentBranch,
  }) {
    return GitRepositoryInfo(
      rootPath: rootPath ?? this.rootPath,
      name: name ?? this.name,
      isRoot: isRoot ?? this.isRoot,
      currentBranch: currentBranch ?? this.currentBranch,
    );
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
