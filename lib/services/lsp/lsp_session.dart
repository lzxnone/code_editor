import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/lsp_language_config.dart';
import 'lsp_client.dart';
import 'lsp_diagnostics_store.dart';
import 'lsp_protocol.dart';
import 'proot_path_mapper.dart';

/// 单个语言服务会话（管理与后台进程的文档增量同步、智能补全与诊断流）
class LspSession {
  final LspClient client;
  final LspLanguageConfig config;
  final String workspaceRoot;

  final Map<String, int> _fileVersions = {};
  final Map<String, Timer> _debounceTimers = {};
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  LspSession({
    required this.client,
    required this.config,
    required this.workspaceRoot,
  }) {
    _registerNotificationHandlers();
  }

  void _registerNotificationHandlers() {
    client.onNotification('textDocument/publishDiagnostics', (params) {
      if (params is Map<String, dynamic>) {
        final uri = params['uri'] as String? ?? '';
        final diagsRaw = params['diagnostics'] as List? ?? const [];
        final diags = diagsRaw
            .whereType<Map<String, dynamic>>()
            .map((d) => LspDiagnostic.fromJson(d))
            .toList();

        final hostPath = _fromGuestUriToHostPath(uri);
        LspDiagnosticsStore.instance.updateDiagnostics(hostPath, diags);
        if (hostPath != uri) {
          LspDiagnosticsStore.instance.updateDiagnostics(uri, diags);
        }
      }
    });
  }

  /// 发送 initialize 握手报文
  Future<bool> initialize() async {
    final rootUri = _toGuestUri(workspaceRoot);
    final guestRootPath = PRootPathMapper.toGuestPath(workspaceRoot, workspaceRoot);
    final initParams = {
      'processId': null,
      'rootUri': rootUri,
      'rootPath': guestRootPath,
      'capabilities': {
        'textDocument': {
          'synchronization': {
            'dynamicRegistration': false,
            'willSave': false,
            'willSaveWaitUntil': false,
            'didSave': true,
          },
          'completion': {
            'dynamicRegistration': false,
            'completionItem': {
              'snippetSupport': true,
              'documentationFormat': ['markdown', 'plaintext'],
            },
          },
          'publishDiagnostics': {
            'relatedInformation': true,
          },
          'codeAction': {
            'codeActionLiteralSupport': {
              'codeActionKind': {
                'valueSet': ['quickfix', 'refactor'],
              },
            },
          },
        },
      },
    };

    try {
      final res = await client.sendRequest('initialize', initParams);
      if (res != null) {
        client.sendNotification('initialized', {});
        _isInitialized = true;
        debugPrint('[LspSession] 语言服务初始化成功: ${config.name} (${config.serverCommand})');
        return true;
      }
    } catch (e) {
      debugPrint('[LspSession] 初始化失败: $e');
    }
    return false;
  }

  /// 文档打开通知
  void didOpen(String filePath, String text) {
    final uri = _toGuestUri(filePath);
    _fileVersions[filePath] = 1;

    client.sendNotification('textDocument/didOpen', {
      'textDocument': {
        'uri': uri,
        'languageId': config.languageId,
        'version': 1,
        'text': text,
      },
    });
  }

  /// 文档内容变更通知（带 250ms 智能防抖）
  void didChange(String filePath, String fullText) {
    if (!_fileVersions.containsKey(filePath)) {
      didOpen(filePath, fullText);
      return;
    }

    _debounceTimers[filePath]?.cancel();
    _debounceTimers[filePath] = Timer(const Duration(milliseconds: 250), () {
      if (client.isClosed) return;
      final uri = _toGuestUri(filePath);
      final newVersion = (_fileVersions[filePath] ?? 1) + 1;
      _fileVersions[filePath] = newVersion;

      client.sendNotification('textDocument/didChange', {
        'textDocument': {
          'uri': uri,
          'version': newVersion,
        },
        'contentChanges': [
          {'text': fullText},
        ],
      });
    });
  }

  /// 文档关闭通知
  void didClose(String filePath) {
    _debounceTimers[filePath]?.cancel();
    _debounceTimers.remove(filePath);
    _fileVersions.remove(filePath);
    final uri = _toGuestUri(filePath);

    client.sendNotification('textDocument/didClose', {
      'textDocument': {
        'uri': uri,
      },
    });
  }

  /// 获取光标处语义补全项列表
  Future<List<LspCompletionItem>> getCompletions(
    String filePath,
    int line,
    int character,
  ) async {
    final guestUri = _toGuestUri(filePath);
    if (!client.isClosed && _isInitialized) {
      try {
        final res = await client.sendRequest('textDocument/completion', {
          'textDocument': {'uri': guestUri},
          'position': {'line': line, 'character': character},
        });

        if (res is List) {
          return res
              .whereType<Map<String, dynamic>>()
              .map((item) => LspCompletionItem.fromJson(item))
              .toList();
        } else if (res is Map && res['items'] is List) {
          final items = res['items'] as List;
          return items
              .whereType<Map<String, dynamic>>()
              .map((item) => LspCompletionItem.fromJson(item))
              .toList();
        }
      } catch (e) {
        debugPrint('[LspSession] 获取补全失败: $e');
      }
    }
    return const [];
  }

  /// 获取指定错误或位置的代码修复操作（QuickFix）
  Future<List<LspCodeAction>> getCodeActions(
    String filePath,
    LspRange range,
    List<LspDiagnostic> diagnostics,
  ) async {
    if (!client.isClosed && _isInitialized) {
      try {
        final res = await client.sendRequest('textDocument/codeAction', {
          'textDocument': {'uri': _toGuestUri(filePath)},
          'range': range.toJson(),
          'context': {
            'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
            'only': ['quickfix'],
          },
        });

        if (res is List) {
          return res
              .whereType<Map<String, dynamic>>()
              .map((a) => LspCodeAction.fromJson(a))
              .toList();
        }
      } catch (e) {
        debugPrint('[LspSession] 获取 CodeAction 失败: $e');
      }
    }
    return const [];
  }

  /// 转换宿主文件路径为容器内部映射的 URI
  String _toGuestUri(String hostFilePath) {
    return PRootPathMapper.toGuestUri(hostFilePath, workspaceRoot);
  }

  /// 将容器内部的 URI 反向还原为宿主文件绝对路径
  String _fromGuestUriToHostPath(String guestUri) {
    return PRootPathMapper.fromGuestUriToHostPath(guestUri, workspaceRoot);
  }

  Future<void> close() async {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _fileVersions.clear();

    try {
      await client.sendRequest('shutdown', null, const Duration(seconds: 1));
      client.sendNotification('exit');
    } catch (_) {}

    client.close();
  }
}
