import 'package:path/path.dart' as p;

class EditorTabItem {
  final String path;
  String content;
  String originalContent;
  bool isModified;
  bool isLoaded;
  double verticalScrollOffset;
  double horizontalScrollOffset;
  bool hasExternalConflict;
  bool isDeletedOnDisk;

  EditorTabItem({
    required this.path,
    this.content = '',
    this.originalContent = '',
    this.isModified = false,
    this.isLoaded = false,
    this.verticalScrollOffset = 0.0,
    this.horizontalScrollOffset = 0.0,
    this.hasExternalConflict = false,
    this.isDeletedOnDisk = false,
  });

  String get name => p.basename(path);

  /// 计算标签展示名称：
  /// 当存在同名文件标签时显示相对项目路径，否则优先显示简短文件名
  String getDisplayName(List<EditorTabItem> allTabs, String? rootPath) {
    final hasDuplicateName = allTabs.where((tab) => tab.name == name).length > 1;
    if(hasDuplicateName) {
      if(rootPath != null && rootPath.isNotEmpty) {
        try {
          if(p.isWithin(rootPath, path)) {
            final rel = p.relative(path, from: rootPath);
            return rel;
          }
        }catch (_) {}
      }
      return path;
    }
    return name;
  }

  /// 包含脏标记的前缀名称
  String getFormattedTitle(List<EditorTabItem> allTabs, String? rootPath) {
    final displayName = getDisplayName(allTabs, rootPath);
    return isModified ? '* $displayName' : displayName;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorTabItem && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
