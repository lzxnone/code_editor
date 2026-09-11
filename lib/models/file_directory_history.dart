import 'dart:convert';

class FileDirectoryHistory {
  final String? rootPath;
  final String? lastOpenedFilePath;
  final List<String> openDirectoryPaths;
  final List<String> openFilePaths;

  const FileDirectoryHistory({
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

  factory FileDirectoryHistory.fromMap(Map<String, dynamic> map) {
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

    return FileDirectoryHistory(
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
  factory FileDirectoryHistory.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return FileDirectoryHistory.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const FileDirectoryHistory(rootPath: null, lastOpenedFilePath: null);
  }
}