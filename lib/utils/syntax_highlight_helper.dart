import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';
import 'syntax_languages/mcfunction.dart';

/// 语法高亮辅助类：
/// 1. 基于文件后缀与特殊文件名的 O(1) 语法匹配，彻底避免全量遍历
/// 2. 语法模式单例缓存，避免每帧重复创建 CodeHighlightThemeMode
class SyntaxHighlightHelper {
  SyntaxHighlightHelper._();

  static final Map<String, CodeHighlightThemeMode> _modeCache = {};

  /// 特殊文件名映射（忽略大小写比较）
  static const Map<String, String> _fileNameMap = {
    'dockerfile': 'dockerfile',
    'makefile': 'makefile',
    'gnumakefile': 'makefile',
    'cmakelists.txt': 'cmake',
    'gemfile': 'ruby',
    'rakefile': 'ruby',
    'podfile': 'ruby',
    'vagrantfile': 'ruby',
    'package.json': 'json',
    'composer.json': 'json',
    'pubspec.yaml': 'yaml',
    'pubspec.lock': 'yaml',
    '.bashrc': 'bash',
    '.bash_profile': 'bash',
    '.zshrc': 'bash',
    '.profile': 'bash',
    '.gitignore': 'ini',
    '.gitattributes': 'ini',
    '.gitmodules': 'ini',
    '.editorconfig': 'ini',
    '.env': 'ini',
  };

  /// 常见扩展名到 re_highlight 语言标识符的 O(1) 映射
  static const Map<String, String> _extensionMap = {
    // Dart & Flutter
    '.dart': 'dart',

    // Web & JS / TS
    '.js': 'javascript',
    '.mjs': 'javascript',
    '.cjs': 'javascript',
    '.jsx': 'javascript',
    '.ts': 'typescript',
    '.mts': 'typescript',
    '.cts': 'typescript',
    '.tsx': 'typescript',
    '.json': 'json',
    '.jsonc': 'json',
    '.arb': 'json',
    '.html': 'xml',
    '.htm': 'xml',
    '.xhtml': 'xml',
    '.vue': 'xml',
    '.css': 'css',
    '.scss': 'scss',
    '.less': 'less',

    // 配置与数据标记
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.xml': 'xml',
    '.iml': 'xml',
    '.svg': 'xml',
    '.plist': 'xml',
    '.xaml': 'xml',
    '.properties': 'properties',
    '.ini': 'ini',
    '.cfg': 'ini',
    '.conf': 'ini',
    '.config': 'ini',
    '.toml': 'ini',
    '.proto': 'protobuf',

    // 文档
    '.md': 'markdown',
    '.markdown': 'markdown',
    '.tex': 'latex',

    // 常用后端与系统语言
    '.py': 'python',
    '.pyw': 'python',
    '.java': 'java',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.c': 'c',
    '.h': 'c',
    '.cpp': 'cpp',
    '.cxx': 'cpp',
    '.cc': 'cpp',
    '.hpp': 'cpp',
    '.hxx': 'cpp',
    '.hh': 'cpp',
    '.cs': 'csharp',
    '.go': 'go',
    '.rs': 'rust',
    '.swift': 'swift',
    '.php': 'php',
    '.rb': 'ruby',
    '.lua': 'lua',
    '.r': 'r',
    '.sql': 'sql',

    // 脚本与自动化
    '.sh': 'bash',
    '.bash': 'bash',
    '.zsh': 'bash',
    '.ps1': 'powershell',
    '.psm1': 'powershell',
    '.bat': 'dos',
    '.cmd': 'dos',

    // 构建与版本控制
    '.cmake': 'cmake',
    '.gradle': 'gradle',
    '.groovy': 'groovy',
    '.diff': 'diff',
    '.patch': 'diff',
    '.dockerfile': 'dockerfile',
    '.graphql': 'graphql',
    '.gql': 'graphql',

    // Minecraft
    '.mcfunction': 'mcfunction',
  };

  /// 根据文件路径获取对应的 re_highlight 语言 ID，未匹配则返回 null
  static String? getLanguageId(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) {
      return null;
    }
    final fileName = p.basename(filePath).toLowerCase();

    // 1. 优先根据完整文件名精准匹配 (例如 Dockerfile, Makefile, pubspec.yaml)
    final exactMatch = _fileNameMap[fileName];
    if (exactMatch != null) {
      return exactMatch;
    }

    // 2. 根据文件扩展名 O(1) 匹配
    final ext = p.extension(filePath).toLowerCase();
    if (ext.isNotEmpty) {
      return _extensionMap[ext];
    }

    return null;
  }

  /// 获取指定语言的 CodeHighlightThemeMode 实例（带缓存单例）
  static CodeHighlightThemeMode? getMode(String langId) {
    final cached = _modeCache[langId];
    if (cached != null) {
      return cached;
    }
    final definition = langId == 'mcfunction' ? langMcfunction : builtinAllLanguages[langId];
    if (definition != null) {
      // 对标 VS Code 性能保护策略：
      // 1. 文件文本超过 2MB 时，安全降级为纯文本，防止巨型语法树引发主线程垃圾回收暂停；
      // 2. 单行超过 4096 字符（如压缩混淆 JSON/JS）时，安全截断单行复杂正则回溯与跨 Isolate 数组序列化。
      final mode = CodeHighlightThemeMode(
        mode: definition,
        maxSize: 2 * 1024 * 1024,
        maxLineLength: 4096,
      );
      _modeCache[langId] = mode;
      return mode;
    }
    return null;
  }

  /// 为指定文件获取仅包含所需语法的精简映射表。
  /// 若为纯文本或未知格式则返回空 Map，不会注入无用的 194 种模式。
  static Map<String, CodeHighlightThemeMode> getLanguagesForFile(String? filePath) {
    final langId = getLanguageId(filePath);
    if (langId == null) {
      return const {};
    }
    final mode = getMode(langId);
    if (mode == null) {
      return const {};
    }
    return {langId: mode};
  }

  /// 获取指定文件对应的 re_highlight 原始 Mode 定义（用于提取语言关键字等）
  static Mode? getGrammarModeForFile(String? filePath) {
    final langId = getLanguageId(filePath);
    if (langId == null) return null;
    if (langId == 'mcfunction') return langMcfunction;
    return builtinAllLanguages[langId];
  }

  static final Highlight _highlightInstance = Highlight()
    ..registerLanguages(builtinAllLanguages)
    ..registerLanguage('mcfunction', langMcfunction);

  /// 针对单行代码生成带语法高亮的 TextSpan（供 Diff 视图等只读代码渲染）
  static TextSpan highlightLine({
    required String code,
    required String? filePath,
    required TextStyle baseStyle,
    required Map<String, TextStyle> highlightTheme,
  }) {
    if (code.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }
    // 性能防御：单行超出 2048 字符（如压缩 JSON/数据行）在 Diff 视图中降级为纯文本，防止每帧重绘卡顿
    if (code.length > 2048) {
      return TextSpan(text: code, style: baseStyle);
    }
    final langId = getLanguageId(filePath);
    if (langId == null) {
      return TextSpan(text: code, style: baseStyle);
    }
    try {
      final result = _highlightInstance.highlight(code: code, language: langId);
      final renderer = TextSpanRenderer(baseStyle, highlightTheme);
      result.render(renderer);
      return renderer.span ?? TextSpan(text: code, style: baseStyle);
    } catch (_) {
      return TextSpan(text: code, style: baseStyle);
    }
  }
}

