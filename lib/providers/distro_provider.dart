import 'package:code_editor/models/distro_manifest.dart';
import 'package:flutter/foundation.dart';
import '../services/distro_installer.dart';
import '../services/distro_manager.dart';

/// 终端系统状态管理器（单一内置 Ubuntu 环境）
class DistroProvider with ChangeNotifier {

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

  /// 重新扫描已安装的系统并校准状态
  Future<void> refreshSystems() async {
    final isInstalled = await _manager.isSystemInstalled(DistroRepository.defaultSystemName);
    if (isInstalled) {
      _installedSystems = [DistroRepository.defaultSystemName];
      _selectedSystem = DistroRepository.defaultSystemName;
    } else {
      _installedSystems = [];
      _selectedSystem = null;
    }
    notifyListeners();
  }

  /// 选择指定系统为当前活跃系统（仅支持默认 Ubuntu）
  Future<void> selectSystem(String systemName) async {
    await refreshSystems();
  }

  /// 从应用内置资源导入 Ubuntu 24.04 系统实例
  Future<void> importBuiltinUbuntu({
    String systemName = DistroRepository.defaultSystemName,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await _manager.importBuiltinUbuntu(
      systemName: systemName,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    // 导入成功后刷新列表
    await refreshSystems();
  }
}
