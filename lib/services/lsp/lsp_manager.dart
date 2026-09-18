import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../models/distro_manifest.dart';
import '../distro_manager.dart';
import '../internal_engine_service.dart';
import '../lsp_config_service.dart';
import 'cpp_project_helper.dart';
import 'lsp_client.dart';
import 'lsp_session.dart';

/// 全局语言服务（LSP）调度管理中心
class LspManager extends ChangeNotifier {
  static final LspManager instance = LspManager._();
  LspManager._();

  final Map<String, LspSession> _activeSessions = {};
  final Map<String, Future<LspSession?>> _startingSessions = {};

  /// 获取或拉起匹配当前文件的语言服务会话
  Future<LspSession?> getOrCreateSession(String filePath, {String? workspaceRoot}) async {
    final ext = p.extension(filePath);
    final filename = p.basename(filePath);
    if (ext.isEmpty && filename.isEmpty) return null;

    final config = LspConfigService.instance.findByExtension(ext, filename: filename);
    if (config == null || !config.enabled) return null;

    // 检查是否已有存活会话
    final existing = _activeSessions[config.id];
    if (existing != null && !existing.client.isClosed) {
      return existing;
    }

    // 防止并发重复拉起同一个服务
    if (_startingSessions.containsKey(config.id)) {
      return _startingSessions[config.id];
    }

    final future = _startSession(config, filePath, workspaceRoot);
    _startingSessions[config.id] = future;

    try {
      final session = await future;
      if (session != null) {
        _activeSessions[config.id] = session;
      }
      return session;
    } finally {
      _startingSessions.remove(config.id);
    }
  }

  Future<LspSession?> _startSession(
    dynamic config,
    String filePath,
    String? workspaceRoot,
  ) async {
    try {
      // 1. 检查 Ubuntu 引擎和命令是否就绪
      final engineInstalled = await InternalEngineService.instance.isEngineInstalled();
      if (!engineInstalled) return null;

      final cmdInstalled = await InternalEngineService.instance.isCommandInstalled(config.serverCommand);
      if (!cmdInstalled) {
        debugPrint('[LspManager] 服务命令未安装: ${config.serverCommand}');
        return null;
      }

      final effectiveRoot = workspaceRoot ?? p.dirname(filePath);
      
      // 若为 C/C++ 项目，在启动 clangd 前确保推导并配置头文件与编译标志
      if (config.id == 'c_cpp') {
        try {
          await CppProjectHelper.ensureCompileFlags(effectiveRoot);
        } catch (e) {
          debugPrint('[LspManager] 确保 C/C++ 编译标志失败: $e');
        }
      }

      final rootfs = await InternalEngineService.instance.getRootfsDir();

      final effectiveArgs = List<String>.from(config.serverArgs ?? const []);
      if (config.id == 'c_cpp') {
        if (!effectiveArgs.any((a) => a.startsWith('--query-driver'))) {
          effectiveArgs.add('--query-driver=/usr/bin/*,/usr/local/bin/*');
        }
        if (!effectiveArgs.any((a) => a.startsWith('--header-insertion'))) {
          effectiveArgs.add('--header-insertion=iwyu');
        }
      }

      final cmdWithArgs = [
        config.serverCommand,
        ...effectiveArgs,
      ].join(' ');

      final launchConfig = await DistroManager().buildLaunchConfig(
        systemName: DistroRepository.defaultSystemName,
        customRootDir: rootfs,
        workspacePath: effectiveRoot,
        customCommand: cmdWithArgs,
      );

      debugPrint('[LspManager] 正在拉起语言服务进程: ${launchConfig.toCommandLine()}');

      final process = await Process.start(
        launchConfig.executable,
        launchConfig.arguments,
        environment: launchConfig.environment,
        workingDirectory: launchConfig.workingDirectory,
      );

      final client = LspClient(process);
      final session = LspSession(
        client: client,
        config: config,
        workspaceRoot: effectiveRoot,
      );

      final success = await session.initialize();
      if (success) {
        notifyListeners();
        return session;
      } else {
        await session.close();
        return null;
      }
    } catch (e) {
      debugPrint('[LspManager] 拉起语言服务异常: $e');
      return null;
    }
  }

  /// 获取当前已存活的会话（不触发异步拉起）
  LspSession? getExistingSession(String filePath) {
    final ext = p.extension(filePath);
    final filename = p.basename(filePath);
    if (ext.isEmpty && filename.isEmpty) return null;
    final config = LspConfigService.instance.findByExtension(ext, filename: filename);
    if (config == null) return null;
    final session = _activeSessions[config.id];
    if (session != null && !session.client.isClosed) {
      return session;
    }
    return null;
  }

  /// 响应文档打开
  Future<void> onFileOpened(String filePath, String text, {String? workspaceRoot}) async {
    final session = await getOrCreateSession(filePath, workspaceRoot: workspaceRoot);
    session?.didOpen(filePath, text);
  }

  /// 响应文档编辑（带防抖通知）
  void onFileChanged(String filePath, String fullText) {
    final session = getExistingSession(filePath);
    session?.didChange(filePath, fullText);
  }

  /// 响应文档关闭
  void onFileClosed(String filePath) {
    final session = getExistingSession(filePath);
    session?.didClose(filePath);
  }

  /// 停用并释放指定语言配置的后台服务会话
  Future<void> stopSession(String configId) async {
    // 1. 若当前正在异步拉起中，等待启动完成后再关闭
    if (_startingSessions.containsKey(configId)) {
      try {
        final session = await _startingSessions[configId];
        await session?.close();
      } catch (_) {}
      _startingSessions.remove(configId);
    }

    // 2. 关闭并清理已存活的会话
    final session = _activeSessions.remove(configId);
    if (session != null) {
      try {
        await session.close();
      } catch (e) {
        debugPrint('[LspManager] 关闭语言会话异常 ($configId): $e');
      }
      notifyListeners();
    }
  }

  /// 关闭并回收所有后台语言服务进程
  Future<void> disposeAll() async {
    for (final session in _activeSessions.values) {
      await session.close();
    }
    _activeSessions.clear();
    _startingSessions.clear();
    notifyListeners();
  }
}
