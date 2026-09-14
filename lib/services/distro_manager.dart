import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/distro_manifest.dart';
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

/// Linux 发行版家族分类（用于包管理器与工具链自动适配）
enum DistroFamily {
  alpine,
  ubuntu,
  debian,
  arch,
  fedora,
  unknown,
}

/// Linux 发行版与多系统实例管理器服务（单例模式，易扩展）
class DistroManager {
  static final DistroManager _instance = DistroManager._internal();
  factory DistroManager() => _instance;
  DistroManager._internal();

  /// 自定义覆盖根目录（主要用于测试）
  @visibleForTesting
  Directory? customBaseDir;

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

  /// 获取指定系统实例的 Rootfs 解压目录: `<app_dir>/distros/<systemName>/rootfs`
  Future<Directory> getSystemRootDir(String systemName) async {
    final baseDir = await getBaseDistrosDir();
    return Directory(p.join(baseDir.path, systemName, 'rootfs'));
  }

  /// 获取当前已创建并解压成功的系统实例列表（文件夹名称即系统名称）
  Future<List<String>> listInstalledSystems() async {
    final baseDir = await getBaseDistrosDir();
    if (!baseDir.existsSync()) return [];

    final List<String> systems = [];
    final entities = baseDir.listSync(followLinks: false);
    for (final entity in entities) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        // 若子目录存在 rootfs/ 且包含基础目录结构，则视为有效系统实例
        final rootDir = Directory(p.join(entity.path, 'rootfs'));
        if (rootDir.existsSync()) {
          systems.add(name);
        }
      }
    }
    // 按名称字母排序
    systems.sort((a, b) => a.compareTo(b));
    return systems;
  }

  /// 是否存在任何已安装的系统
  Future<bool> hasAnySystem() async {
    final systems = await listInstalledSystems();
    return systems.isNotEmpty;
  }

  /// 检测指定系统实例是否已安装就绪
  Future<bool> isSystemInstalled(String systemName) async {
    if (systemName == 'host') return true;

    final rootDir = await getSystemRootDir(systemName);
    if (!rootDir.existsSync()) return false;

    final hasEtc = Directory(p.join(rootDir.path, 'etc')).existsSync();
    final hasBin = Directory(p.join(rootDir.path, 'bin')).existsSync();
    return hasEtc && hasBin;
  }

  /// 自动探测指定已安装系统所属的发行版家族（Alpine / Ubuntu / Debian / Arch / Fedora / Unknown）
  Future<DistroFamily> detectDistroFamily(String systemName) async {
    if (systemName == 'host') return DistroFamily.unknown;

    final rootDir = await getSystemRootDir(systemName);
    if (!rootDir.existsSync()) return DistroFamily.unknown;

    final etcDir = Directory(p.join(rootDir.path, 'etc'));
    if (!etcDir.existsSync()) return DistroFamily.unknown;

    // 1. Alpine Linux (apk / alpine-release)
    if (Directory(p.join(etcDir.path, 'apk')).existsSync() ||
        File(p.join(etcDir.path, 'alpine-release')).existsSync() ||
        File(p.join(rootDir.path, 'sbin', 'apk')).existsSync()) {
      return DistroFamily.alpine;
    }

    // 2. Ubuntu 与 Debian (apt / dpkg)
    final aptDir = Directory(p.join(etcDir.path, 'apt'));
    if (aptDir.existsSync() || File(p.join(rootDir.path, 'usr', 'bin', 'apt-get')).existsSync()) {
      final ubuntuSources = File(p.join(aptDir.path, 'sources.list.d', 'ubuntu.sources'));
      final osRelease = File(p.join(etcDir.path, 'os-release'));
      var isUbuntu = ubuntuSources.existsSync();
      if (!isUbuntu && osRelease.existsSync()) {
        try {
          isUbuntu = osRelease.readAsStringSync().toLowerCase().contains('ubuntu');
        } catch (_) {}
      }
      return isUbuntu ? DistroFamily.ubuntu : DistroFamily.debian;
    }

    // 3. Arch Linux (pacman)
    if (Directory(p.join(etcDir.path, 'pacman.d')).existsSync() ||
        File(p.join(etcDir.path, 'arch-release')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'pacman')).existsSync()) {
      return DistroFamily.arch;
    }

    // 4. Fedora (dnf / yum / fedora-release)
    if (Directory(p.join(etcDir.path, 'yum.repos.d')).existsSync() ||
        File(p.join(etcDir.path, 'fedora-release')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'dnf')).existsSync()) {
      return DistroFamily.fedora;
    }

    // 5. 其他未识别的自定义系统
    return DistroFamily.unknown;
  }

  /// 校验系统名称是否合法且未被占用
  Future<void> validateSystemName(String systemName) async {
    final trimmed = systemName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('系统名称不能为空');
    }
    // 限制字符集：字母、数字、下划线、短横线、中文字符
    final validRegex = RegExp(r'^[\w\u4e00-\u9fa5\-_]+$');
    if (!validRegex.hasMatch(trimmed)) {
      throw ArgumentError('系统名称只能包含字母、数字、中文、下划线或短横线');
    }

    final systems = await listInstalledSystems();
    if (systems.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('已存在同名系统 "$trimmed"，请使用其他名称');
    }
  }

  /// 从应用内置资源导入 Ubuntu 24.04 Linux 系统实例
  ///
  /// [systemName] 系统名称（默认为 'ubuntu'，同一个 rootfs 包可创建多个系统）
  Future<void> importBuiltinUbuntu({
    required String systemName,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await validateSystemName(systemName);

    final assetPath = DistroRepository.builtinUbuntuAssetPath;
    onProgress?.call(0.02, '正在读取应用内置 Ubuntu 系统资源包...');
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final targetDir = await getSystemRootDir(systemName);

    await DistroInstaller.installFromBytes(
      tarGzBytes: bytes,
      targetDir: targetDir,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// 从应用内置资源导入 Alpine Linux 系统实例（保留备用）
  ///
  /// [systemName] 系统名称（默认为 'alpine'，同一个 rootfs 包可创建多个系统）
  Future<void> importBuiltinAlpine({
    required String systemName,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await validateSystemName(systemName);

    final assetPath = DistroRepository.builtinAlpineAssetPath;
    onProgress?.call(0.02, '正在读取应用内置 Alpine 系统资源包...');
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final targetDir = await getSystemRootDir(systemName);

    await DistroInstaller.installFromBytes(
      tarGzBytes: bytes,
      targetDir: targetDir,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// 从用户本地指定的 .tar.gz / .tar.xz 压缩包导入外部系统实例
  Future<void> importFromCustomTarGz({
    required String systemName,
    required File tarGzFile,
    InstallProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    await validateSystemName(systemName);

    if (!tarGzFile.existsSync()) {
      throw ArgumentError('所选压缩包文件不存在: ${tarGzFile.path}');
    }

    final targetDir = await getSystemRootDir(systemName);

    await DistroInstaller.installFromFile(
      archiveFile: tarGzFile,
      targetDir: targetDir,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// 高危操作：彻底删除指定系统实例及其所有存储数据
  Future<void> deleteSystem(String systemName) async {
    if (systemName == 'host') return;

    final baseDir = await getBaseDistrosDir();
    final systemDir = Directory(p.join(baseDir.path, systemName));
    if (!systemDir.existsSync()) return;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        if (!systemDir.existsSync()) break;
        await systemDir.delete(recursive: true);
        break;
      } catch (e) {
        if (Platform.isLinux || Platform.isAndroid) {
          try {
            await Process.run('chmod', ['-R', '777', systemDir.path]);
          } catch (_) {}
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
        if (attempt == 2) {
          try {
            if (systemDir.existsSync()) {
              systemDir.deleteSync(recursive: true);
            }
          } catch (_) {}
        }
      }
    }
  }

  static const MethodChannel _nativeChannel = MethodChannel('com.example.code_editor/native');
  String? _cachedProotPath;
  String? _cachedNativeDir;

  /// 获取 App 原生动态库目录路径（用于定位 libproot.so 与 libtalloc.so）
  Future<String?> getNativeLibraryDir() async {
    if (_cachedNativeDir != null) return _cachedNativeDir;
    if (Platform.isAndroid) {
      try {
        final dir = await _nativeChannel.invokeMethod<String>('getNativeLibraryDir');
        if (dir != null && dir.isNotEmpty) {
          _cachedNativeDir = dir;
          return dir;
        }
      } catch (e) {
        debugPrint('获取原生动态库目录失败: $e');
      }
    }
    return null;
  }

  /// 获取 proot 可执行程序的物理路径（优先检测 nativeLibraryDir/libproot.so）
  Future<String> getProotExecutablePath() async {
    if (_cachedProotPath != null && File(_cachedProotPath!).existsSync()) {
      return _cachedProotPath!;
    }

    final nativeDir = await getNativeLibraryDir();
    if (nativeDir != null) {
      final soPath = p.join(nativeDir, 'libproot.so');
      if (File(soPath).existsSync()) {
        _cachedProotPath = soPath;
        return soPath;
      }
    }

    return 'proot';
  }

  /// 构建 PRoot 容器启动命令与环境参数
  ///
  /// [systemName] 当前选择的系统名称
  /// [workspacePath] 挂载的代码工程路径（挂载到容器内部的 /workspace）
  /// [prootPath] proot 二进制路径
  /// [customCommand] 自定义执行命令
  Future<ProotLaunchConfig> buildLaunchConfig({
    required String systemName,
    String? workspacePath,
    String prootPath = 'proot',
    String? customCommand,
  }) async {
    // 1. 本地 Shell 特殊处理
    if (systemName == 'host') {
      final initialDir = (workspacePath != null && Directory(workspacePath).existsSync())
          ? workspacePath
          : Directory.current.path;

      final args = customCommand != null ? ['-c', customCommand] : <String>['-i'];
      return ProotLaunchConfig(
        executable: '/system/bin/sh',
        arguments: args,
        environment: {
          'TERM': 'xterm-256color',
          'SHELL': '/system/bin/sh',
        },
        workingDirectory: initialDir,
      );
    }

    // 2. Linux 容器 (PRoot 隔离环境)
    final rootDir = await getSystemRootDir(systemName);
    final nativeDir = await getNativeLibraryDir();
    final effectiveProot = (prootPath == 'proot') ? await getProotExecutablePath() : prootPath;
    final targetShell = _resolveTargetShell(rootDir);

    // 确保容器内 DNS 配置存在（对标 proot-distro，保证网络连通与 apk/curl 正常解析）
    await _ensureGuestDns(rootDir);

    // 清理此前异常中断留下的陈旧锁文件（如 /etc/group.lock，防止 groupadd/useradd 报错）
    _cleanStaleLocks(rootDir);

    // 确保 Android 宿主特权/辅助组映射与 .hushlogin 存在（解决 groups: cannot find name for group ID 警告）
    await _ensureHostGroups(rootDir);

    // 确保容器内具备标准 SSL CA 证书（解决 APT/Git/Curl 访问 HTTPS 时的证书校验失败）
    await DistroInstaller.ensureCaCertificates(rootDir);

    // 确保 Java 运行时动态链接配置就绪（解决 /usr/bin/java 符号链接找不到 libjli.so）
    await DistroInstaller.ensureJavaConfiguration(rootDir);

    // 确保独立的 /dev/shm 目录存在（对标 proot-distro shm.py，解决 POSIX 共享内存缺失）
    final shmDir = await _ensureShmDir(systemName);

    // 确保独立的 .l2s 硬链接目录存在（对标 proot-distro --link2symlink 规范）
    final l2sDir = await _ensureL2sDir(systemName);

    // 确保独立的 sysdata 桩目录存在（对标 proot-distro sysdata.py，提供 SELinux 与 Proc 补充数据）
    final sysdataDir = await _ensureSysdataDir(systemName);

    String tmpPath = '/tmp';
    try {
      tmpPath = (await getTemporaryDirectory()).path;
    } catch (_) {
      tmpPath = '/tmp';
    }

    final args = <String>[
      '--kill-on-exit',
      '--link2symlink',
      // SysV IPC（共享内存/信号量/消息队列）用户态模拟：Android 的 app seccomp 策略把
      // shmget/semget/msgget 全部返回 ENOSYS，PRoot 用 libandroid-shmem 在容器内模拟这一套。
      // 需要 jniLibs 里同时提供 libandroid-shmem.so（proot 的 NEEDED 依赖）。
      '--sysvipc',
      '-0', // 模拟 root 权限 (uid 0)
      '-k', '5.4.0-proot', // 伪装内核版本（解决 musl libc 调用 clone3/ppoll 时的 Function not implemented）
      '-L', // 修复 lstat 符号链接大小属性
      '-r', rootDir.path, // 根文件系统路径
      '-b', '/dev', // 挂载标准设备节点（宿主已有 /dev/stdin, stdout, stderr 等软链接）
      '-b', '/dev/urandom:/dev/random', // 补充随机数设备节点
      if (shmDir != null) ...['-b', '${shmDir.path}:/dev/shm'], // 挂载独立 POSIX 共享内存
      '-b', '/proc', // 挂载进程信息
      '-b', '/sys', // 挂载系统信息
      if (sysdataDir != null) ...[
        '-b', '${p.join(sysdataDir.path, 'sys_empty')}:/sys/fs/selinux',
        '-b', '${p.join(sysdataDir.path, 'sysctl_entry_cap_last_cap')}:/proc/sys/kernel/cap_last_cap',
        '-b', '${p.join(sysdataDir.path, 'sysctl_inotify_max_user_watches')}:/proc/sys/fs/inotify/max_user_watches',
      ],
    ];

    if (Directory(tmpPath).existsSync()) {
      args.addAll(['-b', '$tmpPath:/tmp']);
    }

    // 挂载工作区
    String containerWorkDir = '/root';
    if (workspacePath != null && Directory(workspacePath).existsSync()) {
      args.addAll(['-b', '$workspacePath:/workspace']);
      containerWorkDir = '/workspace';
    }

    // 设置容器内工作目录
    args.addAll(['-w', containerWorkDir]);

    // 用 /usr/bin/env -i 彻底隔离宿主（Android app 进程）继承的环境变量，
    // 只注入标准纯净的容器环境变量；若修复 Shim 已部署则注入 LD_PRELOAD。
    // Shim 的两项职责见 DistroInstaller.ensureSeccompShim 的注释。
    await DistroInstaller.ensureSeccompShim(rootDir);
    final shimFile = File(p.join(rootDir.path, 'lib', 'libfix_seccomp.so'));
    final hasShim = shimFile.existsSync();

    // 自动检测并注入 JAVA_HOME
    String? guestJavaHome;
    final jvmDir = Directory(p.join(rootDir.path, 'usr', 'lib', 'jvm'));
    if (jvmDir.existsSync()) {
      try {
        final defaultJava = Directory(p.join(jvmDir.path, 'default-java'));
        if (defaultJava.existsSync()) {
          guestJavaHome = '/usr/lib/jvm/default-java';
        } else {
          final entries = jvmDir.listSync().whereType<Directory>().toList();
          if (entries.isNotEmpty) {
            entries.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
            final selected = entries.firstWhere(
              (d) => p.basename(d.path).startsWith('java-'),
              orElse: () => entries.first,
            );
            guestJavaHome = '/usr/lib/jvm/${p.basename(selected.path)}';
          }
        }
      } catch (_) {}
    }

    final guestEnvArgs = <String>[
      '/usr/bin/env',
      '-i',
      'HOME=/root',
      'USER=root',
      'SHELL=$targetShell',
      'TERM=xterm-256color',
      'COLORTERM=truecolor',
      'LANG=C.UTF-8',
      if (guestJavaHome != null) 'JAVA_HOME=$guestJavaHome',
      if (guestJavaHome != null)
        'PATH=$guestJavaHome/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
      else
        'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      if (hasShim) 'LD_PRELOAD=/lib/libfix_seccomp.so',
    ];

    args.addAll(guestEnvArgs);

    // 登录 Shell 或自定义命令
    if (customCommand != null && customCommand.isNotEmpty) {
      args.addAll([targetShell, '-c', customCommand]);
    } else {
      args.addAll([targetShell, '-l', '-i']);
    }

    final env = <String, String>{
      'HOME': '/root',
      'USER': 'root',
      'SHELL': targetShell,
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      'LANG': 'C.UTF-8',
      if (guestJavaHome != null) 'JAVA_HOME': guestJavaHome,
      if (guestJavaHome != null)
        'PATH': '$guestJavaHome/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
      else
        'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'TMPDIR': tmpPath,
      'PROOT_TMP_DIR': tmpPath,
      if (l2sDir != null) 'PROOT_L2S_DIR': l2sDir.path,
      if (nativeDir != null) 'LD_LIBRARY_PATH': nativeDir,
    };

    // Process.start 的宿主工作目录必须在 Android 宿主真实存在
    final hostWorkDir = rootDir.path;

    return ProotLaunchConfig(
      executable: effectiveProot,
      arguments: args,
      environment: env,
      workingDirectory: hostWorkDir,
    );
  }

  /// 确保容器内具备标准 DNS 解析文件 `/etc/resolv.conf`（对标 proot-distro）
  Future<void> _ensureGuestDns(Directory rootDir) async {
    try {
      final etcDir = Directory(p.join(rootDir.path, 'etc'));
      if (!etcDir.existsSync()) {
        etcDir.createSync(recursive: true);
      }
      final resolvConf = File(p.join(etcDir.path, 'resolv.conf'));
      if (!resolvConf.existsSync() || (await resolvConf.length()) == 0) {
        // "可达优先"排序：国内公共 DNS 在前（8.8.8.8/1.1.1.1 在国内常被丢包，
        // 排在首位会让 musl/glibc 解析器先等一次超时）。与 DistroInstaller
        // 的 guestResolvConf 保持一致。
        await resolvConf.writeAsString(
          DistroInstaller.guestResolvConf,
          flush: true,
        );
      }
    } catch (e) {
      debugPrint('配置容器 DNS 失败 (非阻塞): $e');
    }
  }

  /// 确保容器实例拥有独立的 POSIX 共享内存目录（对标 proot-distro shm.py）
  Future<Directory?> _ensureShmDir(String systemName) async {
    try {
      final baseDir = await getBaseDistrosDir();
      final shmDir = Directory(p.join(baseDir.path, systemName, 'shm'));
      if (!shmDir.existsSync()) {
        shmDir.createSync(recursive: true);
      }
      return shmDir;
    } catch (e) {
      debugPrint('创建容器 shm 目录失败 (非阻塞): $e');
      return null;
    }
  }

  /// 确保容器实例拥有独立的 .l2s 硬链接跟踪目录（对标 proot-distro login/__init__.py）
  Future<Directory?> _ensureL2sDir(String systemName) async {
    try {
      final baseDir = await getBaseDistrosDir();
      final l2sDir = Directory(p.join(baseDir.path, systemName, '.l2s'));
      if (!l2sDir.existsSync()) {
        l2sDir.createSync(recursive: true);
      }
      return l2sDir;
    } catch (e) {
      debugPrint('创建容器 .l2s 目录失败 (非阻塞): $e');
      return null;
    }
  }

  /// 确保容器实例拥有独立的 sysdata 桩目录与 SELinux 覆盖节点（对标 proot-distro sysdata.py）
  Future<Directory?> _ensureSysdataDir(String systemName) async {
    try {
      final baseDir = await getBaseDistrosDir();
      final sysdataDir = Directory(p.join(baseDir.path, systemName, 'sysdata'));
      if (!sysdataDir.existsSync()) {
        sysdataDir.createSync(recursive: true);
      }

      // 1. 空目录用于覆盖 /sys/fs/selinux（禁用 selinux 检测）
      final emptyDir = Directory(p.join(sysdataDir.path, 'sys_empty'));
      if (!emptyDir.existsSync()) {
        emptyDir.createSync(recursive: true);
      }

      // 2. /proc/sys/kernel/cap_last_cap 桩
      final capFile = File(p.join(sysdataDir.path, 'sysctl_entry_cap_last_cap'));
      if (!capFile.existsSync()) {
        capFile.writeAsStringSync('40\n');
      }

      // 3. /proc/sys/fs/inotify/max_user_watches 桩
      final inotifyFile = File(p.join(sysdataDir.path, 'sysctl_inotify_max_user_watches'));
      if (!inotifyFile.existsSync()) {
        inotifyFile.writeAsStringSync('4096\n');
      }

      return sysdataDir;
    } catch (e) {
      debugPrint('创建容器 sysdata 目录失败 (非阻塞): $e');
      return null;
    }
  }

  /// 智能选择不同 Linux 发行版最适配的交互式 Shell：
  /// 1. 优先读取 /etc/passwd 中 root 用户指定的默认登录 Shell（如用户自行切换了 zsh/fish）；
  /// 2. 若配置为 /bin/sh，但在存在 GNU Readline 支持的更好交互 Shell（如 /bin/bash）时优先升级至 bash，
  ///    彻底解决 Ubuntu/Debian 等发行版 /bin/sh (dash) 缺少行编辑与 Readline 支持的问题；
  /// 3. 若系统中无 bash（如原版最小化 Alpine），则使用 /bin/ash 或 /bin/sh；
  /// 4. 支持 /usr/bin/bash、/usr/bin/zsh 等现代 Linux UsrMerge 单一根目录结构。
  String _resolveTargetShell(Directory rootDir) {
    String? rootPasswdShell;
    final passwdFile = File(p.join(rootDir.path, 'etc', 'passwd'));
    if (passwdFile.existsSync()) {
      try {
        final lines = passwdFile.readAsLinesSync();
        for (final line in lines) {
          if (line.startsWith('root:')) {
            final parts = line.split(':');
            if (parts.length >= 7) {
              final sh = parts[6].trim();
              if (sh.isNotEmpty) {
                rootPasswdShell = sh;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    final hasBash = File(p.join(rootDir.path, 'bin', 'bash')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'bash')).existsSync();
    final hasZsh = File(p.join(rootDir.path, 'bin', 'zsh')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'zsh')).existsSync();
    final hasAsh = File(p.join(rootDir.path, 'bin', 'ash')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'ash')).existsSync();

    // 如果 passwd 里配置了非 /bin/sh 的具体 shell（如 /bin/bash, /bin/zsh, /bin/ash, /usr/bin/fish）且物理文件存在，遵从系统配置
    if (rootPasswdShell != null &&
        rootPasswdShell != '/bin/sh' &&
        rootPasswdShell != '/usr/bin/sh') {
      final shellRel = rootPasswdShell.startsWith('/') ? rootPasswdShell.substring(1) : rootPasswdShell;
      if (File(p.join(rootDir.path, shellRel)).existsSync()) {
        return rootPasswdShell;
      }
    }

    // 默认回退链：bash (Ubuntu/Debian/Arch/Fedora) -> zsh -> ash (Alpine) -> sh
    if (hasBash) {
      return '/bin/bash';
    } else if (hasZsh) {
      return '/bin/zsh';
    } else if (hasAsh) {
      return '/bin/ash';
    }
    return '/bin/sh';
  }

  /// 保证 Android 宿主分配给当前 App 进程的所有辅助 GID 在容器 /etc/group 中均有注册，
  /// 并在 /root 下创建 .hushlogin，彻底消除 login 时输出
  /// "groups: cannot find name for group ID XXX" 等警告。
  Future<void> _ensureHostGroups(Directory rootDir) async {
    try {
      if (!rootDir.existsSync()) return;
      final etcDir = Directory(p.join(rootDir.path, 'etc'));
      if (!etcDir.existsSync()) {
        try {
          etcDir.createSync(recursive: true);
        } catch (_) {}
      }

      final groupFile = File(p.join(etcDir.path, 'group'));
      final existingGids = <int>{};
      String existingContent = '';
      if (groupFile.existsSync()) {
        existingContent = groupFile.readAsStringSync();
        for (final line in existingContent.split('\n')) {
          final parts = line.split(':');
          if (parts.length >= 3) {
            final gid = int.tryParse(parts[2].trim());
            if (gid != null) existingGids.add(gid);
          }
        }
      }

      // 获取宿主当前进程拥有的所有 GID
      final targetGids = <int>{
        // 常见 Android 特权/网络与存储辅助 GID
        1015, // sdcard_rw
        1028, // sdcard_r
        1077, // ext_data_rw
        3003, // inet
        3004, // net_raw
        3005, // net_admin
        9997, // everybody
      };

      // 从 /proc/self/status 动态提取当前真实附加的 Groups
      final procStatus = File('/proc/self/status');
      if (procStatus.existsSync()) {
        try {
          final lines = procStatus.readAsLinesSync();
          for (final line in lines) {
            if (line.startsWith('Groups:')) {
              final gids = line.substring(7).trim().split(RegExp(r'\s+'));
              for (final s in gids) {
                final val = int.tryParse(s);
                if (val != null) targetGids.add(val);
              }
            }
          }
        } catch (_) {}
      }

      final buffer = StringBuffer();
      for (final gid in targetGids) {
        if (!existingGids.contains(gid)) {
          final groupName = _androidAidGroupName(gid);
          buffer.writeln('$groupName:x:$gid:');
        }
      }

      // 保证常见系统服务所需的用户组存在（如 dbus 所需的 messagebus GID 101）
      if (!existingGids.contains(101) && !existingContent.contains('messagebus:')) {
        buffer.writeln('messagebus:x:101:');
      }

      if (buffer.isNotEmpty) {
        if (!groupFile.existsSync()) {
          groupFile.writeAsStringSync(buffer.toString());
        } else {
          final separator = existingContent.endsWith('\n') || existingContent.isEmpty ? '' : '\n';
          groupFile.writeAsStringSync('$separator${buffer.toString()}', mode: FileMode.append);
        }
      }

      // 静默模式：创建 /root/.hushlogin 屏蔽 motd / 登录杂乱信息
      final rootHome = Directory(p.join(rootDir.path, 'root'));
      if (!rootHome.existsSync()) {
        try {
          rootHome.createSync(recursive: true);
        } catch (_) {}
      }
      final hushFile = File(p.join(rootHome.path, '.hushlogin'));
      if (!hushFile.existsSync()) {
        try {
          hushFile.createSync();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('配置容器辅助用户组失败 (非阻塞): $e');
    }
  }

  /// 清理此前异常崩溃或中断留下的陈旧锁文件（防止 groupadd/useradd 等报 /etc/*.lock 锁占用或找不到）
  void _cleanStaleLocks(Directory rootDir) {
    try {
      final etcDir = Directory(p.join(rootDir.path, 'etc'));
      if (etcDir.existsSync()) {
        for (final entry in etcDir.listSync(followLinks: false)) {
          final name = p.basename(entry.path);
          if (name.endsWith('.lock') ||
              name.startsWith('group.') ||
              name.startsWith('passwd.') ||
              name.startsWith('shadow.') ||
              name.startsWith('gshadow.')) {
            try {
              entry.deleteSync(recursive: true);
              debugPrint('[DistroManager] 清理陈旧锁文件: ${entry.path}');
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[DistroManager] 清理陈旧锁文件异常 (非阻塞): $e');
    }
  }

  static String _androidAidGroupName(int gid) {
    switch (gid) {
      case 1015:
        return 'aid_sdcard_rw';
      case 1028:
        return 'aid_sdcard_r';
      case 1077:
        return 'aid_ext_data_rw';
      case 3003:
        return 'aid_inet';
      case 3004:
        return 'aid_net_raw';
      case 3005:
        return 'aid_net_admin';
      case 9997:
        return 'aid_everybody';
      default:
        return 'aid_$gid';
    }
  }
}
