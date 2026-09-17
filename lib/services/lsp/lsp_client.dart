import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LspException implements Exception {
  final int code;
  final String message;
  final dynamic data;

  const LspException(this.code, this.message, [this.data]);

  @override
  String toString() => 'LspException($code): $message';
}

/// 基于标准输入输出（stdio）的原生高性能 JSON-RPC 2.0 LSP 客户端
class LspClient {
  final Process _process;
  final StreamSubscription<List<int>> _stdoutSub;
  final StreamSubscription<List<int>> _stderrSub;

  int _nextId = 1;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  final Map<String, List<void Function(dynamic params)>> _notificationListeners = {};

  final List<int> _buffer = [];
  bool _isClosed = false;
  bool get isClosed => _isClosed;

  /// 串行异步写入链，杜绝并发写入 stdin 导致 StreamSink is bound to a stream 异常
  Future<void> _writeQueue = Future.value();

  LspClient(this._process)
      : _stdoutSub = _process.stdout.listen(null),
        _stderrSub = _process.stderr.listen(null) {
    _stdoutSub.onData(_handleStdoutData);
    _stderrSub.onData(_handleStderrData);
    _process.exitCode.then((code) {
      debugPrint('[LspClient] 语言服务进程退出: $code');
      close();
    });
  }

  /// 注册监听服务端的单向通知（如 textDocument/publishDiagnostics）
  void onNotification(String method, void Function(dynamic params) handler) {
    _notificationListeners.putIfAbsent(method, () => []).add(handler);
  }

  /// 发送 JSON-RPC 2.0 请求并等待响应结果
  Future<T?> sendRequest<T>(String method, [dynamic params, Duration timeout = const Duration(seconds: 10)]) async {
    if (_isClosed) {
      throw StateError('LspClient 已关闭，无法发送请求: $method');
    }

    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final payload = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };

    _sendMessage(payload);

    try {
      final res = await completer.future.timeout(timeout);
      return res as T?;
    } on TimeoutException {
      _pendingRequests.remove(id);
      debugPrint('[LspClient] 请求超时: $method (id: $id)');
      return null;
    } catch (e) {
      _pendingRequests.remove(id);
      rethrow;
    }
  }

  /// 发送单向通知（无需回复，如 textDocument/didChange, didOpen）
  void sendNotification(String method, [dynamic params]) {
    if (_isClosed) return;
    final payload = {
      'jsonrpc': '2.0',
      'method': method,
      if (params != null) 'params': params,
    };
    _sendMessage(payload);
  }

  void _sendMessage(Map<String, dynamic> payload) {
    if (_isClosed) return;

    _writeQueue = _writeQueue.then((_) async {
      if (_isClosed) return;
      try {
        final jsonStr = jsonEncode(payload);
        final bodyBytes = utf8.encode(jsonStr);
        final headerStr = 'Content-Length: ${bodyBytes.length}\r\n\r\n';
        final headerBytes = ascii.encode(headerStr);

        _process.stdin.add(headerBytes);
        _process.stdin.add(bodyBytes);
        await _process.stdin.flush();
      } catch (e) {
        debugPrint('[LspClient] 发送消息异常: $e');
      }
    }).catchError((e) {
      debugPrint('[LspClient] 消息写入队列异常: $e');
    });
  }

  void _handleStdoutData(List<int> chunk) {
    _buffer.addAll(chunk);

    while (true) {
      final headerEnd = _findHeaderEnd(_buffer);
      if (headerEnd == -1) break;

      final headerBytes = _buffer.sublist(0, headerEnd);
      final headerStr = ascii.decode(headerBytes, allowInvalid: true);
      final contentLength = _parseContentLength(headerStr);

      if (contentLength == null) {
        // 异常头部，跳过4字节分隔符
        _buffer.removeRange(0, headerEnd + 4);
        continue;
      }

      final totalMsgLength = headerEnd + 4 + contentLength;
      if (_buffer.length < totalMsgLength) {
        // 数据包尚未完整接收，等待下一个 chunk
        break;
      }

      final bodyBytes = _buffer.sublist(headerEnd + 4, totalMsgLength);
      _buffer.removeRange(0, totalMsgLength);

      try {
        final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
        final dynamic msg = jsonDecode(bodyStr);
        if (msg is Map<String, dynamic>) {
          _dispatchMessage(msg);
        }
      } catch (e) {
        debugPrint('[LspClient] 解析消息体异常: $e');
      }
    }
  }

  void _dispatchMessage(Map<String, dynamic> msg) {
    final id = msg['id'];
    final method = msg['method'] as String?;

    // 1. 响应我们之前发送的 Request (id != null, 无 method)
    if (id != null && method == null) {
      final intId = id is int ? id : int.tryParse(id.toString());
      if (intId != null && _pendingRequests.containsKey(intId)) {
        final completer = _pendingRequests.remove(intId)!;
        if (msg.containsKey('error')) {
          final err = msg['error'];
          if (err is Map) {
            completer.completeError(LspException(
              err['code'] as int? ?? -1,
              err['message'] as String? ?? 'Unknown error',
              err['data'],
            ));
          } else {
            completer.completeError(LspException(-1, err.toString()));
          }
        } else {
          completer.complete(msg['result']);
        }
      }
      return;
    }

    // 2. 服务端主动推送的单向通知 (id == null, 有 method)
    if (method != null && id == null) {
      final listeners = _notificationListeners[method];
      if (listeners != null) {
        for (final listener in listeners) {
          try {
            listener(msg['params']);
          } catch (e) {
            debugPrint('[LspClient] 通知监听执行异常 ($method): $e');
          }
        }
      }
      return;
    }

    // 3. 服务端向客户端发送的请求 (id != null, 有 method，如 workspace/configuration)
    if (method != null && id != null) {
      _handleServerRequest(id, method, msg['params']);
    }
  }

  void _handleServerRequest(dynamic id, String method, dynamic params) {
    // 基础应答：返回 null 或空配置，避免服务端挂起
    final reply = {
      'jsonrpc': '2.0',
      'id': id,
      'result': null,
    };
    _sendMessage(reply);
  }

  void _handleStderrData(List<int> chunk) {
    // 记录语言服务器的 stderr 日志（调试信息）
    final text = utf8.decode(chunk, allowMalformed: true);
    if (kDebugMode) {
      debugPrint('[LSP Stderr] $text');
    }
  }

  int _findHeaderEnd(List<int> buf) {
    // 匹配 \r\n\r\n (13, 10, 13, 10)
    for (int i = 0; i <= buf.length - 4; i++) {
      if (buf[i] == 13 && buf[i + 1] == 10 && buf[i + 2] == 13 && buf[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  int? _parseContentLength(String headerStr) {
    for (final line in headerStr.split('\r\n')) {
      final parts = line.split(':');
      if (parts.length >= 2 && parts[0].trim().toLowerCase() == 'content-length') {
        return int.tryParse(parts[1].trim());
      }
    }
    return null;
  }

  void close() {
    if (_isClosed) return;
    _isClosed = true;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(const LspException(-32099, 'LspClient 已关闭'));
      }
    }
    _pendingRequests.clear();
    _notificationListeners.clear();
    _stdoutSub.cancel();
    _stderrSub.cancel();
    try {
      _process.kill();
    } catch (_) {}
  }
}
