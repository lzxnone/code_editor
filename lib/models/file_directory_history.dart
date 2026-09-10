import 'dart:convert';

class FileDirectoryHistory {
  final String? rootPath;
  final String? lastOpenedFilePath;
  final List<String> openDirectoryPaths;

  const FileDirectoryHistory({
    required this.rootPath,
    required this.lastOpenedFilePath,
    this.openDirectoryPaths = const [],
  });

  Map<String, dynamic> toMap() => {
    'rootPath': rootPath,
    'lastOpenedFilePath': lastOpenedFilePath,
    'openDirectoryPaths': openDirectoryPaths,
  };

  factory FileDirectoryHistory.fromMap(Map<String, dynamic> map) {
    return FileDirectoryHistory(
      rootPath: map['rootPath'] as String?,
      lastOpenedFilePath: map['lastOpenedFilePath'] as String?,
      openDirectoryPaths: (map['openDirectoryPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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