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
  final String? workspacePath;
  final DateTime createdAt;
  final Terminal terminal;
  final FocusNode focusNode;

  Pty? _pty;
  StreamSubscription? _ptyOutputSub;
  bool _isProcessRunning = false;
  Completer<bool>? _processCompleter;
  VoidCallback? onProcessTerminated;

  TerminalSession({
    required this.id,
    this.name = '会话',
    this.distroId = 'alpine',
    this.workspacePath,
    this.onProcessTerminated,
    DateTime? createdAt,
    int maxLines = 10000,
    bool autoStartProcess = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        terminal = Terminal(maxLines: maxLines),
        focusNode = FocusNode() {
    _initTerminalEvents();
    if (autoStartProcess) {
      unawaited(startProcess(workspacePath: workspacePath));
    }
  }

  bool get isProcessRunning => _isProcessRunning;

  /// 获取终端进程启动就绪的 Future
  Future<bool>? get onProcessReady => _processCompleter?.future;

  /// 获取终端缓冲区当前全部可见文本（常用于测试与日志断言）
  String get bufferText => terminal.buffer.getText();

  void _initTerminalEvents() {
    // 监听输入直接送往 PTY；若进程已退出或未启动，则完全不处理输入（禁止交互）
    terminal.onOutput = (data) {
      if (_pty != null && _isProcessRunning) {
        try {
          _pty!.write(utf8.encode(data));
        } catch (_) {}
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

  /// 启动底层真实 PTY 进程（连接 PRoot 容器或 Host Shell）
  Future<void> startProcess({DistroManager? distroManager, String? workspacePath}) async {
    if (_processCompleter == null || _processCompleter!.isCompleted) {
      _processCompleter = Completer<bool>();
    }
    final manager = distroManager ?? DistroManager();
    final effectiveWorkspace = workspacePath ?? this.workspacePath;
    try {
      final config = await manager.buildLaunchConfig(
        systemName: distroId,
        workspacePath: effectiveWorkspace,
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
      if (!(_processCompleter?.isCompleted ?? true)) {
        _processCompleter?.complete(true);
      }

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
          onProcessTerminated?.call();
        },
      );

      _pty!.exitCode.then((code) {
        _isProcessRunning = false;
        terminal.write('\r\n\x1b[33m[Process exited with code $code]\x1b[0m\r\n');
        onProcessTerminated?.call();
      });
    } catch (e) {
      _isProcessRunning = false;
      if (!(_processCompleter?.isCompleted ?? true)) {
        _processCompleter?.complete(false);
      }
      terminal.write('\x1b[31m[PTY launch failed: $e]\x1b[0m\r\n');
      onProcessTerminated?.call();
    }
  }

  /// 等待终端底层伪终端进程启动并就绪
  Future<bool> waitForReady({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isProcessRunning && _pty != null) return true;
    if (_processCompleter != null) {
      try {
        return await _processCompleter!.future.timeout(timeout, onTimeout: () => false);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 向终端底层伪终端 (PTY) 真正写入待执行指令
  ///
  /// 该方法通过 [_pty.write] 向进程标准输入通道写入指令并换行，触发 Shell 真正执行任务，
  /// 所有输出实时经由 PTY 流向终端画布呈现给用户。
  Future<void> executeCommand(String command) async {
    if (!_isProcessRunning && _processCompleter == null) {
      unawaited(startProcess());
    }

    final isReady = await waitForReady();
    if (isReady && _pty != null && _isProcessRunning) {
      // 适度微延迟确保 Shell 终端行纪律（termios）已就绪并开始监听 stdin
      await Future<void>.delayed(const Duration(milliseconds: 60));
      try {
        _pty!.write(utf8.encode('$command\n'));
      } catch (e) {
        terminal.write('\r\n\x1b[31m[写入终端失败: $e]\x1b[0m\r\n');
      }
    } else {
      terminal.write('\r\n\x1b[31m[无法执行命令：终端环境未启动或启动失败]\x1b[0m\r\n');
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
