import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/run_task.dart';

/// 单文件任务探测器：针对当前编辑器正在打开的单文件，生成开箱即用的轻量运行任务。
///
/// 包含 8 类语言后缀的独立检测与执行指令安全封装：
/// 1. Python (.py)
/// 2. C (.c)
/// 3. C++ (.cpp, .cc, .cxx)
/// 4. Shell (.sh, .bash)
/// 5. Dart (.dart)
/// 6. Go (.go)
/// 7. Rust (.rs)
/// 8. Node.js (.js)
class SingleFileTaskDetector {
  /// 所有支持的单文件后缀集合（全小写）
  static const Set<String> supportedExtensions = {
    '.py',
    '.c',
    '.cpp',
    '.cc',
    '.cxx',
    '.sh',
    '.bash',
    '.dart',
    '.go',
    '.rs',
    '.js',
  };

  /// 检查给定文件路径是否属于支持的单文件任务类型
  static bool isSupported(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// 探测单文件运行指令（基于当前打开的文件）
  static RunTask? detect(String projectRoot, String currentFilePath) {
    final file = File(currentFilePath);
    if (!file.existsSync()) return null;

    // 边界：只有位于工程根目录内的文件才有意义。
    // 容器里挂载为 /workspace 的正是工程根，工程外的文件在容器内不存在，
    // 生成的 "../xxx" 路径必然执行失败，因此直接不产出单文件任务。
    if (!p.isWithin(projectRoot, currentFilePath)) return null;

    final fileName = p.basename(currentFilePath);
    final ext = p.extension(currentFilePath).toLowerCase();

    String relPath = p.relative(currentFilePath, from: projectRoot).replaceAll(r'\', '/');
    if (!relPath.startsWith('./') && !relPath.startsWith('/')) {
      relPath = './$relPath';
    }

    // 安全转义 Shell 路径参数（单引号包裹并转义内部单引号，彻底阻断 $ 变量展开与特殊字符）
    final escapedRelPath = "'${relPath.replaceAll("'", r"'\''")}'";

    switch (ext) {
      case '.py':
        return RunTask(
          id: 'detected_single_python',
          name: 'Python: $fileName',
          command: 'python3 $escapedRelPath',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.code,
        );
      case '.c':
        return RunTask(
          id: 'detected_single_c',
          name: 'GCC: $fileName',
          command: 'gcc $escapedRelPath -lm -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.terminal,
        );
      case '.cpp':
      case '.cc':
      case '.cxx':
        return RunTask(
          id: 'detected_single_cpp',
          name: 'G++: $fileName',
          command: 'g++ $escapedRelPath -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.terminal,
        );
      case '.sh':
      case '.bash':
        return RunTask(
          id: 'detected_single_sh',
          name: 'Shell: $fileName',
          command: 'sh $escapedRelPath',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.terminal,
        );
      case '.dart':
        return RunTask(
          id: 'detected_single_dart',
          name: 'Dart: $fileName',
          command: 'dart run $escapedRelPath',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.code,
        );
      case '.go':
        return RunTask(
          id: 'detected_single_go',
          name: 'Go: $fileName',
          command: 'go run $escapedRelPath',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.code,
        );
      case '.rs':
        return RunTask(
          id: 'detected_single_rust',
          name: 'Rust: $fileName',
          command: 'rustc $escapedRelPath -o /tmp/a.out && /tmp/a.out',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.code,
        );
      case '.js':
        return RunTask(
          id: 'detected_single_js',
          name: 'Node: $fileName',
          command: 'node $escapedRelPath',
          source: TaskSource.detected,
          group: 'single_file',
          icon: Icons.javascript,
        );
      default:
        return null;
    }
  }
}
