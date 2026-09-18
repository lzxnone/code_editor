import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/lsp_language_config.dart';

/// 语言服务器配置管理器
class LspConfigService extends ChangeNotifier {
  static final LspConfigService instance = LspConfigService._();
  LspConfigService._();

  /// 测试自定义存储目录
  @visibleForTesting
  Directory? customBaseDir;

  List<LspLanguageConfig> _configs = [];
  bool _isLoaded = false;

  List<LspLanguageConfig> get configs => List.unmodifiable(_configs);
  bool get isLoaded => _isLoaded;

  /// 获取配置文件路径: `<files>/config/lsp_languages.json`
  Future<File> getConfigFile() async {
    final Directory baseDir;
    if (customBaseDir != null) {
      baseDir = customBaseDir!;
    } else {
      final appDir = await getApplicationSupportDirectory();
      final rootPath = p.basename(appDir.path) == 'files'
          ? appDir.path
          : p.join(appDir.path, 'files');
      baseDir = Directory(p.join(rootPath, 'config'));

      // 自动迁移旧版本放置在 internal_engine 的配置文件并清理旧目录
      try {
        final legacyDir = Directory(p.join(rootPath, 'internal_engine'));
        final legacyFile = File(p.join(legacyDir.path, 'lsp_languages.json'));
        final targetFile = File(p.join(baseDir.path, 'lsp_languages.json'));

        if (legacyFile.existsSync() && !targetFile.existsSync()) {
          if (!baseDir.existsSync()) {
            baseDir.createSync(recursive: true);
          }
          legacyFile.copySync(targetFile.path);
        }

        if (legacyDir.existsSync()) {
          legacyDir.deleteSync(recursive: true);
          debugPrint('[LspConfigService] 已迁移并清理旧 internal_engine 目录');
        }
      } catch (e) {
        debugPrint('[LspConfigService] 清理旧 internal_engine 异常: $e');
      }
    }

    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    return File(p.join(baseDir.path, 'lsp_languages.json'));
  }

  /// 加载已安装的配置列表。初始为空数组 []，不存在未安装的占位项
  Future<List<LspLanguageConfig>> loadConfigs({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      return _configs;
    }

    final file = await getConfigFile();
    List<LspLanguageConfig> loaded = [];
    bool needSave = false;

    if (!file.existsSync()) {
      // 初始为空数组，写入持久化文件
      loaded = [];
      needSave = true;
    } else {
      try {
        final content = file.readAsStringSync().trim();
        if (content.isNotEmpty) {
          final dynamic raw = jsonDecode(content);
          if (raw is List) {
            loaded = raw
                .map((e) => e is Map<String, dynamic>
                    ? LspLanguageConfig.fromJson(e)
                    : null)
                .whereType<LspLanguageConfig>()
                .toList();
          }
        }
      } catch (e) {
        debugPrint('读取 lsp_languages.json 异常: $e');
        loaded = [];
        needSave = true;
      }
    }

    _configs = loaded;
    _isLoaded = true;

    if (needSave) {
      await _writeToDisk();
    }

    notifyListeners();
    return _configs;
  }

  /// 保存完整配置列表到本地 JSON
  Future<void> saveConfigs(List<LspLanguageConfig> newConfigs) async {
    _configs = List.from(newConfigs);
    _isLoaded = true;
    await _writeToDisk();
    notifyListeners();
  }

  /// 更新或新增某项语言配置
  Future<void> updateConfig(LspLanguageConfig config) async {
    final index = _configs.indexWhere((e) => e.id == config.id);
    if (index >= 0) {
      _configs[index] = config;
    } else {
      _configs.add(config);
    }
    await _writeToDisk();
    notifyListeners();
  }

  /// 删除某项语言配置
  Future<void> deleteConfig(String id) async {
    _configs.removeWhere((e) => e.id == id);
    await _writeToDisk();
    notifyListeners();
  }

  /// 清空所有已配置的语言项
  Future<void> resetToDefaults() async {
    _configs = [];
    await _writeToDisk();
    notifyListeners();
  }

  /// 根据文件扩展名或特殊文件名查找匹配的已启用语言配置
  LspLanguageConfig? findByExtension(String ext, {String? filename}) {
    final cleanName = filename?.trim().toLowerCase();
    if (cleanName != null && cleanName.isNotEmpty) {
      for (final config in _configs) {
        for (final item in config.fileExtensions) {
          if (!item.startsWith('.') && item.toLowerCase() == cleanName) {
            return config.enabled ? config : null;
          }
        }
      }
    }

    if (ext.isEmpty) return null;
    final normalized = ext.startsWith('.') ? ext.toLowerCase() : '.$ext'.toLowerCase();

    for (final config in _configs) {
      for (final item in config.fileExtensions) {
        if (item.startsWith('.')) {
          final itemNorm = item.toLowerCase();
          if (itemNorm == normalized) {
            return config.enabled ? config : null;
          }
        }
      }
    }
    return null;
  }

  Future<void> _writeToDisk() async {
    try {
      final file = await getConfigFile();
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(_configs.map((e) => e.toJson()).toList());
      file.writeAsStringSync(jsonString, flush: true);
    } catch (e) {
      debugPrint('保存 lsp_languages.json 失败: $e');
    }
  }
}
