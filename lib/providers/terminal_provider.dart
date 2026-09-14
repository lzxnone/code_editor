import 'dart:async';
import 'package:code_editor/models/terminal_session.dart';
import 'package:flutter/material.dart';

/// 全局终端会话管理 Provider
class TerminalProvider extends ChangeNotifier {
  final List<TerminalSession> _sessions = [];
  int _activeIndex = 0;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  int get activeIndex => _activeIndex;

  bool get isEmpty => _sessions.isEmpty;

  bool get isNotEmpty => _sessions.isNotEmpty;

  TerminalSession? get activeSession {
    if (_sessions.isEmpty) return null;
    if (_activeIndex >= 0 && _activeIndex < _sessions.length) {
      return _sessions[_activeIndex];
    }
    return _sessions.first;
  }

  /// 懒加载：进入终端页面时调用，如果尚未创建会话，则自动创建并激活首个会话
  void ensureInitialized({
    String defaultName = '会话',
    String defaultDistroId = 'alpine',
    String? workspacePath,
  }) {
    if (_sessions.isEmpty) {
      createSession(
        name: defaultName,
        distroId: defaultDistroId,
        workspacePath: workspacePath,
        activate: true,
      );
    }
  }

  /// 创建新会话
  /// [distroId]: 发行版标识符（如 'alpine', 'host'）
  /// [workspacePath]: 绑定的工程根目录路径（挂载至容器内部的 /workspace）
  /// [activate]: 是否自动跳转切换到该会话。抽屉右上角加号点击时为 false（直接添加但不跳转）。
  TerminalSession createSession({
    String? name,
    String distroId = 'alpine',
    String? workspacePath,
    bool activate = false,
    bool autoStartProcess = true,
  }) {
    final nextIndex = _sessions.length + 1;
    final sessionName = (name != null && name.trim().isNotEmpty) ? name.trim() : '会话';
    final session = TerminalSession(
      id: 'session_${DateTime.now().microsecondsSinceEpoch}_$nextIndex',
      name: sessionName,
      distroId: distroId,
      workspacePath: workspacePath,
      autoStartProcess: autoStartProcess,
      onProcessTerminated: () {
        notifyListeners();
      },
    );

    _sessions.add(session);

    if (activate || _sessions.length == 1) {
      _activeIndex = _sessions.length - 1;
    }

    notifyListeners();
    return session;
  }

  /// 查找或复用绑定了指定工程路径与系统实例的终端会话
  /// 如果存在，直接激活并返回；如果不存在，则新建并激活一个会话
  TerminalSession getOrCreateSessionForProject({
    required String projectRoot,
    String distroId = 'ubuntu',
    String? sessionName,
  }) {
    final index = _sessions.indexWhere(
      (s) => s.workspacePath == projectRoot && s.distroId == distroId,
    );
    if (index != -1) {
      final session = _sessions[index];
      selectSession(index);
      if (!session.isProcessRunning) {
        unawaited(session.startProcess());
      }
      return session;
    }

    return createSession(
      name: sessionName,
      distroId: distroId,
      workspacePath: projectRoot,
      activate: true,
      autoStartProcess: true,
    );
  }

  /// 切换当前激活的会话
  void selectSession(int index) {
    if (index >= 0 && index < _sessions.length) {
      if (_activeIndex != index) {
        _activeIndex = index;
        notifyListeners();
      }
    }
  }

  /// 重命名指定终端会话
  void renameSession(String id, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sessions[index].name = trimmed;
      notifyListeners();
    }
  }

  /// 删除指定终端会话
  void removeSession(String id) {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final removedSession = _sessions.removeAt(index);
    removedSession.dispose();

    if (_sessions.isEmpty) {
      _activeIndex = 0;
    } else if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    } else if (_activeIndex > index) {
      _activeIndex--;
    }

    notifyListeners();
  }

  /// 移除指定系统的所有会话（当系统被物理删除时调用）
  void removeSessionsForDistro(String distroId) {
    final toRemove = _sessions.where((s) => s.distroId == distroId).toList();
    if (toRemove.isEmpty) return;

    for (final session in toRemove) {
      session.dispose();
      _sessions.remove(session);
    }

    if (_sessions.isEmpty) {
      _activeIndex = 0;
    } else if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    }

    notifyListeners();
  }

  /// 清空全部会话并释放资源
  void clearAllSessions() {
    if (_sessions.isEmpty) return;
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    _activeIndex = 0;
    notifyListeners();
  }

  /// 拖拽重新排序终端会话（接收 onReorderItem 传入的已修正目标索引）
  void reorderSessions(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _sessions.length) return;
    if (newIndex < 0 || newIndex >= _sessions.length) return;
    if (oldIndex == newIndex) return;

    final activeSessionId = activeSession?.id;

    final session = _sessions.removeAt(oldIndex);
    _sessions.insert(newIndex, session);

    if (activeSessionId != null) {
      final foundIndex = _sessions.indexWhere((s) => s.id == activeSessionId);
      if (foundIndex != -1) {
        _activeIndex = foundIndex;
      }
    }

    notifyListeners();
  }

  /// 向指定终端会话写入文本并通知更新
  void appendOutput(TerminalSession session, String text) {
    session.write(text);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final session in _sessions) {
      session.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
