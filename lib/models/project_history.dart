import 'dart:convert';

class ProjectHistory {
  final String? rootPath; //项目根绝对路径
  final String? lastOpenedFilePath; //上一次打开的文件绝对路径
  final List<String> openDirectoryPaths; //在文件树中打开的所有文件夹的绝对路径
  final List<String> openFilePaths; //存在于编辑区的所有文件的绝对路径

  const ProjectHistory({
    required this.rootPath,
    required this.lastOpenedFilePath,
    this.openDirectoryPaths = const [],
    this.openFilePaths = const [],
  });

  Map<String, dynamic> toMap() => {
    'rootPath': rootPath,
    'lastOpenedFilePath': lastOpenedFilePath,
    'openDirectoryPaths': openDirectoryPaths,
    'openFilePaths': openFilePaths,
  };

  factory ProjectHistory.fromMap(Map<String, dynamic> map) {
    final rawOpenFilePaths = map['openFilePaths'] as List<dynamic>?;
    final lastFile = map['lastOpenedFilePath'] as String?;
    List<String> openFiles;
    if (rawOpenFilePaths != null) {
      openFiles = rawOpenFilePaths.map((e) => e.toString()).toList();
    } else if (lastFile != null && lastFile.isNotEmpty) {
      openFiles = [lastFile];
    } else {
      openFiles = const [];
    }

    return ProjectHistory(
      rootPath: map['rootPath'] as String?,
      lastOpenedFilePath: lastFile,
      openDirectoryPaths: (map['openDirectoryPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      openFilePaths: openFiles,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ProjectHistory.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return ProjectHistory.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const ProjectHistory(rootPath: null, lastOpenedFilePath: null);
  }
}