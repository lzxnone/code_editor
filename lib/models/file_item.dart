class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  final List<FileItem> children;
  final int depth;
  bool isOpen;

  FileItem({
    required this.path,
    required this.name,
    this.isDirectory = false,
    this.children = const [],
    this.depth = 0,
    this.isOpen = false
  });
}