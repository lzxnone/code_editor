import 'dart:async';
import 'dart:convert';
import 'package:code_editor/services/distro_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

/// 单个真实交互式终端会话的数据与状态模型（基于 原生 Unix PTY 伪终端）
class TerminalSession {
  final String id;
  String name;
  final String distroId;
  final DateTime createdAt;
  final Terminal terminal;
  final FocusNode focusNode;

  Pty? _pty;
  StreamSubscription? _ptyOutputSub;
  bool _isProcessRunning = false;
  String _inputBuffer = '';

  TerminalSession({
    required this.id,
    this.name = '会话',
    this.distroId = 'alpine',
    DateTime? createdAt,
    int maxLines = 10000,
    bool autoStartProcess = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        terminal = Terminal(maxLines: maxLines),
        focusNode = FocusNode() {
    _initTerminalEvents();
    if (autoStartProcess) {
      unawaited(startProcess());
    }
  }

  bool get isProcessRunning => _isProcessRunning;

  /// 获取终端缓冲区当前全部可见文本（常用于测试与日志断言）
  String get bufferText => terminal.buffer.getText();

  void _initTerminalEvents() {
    // 监听输入直接送往 PTY
    terminal.onOutput = (data) {
      if (_pty != null && _isProcessRunning) {
        try {
          _pty!.write(utf8.encode(data));
        } catch (_) {}
      } else {
        _handleLocalEcho(data);
      }
    };

    // 监听终端视口尺寸变化并同步给底层 PTY
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      if (_pty != null && _isProcessRunning) {
        try {
          _pty!.resize(height, width);
        } catch (_) {}
      }
    };
  }

  /// 当无底层进程挂接时的本地简易交互回显支持（保证脱机/本地开发时的基础交互与光标跳动）
  void _handleLocalEcho(String data) {
    for (int i = 0; i < data.length; i++) {
      final char = data[i];
      if (char == '\r' || char == '\n') {
        terminal.write('\r\n');
        _executeLocalCommand(_inputBuffer.trim());
        _inputBuffer = '';
      } else if (char == '\x7f' || char == '\b') {
        // 退格键
        if (_inputBuffer.isNotEmpty) {
          _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
          terminal.write('\b \b');
        }
      } else if (char.codeUnitAt(0) >= 32) {
        _inputBuffer += char;
        terminal.write(char);
      }
    }
  }

  void _executeLocalCommand(String cmd) {
    if (cmd.isEmpty) {
      terminal.write('\$ ');
      return;
    }
    if (cmd == 'clear') {
      clear();
      terminal.write('\$ ');
      return;
    }
    terminal.write('\x1b[33m[Host fallback]: executed "$cmd"\x1b[0m\r\n');
    terminal.write('\$ ');
  }

  /// 启动底层真实 PTY 进程（连接 PRoot 容器或 Host Shell）
  Future<void> startProcess({DistroManager? distroManager, String? workspacePath}) async {
    final manager = distroManager ?? DistroManager();
    try {
      final config = await manager.buildLaunchConfig(
        systemName: distroId,
        workspacePath: workspacePath,
      );

      final initialRows = terminal.viewHeight > 0 ? terminal.viewHeight : 24;
      final initialCols = terminal.viewWidth > 0 ? terminal.viewWidth : 80;

      // 使用真实 Unix 伪终端 (PTY) 启动子进程
      _pty = Pty.start(
        config.executable,
        arguments: config.arguments,
        environment: config.environment,
        workingDirectory: config.workingDirectory,
        rows: initialRows,
        columns: initialCols,
      );
      _isProcessRunning = true;

      // PTY 输出数据流实时解码并写入终端
      _ptyOutputSub = _pty!.output.listen(
        (bytes) {
          terminal.write(utf8.decode(bytes, allowMalformed: true));
        },
        onError: (err) {
          terminal.write('\r\n\x1b[31m[PTY Output error: $err]\x1b[0m\r\n');
        },
        onDone: () {
          _isProcessRunning = false;
        },
      );

      _pty!.exitCode.then((code) {
        _isProcessRunning = false;
        terminal.write('\r\n\x1b[33m[Process exited with code $code]\x1b[0m\r\n');
      });
    } catch (e) {
      _isProcessRunning = false;
      terminal.write('\x1b[1;36mWelcome to Terminal [$distroId]\x1b[0m\r\n');
      terminal.write('\x1b[90m(PTY launch failed: $e. Running in local fallback mode.)\x1b[0m\r\n\r\n');
      terminal.write('\$ ');
    }
  }

  /// 向终端写入文本（支持 VT100 / ANSI 转义序列）
  void write(String text) {
    terminal.write(text);
  }

  /// 发送标准 ANSI 清屏并复位光标
  void clear() {
    terminal.write('\x1b[2J\x1b[H');
  }

  /// 释放 PTY 进程与焦点资源
  void dispose() {
    _ptyOutputSub?.cancel();
    if (_pty != null) {
      try {
        _pty!.kill();
      } catch (_) {}
      _pty = null;
    }
    focusNode.dispose();
  }
}
