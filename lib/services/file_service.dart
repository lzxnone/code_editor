import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';

class FileService {
  static final FileService instance = FileService._();
  FileService._();

  //构建文件目录树
  Future<List<FileItem>> buildTree(
    String dirPath, {
    String? rootPath,
    int depth = 0,
    List<String> openDirectoryPaths = const [],
    int maxDepth = 10,
  }) async {
    if(depth > maxDepth) {
      return [];
    }

    final effectiveRoot = rootPath ?? dirPath;

    final rootDir = Directory(dirPath);
    try {
      if(!await rootDir.exists()) {
        return [];
      }
    }catch (_) {
      return [];
    }

    List<FileItem> items = [];

    try {
      final List<FileSystemEntity> entities = await rootDir
          .list(followLinks: false)
          .handleError((e) {
            // 忽略无权限或已损坏的项目
          })
          .toList();

      final normalizedOpenPaths = openDirectoryPaths.map((e) => p.normalize(e)).toSet();

      for(var entity in entities) {
        try {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('.')) continue;

          final entityPath = p.normalize(entity.path);
          String? relativePath;
          try {
            relativePath = p.relative(entityPath, from: effectiveRoot);
          }catch (_) {}

          if(entity is Directory) {
            final isDirOpen = normalizedOpenPaths.contains(entityPath);
            List<FileItem> children = [];
            // 只有当该子目录确实被用户展开时，才递归加载其子项，避免无限制深度扫描
            if(isDirOpen) {
              children = await buildTree(
                entityPath,
                rootPath: effectiveRoot,
                depth: depth + 1,
                openDirectoryPaths: openDirectoryPaths,
                maxDepth: maxDepth,
              );
            }
            items.add(FileItem(
              name: fileName,
              path: entityPath,
              relativePath: relativePath,
              isDirectory: true,
              children: children,
              depth: depth,
              isOpen: isDirOpen,
            ));
          }else if (entity is File) {
            items.add(FileItem(
              name: fileName,
              path: entityPath,
              relativePath: relativePath,
              isDirectory: false,
              depth: depth,
            ));
          }
        }catch (_) {
          // 单个文件/目录异常跳过，防止整体崩溃
          continue;
        }
      }

      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }catch (_) {
      // 扫描顶层目录出错，安全返回已扫描项
    }

    return items;
  }

  //二进制文件扩展名
  static const Set<String> _binaryExtensions = {
    '.exe', '.dll', '.bin', '.so', '.dylib', '.class', '.pyc',
    '.zip', '.tar', '.gz', '.7z', '.rar', '.iso', '.apk', '.aab',
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.bmp',
    '.mp3', '.mp4', '.wav', '.avi', '.mov', '.flv', '.mkv',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.db', '.sqlite', '.sqlite3',
  };

  // 最大允许读取为文本的大小（默认 2MB）
  static const int maxTextFileSize = 2 * 1024 * 1024;

  //阅读文件内容
  Future<String> readFileContent(String path) async {
    final file = File(path);

    if(!await file.exists()) {
      throw FileSystemException('文件不存在或已被移除', path);
    }

    final ext = p.extension(path).toLowerCase();
    if(_binaryExtensions.contains(ext)) {
      throw const FileSystemException('此文件是二进制可执行文件或多媒体文件，不支持作为文本编辑');
    }

    final length = await file.length();
    if(length > maxTextFileSize) {
      final sizeMb = (length / (1024 * 1024)).toStringAsFixed(1);
      throw FileSystemException('文件过大 (${sizeMb}MB)，超过了编辑器限制 (2MB)，暂不支持直接打开');
    }

    try {
      // 先采样前 4KB 检测是否包含二进制 0x00 字节，防止无后缀的二进制文件被当作文本读入导致卡死
      final raf = await file.open(mode: FileMode.read);
      try {
        final buffer = List<int>.filled(4096, 0);
        final bytesRead = await raf.readInto(buffer, 0, 4096);
        for(int i = 0; i < bytesRead; i++) {
          if(buffer[i] == 0) {
            throw const FileSystemException('检测到该文件为二进制格式，不支持作为文本展示与编辑');
          }
        }
      }finally {
        await raf.close();
      }

      return await file.readAsString(
        encoding: const Utf8Codec(allowMalformed: true),
      );
    }catch (e) {
      if (e is FileSystemException) rethrow;
      throw FileSystemException('读取文件失败: $e', path);
    }
  }

  // 写入保存文件
  Future<void> saveFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content, encoding: utf8, flush: true);
  }

  // 新建文件
  Future<void> createFile(String targetPath) async {
    final file = File(targetPath);
    if(await file.exists()) {
      throw FileSystemException('文件已存在', targetPath);
    }
    await file.create(recursive: true);
  }

  // 新建文件夹
  Future<void> createDirectory(String targetPath) async {
    final dir = Directory(targetPath);
    if(await dir.exists()) {
      throw FileSystemException('文件夹已存在', targetPath);
    }
    await dir.create(recursive: true);
  }

  // 重命名
  Future<void> renameEntity(String oldPath, String newName) async {
    final entityType = await FileSystemEntity.type(oldPath);
    if(entityType == FileSystemEntityType.notFound) {
      throw FileSystemException('项目不存在', oldPath);
    }
    final parentDir = p.dirname(oldPath);
    final newPath = p.join(parentDir, newName);

    if(entityType == FileSystemEntityType.directory) {
      await Directory(oldPath).rename(newPath);
    }else {
      await File(oldPath).rename(newPath);
    }
  }

  // 删除
  Future<void> deleteEntity(String targetPath) async {
    final entityType = await FileSystemEntity.type(targetPath);
    if(entityType == FileSystemEntityType.directory) {
      await Directory(targetPath).delete(recursive: true);
    }else if (entityType == FileSystemEntityType.file) {
      await File(targetPath).delete();
    }
  }

  // 递归拷贝文件夹或文件
  Future<void> copyEntity(String sourcePath, String destinationDir) async {
    final entityType = await FileSystemEntity.type(sourcePath);
    final baseName = p.basename(sourcePath);
    String targetPath = p.join(destinationDir, baseName);

    // 如果同名，自动生成副本名称（如 file(1).dart）
    targetPath = await _getUniqueTargetPath(targetPath, entityType == FileSystemEntityType.directory);

    if(entityType == FileSystemEntityType.directory) {
      await _copyDirectory(Directory(sourcePath), Directory(targetPath));
    }else if (entityType == FileSystemEntityType.file) {
      await File(sourcePath).copy(targetPath);
    }
  }

  // 移动（用于剪切后粘贴）
  Future<void> moveEntity(String sourcePath, String destinationDir) async {
    final entityType = await FileSystemEntity.type(sourcePath);
    final baseName = p.basename(sourcePath);
    String targetPath = p.join(destinationDir, baseName);

    if(p.equals(p.dirname(sourcePath), destinationDir)) {
      // 在同一目录下粘贴剪切的项目，无需操作
      return;
    }

    targetPath = await _getUniqueTargetPath(targetPath, entityType == FileSystemEntityType.directory);

    if(entityType == FileSystemEntityType.directory) {
      try {
        await Directory(sourcePath).rename(targetPath);
      }catch (_) {
        // 跨盘符或无法直接 rename 时退化为 copy + delete
        await _copyDirectory(Directory(sourcePath), Directory(targetPath));
        await Directory(sourcePath).delete(recursive: true);
      }
    }else if (entityType == FileSystemEntityType.file) {
      try {
        await File(sourcePath).rename(targetPath);
      }catch (_) {
        await File(sourcePath).copy(targetPath);
        await File(sourcePath).delete();
      }
    }
  }

  //递归复制文件
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false, followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if(entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  //处理同名
  Future<String> _getUniqueTargetPath(String originalPath, bool isDirectory) async {
    if(!await FileSystemEntity.isDirectory(originalPath) &&
        !await FileSystemEntity.isFile(originalPath)) {
      return originalPath;
    }

    final parent = p.dirname(originalPath);
    final ext = isDirectory ? '' : p.extension(originalPath);
    final nameWithoutExt = isDirectory
        ? p.basename(originalPath)
        : p.basenameWithoutExtension(originalPath);

    int counter = 1;
    while(true) {
      final candidateName = '$nameWithoutExt($counter)$ext';
      final candidatePath = p.join(parent, candidateName);
      if(!await FileSystemEntity.isDirectory(candidatePath) &&
          !await FileSystemEntity.isFile(candidatePath)) {
        return candidatePath;
      }
      counter++;
    }
  }

  //存在
  Future<bool> entityExists(String path) async {
    final type = await FileSystemEntity.type(path);
    return type != FileSystemEntityType.notFound;
  }
}