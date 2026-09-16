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

  /// 获取配置文件路径: `<files>/internal_engine/lsp_languages.json`
  Future<File> getConfigFile() async {
    final Directory baseDir;
    if (customBaseDir != null) {
      baseDir = customBaseDir!;
    } else {
      final appDir = await getApplicationSupportDirectory();
      final rootPath = p.basename(appDir.path) == 'files'
          ? appDir.path
          : p.join(appDir.path, 'files');
      baseDir = Directory(p.join(rootPath, 'internal_engine'));
    }

    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    return File(p.join(baseDir.path, 'lsp_languages.json'));
  }

  /// 加载配置，若缺失预设语言则自动增量追加合并并回写
  Future<List<LspLanguageConfig>> loadConfigs({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) {
      return _configs;
    }

    final file = await getConfigFile();
    List<LspLanguageConfig> loaded = [];
    bool needSave = false;

    if (!file.existsSync()) {
      loaded = List.from(LspLanguageConfig.defaultPresets);
      needSave = true;
    } else {
      try {
        final content = file.readAsStringSync();
        final dynamic raw = jsonDecode(content);
        if (raw is List) {
          loaded = raw
              .map((e) => e is Map<String, dynamic>
                  ? LspLanguageConfig.fromJson(e)
                  : null)
              .whereType<LspLanguageConfig>()
              .toList();
        }
      } catch (e) {
        debugPrint('读取 lsp_languages.json 异常: $e，使用默认预设');
        loaded = List.from(LspLanguageConfig.defaultPresets);
        needSave = true;
      }

      // 动态增量合并：对比官方预设，若预设中某项 id 本地缺失，则追加进去，默认 enabled: true
      final existingIds = loaded.map((e) => e.id).toSet();
      for (final preset in LspLanguageConfig.defaultPresets) {
        if (!existingIds.contains(preset.id)) {
          loaded.add(preset.copyWith(enabled: true));
          needSave = true;
        }
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

  /// 恢复官方默认预设
  Future<void> resetToDefaults() async {
    _configs = List.from(LspLanguageConfig.defaultPresets);
    await _writeToDisk();
    notifyListeners();
  }

  /// 根据文件扩展名查找匹配的已启用语言配置
  LspLanguageConfig? findByExtension(String ext) {
    if (ext.isEmpty) return null;
    final normalized = ext.startsWith('.') ? ext.toLowerCase() : '.$ext'.toLowerCase();

    for (final config in _configs) {
      if (!config.enabled) continue;
      for (final item in config.fileExtensions) {
        final itemNorm = item.startsWith('.') ? item.toLowerCase() : '.$item'.toLowerCase();
        if (itemNorm == normalized) {
          return config;
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
