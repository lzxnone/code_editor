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
