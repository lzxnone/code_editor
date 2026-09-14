import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/distro_installer.dart';
import '../services/distro_manager.dart';

/// 终端多系统状态与默认系统持久化管理器
class DistroProvider with ChangeNotifier {
  static const String _prefKeyDefaultSystem = 'terminal_default_system';

  final DistroManager _manager = DistroManager();

  /// 当前已安装的系统名称列表
  List<String> _installedSystems = [];

  /// 当前选中的默认系统（若无系统则为 null）
  String? _selectedSystem;

  /// 是否已完成初始状态加载
  bool _isInitialized = false;

  /// 系统被物理删除时的回调监听（如联动终端清理其下全部关联会话）
  void Function(String deletedSystem)? onSystemDeleted;

  bool get isInitialized => _isInitialized;

  List<String> get installedSystems => List.unmodifiable(_installedSystems);

  String? get selectedSystem => _selectedSystem;

  bool get hasAnySystem => _installedSystems.isNotEmpty;

  /// 初始化：扫描系统列表并读取持久化的默认系统
  Future<void> init() async {
    await refreshSystems();
    _isInitialized = true;
    notifyListeners();
  }

  /// 重新扫描已安装的系统并校准当前默认选中项
  Future<void> refreshSystems() async {
    final systems = await _manager.listInstalledSystems();
    _installedSystems = systems;

    final prefs = await SharedPreferences.getInstance();
    final savedSystem = prefs.getString(_prefKeyDefaultSystem);

    if (savedSystem != null && _installedSystems.contains(savedSystem)) {
      _selectedSystem = savedSystem;
    } else if (_installedSystems.isNotEmpty) {
      _selectedSystem = _installedSystems.first;
      await prefs.setString(_prefKeyDefaultSystem, _selectedSystem!);
    } else {
      _selectedSystem = null;
      await prefs.remove(_prefKeyDefaultSystem);
    }

    notifyListeners();
  }

  /// 选择指定系统为当前活跃系统并持久化为默认系统
  Future<void> selectSystem(String systemName) async {
    if (!_installedSystems.contains(systemName)) return;

    if (_selectedSystem != systemName) {
      _selectedSystem = systemName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDefaultSystem, systemName);
      notifyListeners();
    }
  }

  /// 从应用内置资源导入 Ubuntu 24.04 系统实例
  Future<void> importBuiltinUbuntu({
    required String systemName,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await _manager.importBuiltinUbuntu(
      systemName: systemName,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    // 导入成功后刷新列表并自动选为当前系统
    await refreshSystems();
    await selectSystem(systemName);
  }

  /// 从应用内置资源导入 Alpine 系统实例（保留备用）
  Future<void> importBuiltinAlpine({
    required String systemName,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await _manager.importBuiltinAlpine(
      systemName: systemName,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    // 导入成功后刷新列表并自动选为当前系统
    await refreshSystems();
    await selectSystem(systemName);
  }

  /// 从外部 .tar.gz 压缩包导入自定义系统实例
  Future<void> importFromCustomTarGz({
    required String systemName,
    required File tarGzFile,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await _manager.importFromCustomTarGz(
      systemName: systemName,
      tarGzFile: tarGzFile,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    // 导入成功后刷新列表并自动选为当前系统
    await refreshSystems();
    await selectSystem(systemName);
  }

  /// 高危操作：删除指定系统实例
  Future<void> deleteSystem(String systemName) async {
    await _manager.deleteSystem(systemName);
    onSystemDeleted?.call(systemName);
    await refreshSystems();
  }
}
