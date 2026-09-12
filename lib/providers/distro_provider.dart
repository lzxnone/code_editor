import 'package:flutter/foundation.dart';
import '../models/distro_info.dart';
import '../services/distro_manager.dart';

/// Linux 发行版状态提供者（供 UI 监听与绑定）
class DistroProvider with ChangeNotifier {
  final DistroManager _manager = DistroManager();

  /// 各发行版状态缓存
  final Map<String, DistroStatus> _statuses = {};

  /// 安装进度 (0.0 ~ 1.0)
  final Map<String, double> _progress = {};

  /// 状态描述文字（如 "正在解压... 45%"）
  final Map<String, String> _statusMessages = {};

  /// 默认创建会话使用的发行版 ID
  String _defaultDistroId = 'alpine';

  String get defaultDistroId => _defaultDistroId;

  List<DistroInfo> get distros => _manager.listDistros();

  DistroStatus getStatus(String id) => _statuses[id] ?? DistroStatus.notInstalled;

  double getProgress(String id) => _progress[id] ?? 0.0;

  String getStatusMessage(String id) => _statusMessages[id] ?? '';

  /// 初始化检查所有发行版状态
  Future<void> checkAllStatuses() async {
    for (final distro in _manager.listDistros()) {
      try {
        final isInst = await _manager.isInstalled(distro.id);
        _statuses[distro.id] = isInst ? DistroStatus.installed : DistroStatus.notInstalled;
      } catch (_) {
        _statuses[distro.id] = DistroStatus.error;
      }
    }
    notifyListeners();
  }

  /// 设置默认发行版
  void setDefaultDistro(String id) {
    if (_defaultDistroId != id) {
      _defaultDistroId = id;
      notifyListeners();
    }
  }

  /// 安装发行版
  Future<bool> installDistro(String distroId) async {
    _statuses[distroId] = DistroStatus.installing;
    _progress[distroId] = 0.0;
    _statusMessages[distroId] = '准备开始安装...';
    notifyListeners();

    try {
      await _manager.installDistro(
        distroId,
        onProgress: (prog, msg) {
          _progress[distroId] = prog;
          _statusMessages[distroId] = msg;
          notifyListeners();
        },
      );
      _statuses[distroId] = DistroStatus.installed;
      _statusMessages[distroId] = '已就绪';
      notifyListeners();
      return true;
    } catch (e) {
      _statuses[distroId] = DistroStatus.error;
      _statusMessages[distroId] = '安装失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 卸载发行版
  Future<void> uninstallDistro(String distroId) async {
    try {
      await _manager.uninstallDistro(distroId);
      _statuses[distroId] = DistroStatus.notInstalled;
      _progress.remove(distroId);
      _statusMessages.remove(distroId);
      notifyListeners();
    } catch (e) {
      _statusMessages[distroId] = '卸载失败: $e';
      notifyListeners();
    }
  }
}
