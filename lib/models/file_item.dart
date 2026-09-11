import 'package:path/path.dart' as p;

class FileItem {
  final String fullPath;
  final String name;
  final String? relativePath;
  final bool isDirectory;
  List<FileItem> children;
  final int depth;
  bool isOpen;

  FileItem({
    required String path,
    String? name,
    this.relativePath,
    this.isDirectory = false,
    List<FileItem>? children,
    this.depth = 0,
    this.isOpen = false,
  })  : fullPath = p.normalize(path),
        name = name ?? p.basename(path),
        children = children ?? [];

  /// 完整物理绝对路径别名（完全兼容旧代码）
  String get path => fullPath;

  /// 文件扩展名（含前导点，如 '.dart'、'.json'；文件夹或无扩展名返回 ''）
  String get extension => isDirectory ? '' : p.extension(fullPath).toLowerCase();

  /// 不带扩展名的文件名（如 'main'）
  String get nameWithoutExtension =>
      isDirectory ? name : p.basenameWithoutExtension(fullPath);

  /// 优先展示相对路径；若无相对路径则展示纯文件名
  String get displayPath => relativePath ?? name;

  /// 获取相对于指定 rootPath 的相对路径（优先使用已有相对路径，跨盘或无项目安全回退）
  String getRelativePath([String? fromRoot]) {
    if(relativePath != null && (fromRoot == null || fromRoot.isEmpty)) {
      return relativePath!;
    }
    final root = fromRoot;
    if(root == null || root.trim().isEmpty) return name;
    try {
      return p.relative(fullPath, from: root);
    }catch (_) {
      return fullPath;
    }
  }
}
