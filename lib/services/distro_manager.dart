import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/distro_info.dart';
import 'distro_installer.dart';

/// 容器启动配置数据
class ProotLaunchConfig {
  /// 可执行程序（proot 二进制路径或 host shell）
  final String executable;

  /// 启动参数
  final List<String> arguments;

  /// 环境变量
  final Map<String, String> environment;

  /// 初始工作目录
  final String workingDirectory;

  const ProotLaunchConfig({
    required this.executable,
    required this.arguments,
    required this.environment,
    required this.workingDirectory,
  });

  /// 格式化为命令行预览字符串
  String toCommandLine() {
    final argsStr = arguments.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
    return '$executable $argsStr';
  }
}

/// Linux 发行版管理器服务（单例模式，易扩展）
class DistroManager {
  static final DistroManager _instance = DistroManager._internal();
  factory DistroManager() => _instance;
  DistroManager._internal() {
    // 注册内置默认发行版
    for (final d in DistroInfo.defaults) {
      _distros[d.id] = d;
    }
  }

  /// 自定义覆盖根目录（主要用于测试）
  @visibleForTesting
  Directory? customBaseDir;

  /// 发行版注册表 `Map<id, DistroInfo>`
  final Map<String, DistroInfo> _distros = {};

  /// 获取所有已注册的发行版
  List<DistroInfo> listDistros() => _distros.values.toList();

  /// 获取指定发行版元数据
  DistroInfo? getDistro(String id) => _distros[id];

  /// 动态注册新的发行版（支持未来插件化或用户自定义导入）
  void registerDistro(DistroInfo distro) {
    _distros[distro.id] = distro;
  }

  /// 注销指定发行版
  void unregisterDistro(String id) {
    _distros.remove(id);
  }

  /// 获取发行版存储基础目录: `<app_dir>/distros`
  Future<Directory> getBaseDistrosDir() async {
    if (customBaseDir != null) {
      return customBaseDir!;
    }
    final appDir = await getApplicationSupportDirectory();
    final distrosDir = Directory(p.join(appDir.path, 'distros'));
    if (!distrosDir.existsSync()) {
      distrosDir.createSync(recursive: true);
    }
    return distrosDir;
  }

  /// 获取指定发行版的 Rootfs 解压目录: `<app_dir>/distros/<distroId>/rootfs`
  Future<Directory> getDistroRootDir(String distroId) async {
    final baseDir = await getBaseDistrosDir();
    return Directory(p.join(baseDir.path, distroId, 'rootfs'));
  }

  /// 检测指定发行版是否已安装就绪
  Future<bool> isInstalled(String distroId) async {
    // host 为宿主系统，无需安装
    if (distroId == 'host') return true;

    final rootDir = await getDistroRootDir(distroId);
    if (!rootDir.existsSync()) return false;

    // 检查关键目录和常用 shell 是否存在
    final hasEtc = Directory(p.join(rootDir.path, 'etc')).existsSync();
    final hasBin = Directory(p.join(rootDir.path, 'bin')).existsSync();
    return hasEtc && hasBin;
  }

  /// 安装发行版（优先从内置 asset 离线安装，支持进度回调）
  Future<void> installDistro(
    String distroId, {
    InstallProgressCallback? onProgress,
  }) async {
    final distro = getDistro(distroId);
    if (distro == null) {
      throw ArgumentError('未知的发行版 ID: $distroId');
    }

    if (distroId == 'host') {
      onProgress?.call(1.0, '本地 Shell 无需安装');
      return;
    }

    final targetDir = await getDistroRootDir(distroId);

    // 优先从内置 Asset 安装
    if (distro.assetPath != null) {
      onProgress?.call(0.02, '正在读取内置系统资源包...');
      final byteData = await rootBundle.load(distro.assetPath!);
      final bytes = byteData.buffer.asUint8List();

      await DistroInstaller.installFromBytes(
        tarGzBytes: bytes,
        targetDir: targetDir,
        onProgress: onProgress,
      );
      return;
    }

    // 远程下载模式扩展点
    if (distro.downloadUrl != null) {
      throw UnsupportedError('远程下载安装功能后续支持，请先使用内置版本');
    }

    throw StateError('该发行版既无内置 asset 也无下载链接: $distroId');
  }

  /// 从用户本地指定的 .tar.gz 文件安装自定义系统
  Future<void> installFromCustomTarGz(
    String distroId,
    File tarGzFile, {
    InstallProgressCallback? onProgress,
  }) async {
    final targetDir = await getDistroRootDir(distroId);
    final bytes = await tarGzFile.readAsBytes();

    await DistroInstaller.installFromBytes(
      tarGzBytes: bytes,
      targetDir: targetDir,
      onProgress: onProgress,
    );
  }

  /// 卸载并清除指定发行版的 rootfs 目录
  Future<void> uninstallDistro(String distroId) async {
    if (distroId == 'host') return;

    final baseDir = await getBaseDistrosDir();
    final distroDir = Directory(p.join(baseDir.path, distroId));
    if (distroDir.existsSync()) {
      distroDir.deleteSync(recursive: true);
    }
  }

  /// 构建 PRoot 容器启动命令与环境参数
  ///
  /// [distroId] 发行版标识符
  /// [workspacePath] 挂载的代码工程路径（挂载到容器内部的 /workspace）
  /// [prootPath] proot 二进制路径（默认可传入 'proot' 或设备内部特定路径）
  /// [customCommand] 自定义初始执行命令（默认进入交互式 login shell）
  Future<ProotLaunchConfig> buildLaunchConfig({
    required String distroId,
    String? workspacePath,
    String prootPath = 'proot',
    String? customCommand,
  }) async {
    final distro = getDistro(distroId) ?? DistroInfo.alpine;

    // 1. 本地 Shell 特殊处理：无需 PRoot
    if (distroId == 'host') {
      final initialDir = (workspacePath != null && Directory(workspacePath).existsSync())
          ? workspacePath
          : Directory.current.path;

      final args = customCommand != null ? ['-c', customCommand] : <String>[];
      return ProotLaunchConfig(
        executable: distro.defaultShell,
        arguments: args,
        environment: {
          'TERM': 'xterm-256color',
        },
        workingDirectory: initialDir,
      );
    }

    // 2. Linux 容器 (PRoot 隔离环境)
    final rootDir = await getDistroRootDir(distroId);
    final targetShell = distro.defaultShell;

    final args = <String>[
      '-0', // 模拟 root 权限 (uid 0)
      '-r', rootDir.path, // 根文件系统路径
      '-b', '/dev', // 挂载标准设备节点
      '-b', '/proc', // 挂载进程信息
      '-b', '/sys', // 挂载系统信息
    ];

    // 挂载工作区
    String containerWorkDir = '/root';
    if (workspacePath != null && Directory(workspacePath).existsSync()) {
      args.addAll(['-b', '$workspacePath:/workspace']);
      containerWorkDir = '/workspace';
    }

    // 设置容器内工作目录
    args.addAll(['-w', containerWorkDir]);

    // 登录 Shell 或自定义命令
    if (customCommand != null && customCommand.isNotEmpty) {
      args.addAll([targetShell, '-c', customCommand]);
    } else {
      args.addAll([targetShell, '-l']);
    }

    final env = <String, String>{
      'HOME': '/root',
      'USER': 'root',
      'TERM': 'xterm-256color',
      'LANG': 'C.UTF-8',
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'TMPDIR': '/tmp',
    };

    return ProotLaunchConfig(
      executable: prootPath,
      arguments: args,
      environment: env,
      workingDirectory: containerWorkDir,
    );
  }
}
