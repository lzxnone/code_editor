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
    int depth = 0,
    List<String> openDirectoryPaths = const [],
  }) async {
    final rootDir = Directory(dirPath);
    if(!await rootDir.exists()) {
      return [];
    }

    List<FileItem> items = [];

    try {
      final List<FileSystemEntity> entities = await rootDir.list().toList();
      for(var entity in entities) {
        final fileName = p.basename(entity.path);
        if(fileName.startsWith('.')) continue;

        if(entity is Directory) {
          final isDirOpen = openDirectoryPaths.contains(entity.path);
          final children = await buildTree(
            entity.path,
            depth: depth + 1,
            openDirectoryPaths: openDirectoryPaths,
          );
          items.add(FileItem(
            name: fileName,
            path: entity.path,
            isDirectory: true,
            children: children,
            depth: depth,
            isOpen: isDirOpen,
          ));
        }else if(entity is File) {
          items.add(FileItem(
            name: fileName,
            path: entity.path,
            isDirectory: false,
            depth: depth,
          ));
        }
      }

      items.sort((a, b) {
        if(a.isDirectory && !b.isDirectory) return -1;
        if(!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }catch(e) {
      print('扫描目录出错: $e');
    }

    return items;
  }

  //阅读文件内容
  Future<String> readFileContent(String path) async {
    final file = File(path);

    if(!await file.exists()) {
      throw FileSystemException('文件不存在或已被移除', path);
    }

    try {
      return await file.readAsString(
        encoding: const Utf8Codec(allowMalformed: true),
      );
    }catch (e) {
      throw FileSystemException('读取文件失败: $e', path);
    }
  }

  // 写入保存文件
  Future<void> saveFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content, encoding: utf8, flush: true);
  }
}