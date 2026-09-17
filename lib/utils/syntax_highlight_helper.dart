import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

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
    final definition = builtinAllLanguages[langId];
    if (definition != null) {
      final mode = CodeHighlightThemeMode(mode: definition);
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
    return builtinAllLanguages[langId];
  }
}
