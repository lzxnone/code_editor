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
  void ensureInitialized() {
    if (_sessions.isEmpty) {
      createSession(name: '会话', activate: true);
    }
  }

  /// 创建新会话
  /// [distroId]: 发行版标识符（如 'alpine', 'host'）
  /// [activate]: 是否自动跳转切换到该会话。抽屉右上角加号点击时为 false（直接添加但不跳转）。
  TerminalSession createSession({
    String name = '会话',
    String distroId = 'alpine',
    bool activate = false,
  }) {
    final nextIndex = _sessions.length + 1;
    final session = TerminalSession(
      id: 'session_${DateTime.now().microsecondsSinceEpoch}_$nextIndex',
      name: name,
      distroId: distroId,
      initialOutput: [
        'Welcome to Terminal ($nextIndex) [$distroId]',
        'Type "help" for a list of built-in commands or "clear" to clear.',
        '',
      ],
    );

    _sessions.add(session);

    if (activate || _sessions.length == 1) {
      _activeIndex = _sessions.length - 1;
    }

    notifyListeners();
    return session;
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

  /// 向指定终端会话追加输出并通知更新
  void appendOutput(TerminalSession session, String line) {
    session.appendOutput(line);
    notifyListeners();
  }

  /// 执行简单交互命令（支持 help, clear, echo, date 等，后续可无缝接入 PTY / Shell）
  void executeCommand(TerminalSession session, String rawInput) {
    final input = rawInput.trim();
    session.appendOutput('\$ $rawInput');

    if (input.isEmpty) {
      notifyListeners();
      return;
    }

    final parts = input.split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();

    switch (cmd) {
      case 'clear':
        session.clear();
        break;
      case 'help':
        session.appendOutput('Built-in terminal commands:');
        session.appendOutput('  clear        Clear the terminal screen');
        session.appendOutput('  date         Show current date and time');
        session.appendOutput('  echo <msg>   Echo text back');
        session.appendOutput('  help         Show this help information');
        session.appendOutput('  sessions     List active sessions');
        break;
      case 'date':
        session.appendOutput(DateTime.now().toString());
        break;
      case 'echo':
        session.appendOutput(parts.skip(1).join(' '));
        break;
      case 'sessions':
        session.appendOutput('Total sessions: ${_sessions.length}');
        for (int i = 0; i < _sessions.length; i++) {
          final s = _sessions[i];
          final marker = (i == _activeIndex) ? '*' : ' ';
          session.appendOutput(' $marker (${i + 1}) ${s.name} [${s.id}]');
        }
        break;
      default:
        session.appendOutput('command not found: $cmd');
        break;
    }

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
