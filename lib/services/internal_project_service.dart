import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'archive_compressor.dart';
import 'archive_extractor.dart';

/// 软件内部私有存储项目管理服务 (files/projects)
class InternalProjectService {
  static final InternalProjectService instance = InternalProjectService._();
  factory InternalProjectService() => instance;
  InternalProjectService._();

  /// 自定义项目存储根目录（主要用于单元测试与隔离环境）
  @visibleForTesting
  Directory? customProjectsDir;

  Directory? _cachedProjectsDir;

  /// 判断指定路径是否为内部存储项目路径 (`files/projects/<projectName>`)
  bool isInternalProject(String? projectPath) {
    if (projectPath == null || projectPath.trim().isEmpty) return false;
    final cleanPath = p.normalize(projectPath.trim());

    if (customProjectsDir != null) {
      final customParent = p.normalize(customProjectsDir!.path);
      return p.equals(p.dirname(cleanPath), customParent);
    }

    if (_cachedProjectsDir != null) {
      final cachedParent = p.normalize(_cachedProjectsDir!.path);
      return p.equals(p.dirname(cleanPath), cachedParent);
    }

    final parentDir = p.normalize(p.dirname(cleanPath));
    final parts = p.split(parentDir);
    if (parts.length >= 2 &&
        parts[parts.length - 2] == 'files' &&
        parts[parts.length - 1] == 'projects') {
      return true;
    }

    return false;
  }

  /// 获取软件内部存储的项目基础目录: `files/projects`
  Future<Directory> getProjectsDirectory() async {
    if (customProjectsDir != null) {
      if (!customProjectsDir!.existsSync()) {
        customProjectsDir!.createSync(recursive: true);
      }
      return customProjectsDir!;
    }

    if (_cachedProjectsDir != null) {
      if (!_cachedProjectsDir!.existsSync()) {
        _cachedProjectsDir!.createSync(recursive: true);
      }
      return _cachedProjectsDir!;
    }

    final appDir = await getApplicationSupportDirectory();
    // Android 下 getApplicationSupportDirectory 对应 .../files
    // 若路径已以 files 结尾，则直接拼接 projects；否则拼接 files/projects 保持规范一致
    final baseDir = p.basename(appDir.path) == 'files'
        ? appDir.path
        : p.join(appDir.path, 'files');

    final projectsDir = Directory(p.join(baseDir, 'projects'));
    if (!projectsDir.existsSync()) {
      projectsDir.createSync(recursive: true);
    }
    _cachedProjectsDir = projectsDir;
    return projectsDir;
  }

  /// 获取所有已创建的内部项目列表（按文件夹名称升序排列）
  Future<List<Directory>> listProjects() async {
    final dir = await getProjectsDirectory();
    if (!dir.existsSync()) {
      return [];
    }

    try {
      final entities = dir.listSync(followLinks: false);
      final projects = entities.whereType<Directory>().toList();
      projects.sort((a, b) => p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase()));
      return projects;
    } catch (e) {
      debugPrint('获取内部项目列表失败: $e');
      return [];
    }
  }

  /// 检查指定项目名称是否已存在
  Future<bool> projectExists(String name) async {
    final dir = await getProjectsDirectory();
    final targetDir = Directory(p.join(dir.path, name.trim()));
    return targetDir.existsSync();
  }

  /// 在 `files/projects` 下新建一个项目文件夹
  Future<Directory> createProject(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FileSystemException('项目名称不能为空');
    }

    final dir = await getProjectsDirectory();
    final projectDir = Directory(p.join(dir.path, trimmedName));
    if (projectDir.existsSync()) {
      throw FileSystemException('同名项目已存在', projectDir.path);
    }

    projectDir.createSync(recursive: true);
    return projectDir;
  }

  /// 重命名指定的项目文件夹
  Future<Directory> renameProject(Directory projectDir, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw const FileSystemException('项目名称不能为空');
    }

    final parent = projectDir.parent;
    final newDir = Directory(p.join(parent.path, trimmedName));
    if (p.normalize(projectDir.path) == p.normalize(newDir.path)) {
      return projectDir;
    }

    if (newDir.existsSync()) {
      throw FileSystemException('同名项目已存在', newDir.path);
    }

    return projectDir.renameSync(newDir.path);
  }

  /// 递归删除项目文件夹
  Future<void> deleteProject(Directory projectDir) async {
    if (projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
  }

  /// 从外部压缩文件解压导入为内部项目 (`files/projects/<projectName>`)
  /// （采用底层 Isolate 流式分块直写落盘引擎，避免大项目解压内存溢出 OOM）
  Future<Directory> importProjectFromArchive(
    String archivePath,
    String projectName, {
    ArchiveProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final trimmedName = projectName.trim();
    if (trimmedName.isEmpty) {
      throw const FileSystemException('项目名称不能为空');
    }

    final dir = await getProjectsDirectory();
    final projectDir = Directory(p.join(dir.path, trimmedName));
    if (projectDir.existsSync()) {
      throw FileSystemException('同名项目已存在', projectDir.path);
    }

    final archiveFile = File(archivePath);
    if (!archiveFile.existsSync()) {
      throw FileSystemException('压缩包文件不存在', archivePath);
    }

    projectDir.createSync(recursive: true);
    try {
      await ArchiveExtractor.extract(
        archiveFile: archiveFile,
        targetDir: projectDir,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      return projectDir;
    } catch (e) {
      if (projectDir.existsSync()) {
        try {
          projectDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// 将内部项目文件夹流式打包压缩为 ZIP 文件并导出到指定路径
  /// （采用自研后台 Isolate 流式分块直写引擎，避免大项目压缩 OOM）
  Future<File> exportProjectToZip(
    Directory projectDir,
    String targetZipPath, {
    ArchiveProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!projectDir.existsSync()) {
      throw FileSystemException('项目目录不存在', projectDir.path);
    }

    final targetFile = File(targetZipPath);
    await ArchiveCompressor.zipDirectory(
      sourceDir: projectDir,
      targetZipFile: targetFile,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return targetFile;
  }
}
