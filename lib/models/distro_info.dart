/// Linux 发行版安装状态
enum DistroStatus {
  /// 未安装
  notInstalled,

  /// 正在安装/解压中
  installing,

  /// 已安装就绪
  installed,

  /// 安装或运行异常
  error,
}

/// Linux 发行版元数据模型，具备高扩展性
class DistroInfo {
  /// 唯一标识符，例如 'alpine', 'debian', 'ubuntu', 'host'
  final String id;

  /// 显示名称，例如 'Alpine Linux'
  final String name;

  /// 版本号，例如 '3.20.3'
  final String version;

  /// 描述信息
  final String description;

  /// 默认登录 Shell，例如 '/bin/sh', '/bin/bash'
  final String defaultShell;

  /// 包管理器名称，例如 'apk', 'apt'
  final String packageManager;

  /// 支持的硬件架构，例如 ['aarch64', 'arm64-v8a']
  final List<String> supportedArchs;

  /// 内置应用资源路径（如有，可离线解压）
  final String? assetPath;

  /// 远程下载地址（支持网络按需下载扩展）
  final String? downloadUrl;

  /// 是否为官方内置预设
  final bool isBuiltin;

  /// 图标名称标识
  final String iconName;

  const DistroInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.defaultShell = '/bin/sh',
    this.packageManager = 'apk',
    this.supportedArchs = const ['aarch64', 'arm64-v8a', 'all'],
    this.assetPath,
    this.downloadUrl,
    this.isBuiltin = true,
    this.iconName = 'terminal',
  });

  /// 预设：Alpine Linux (轻量极速，内置 asset)
  static const DistroInfo alpine = DistroInfo(
    id: 'alpine',
    name: 'Alpine Linux',
    version: '3.20.3',
    description: '轻量快速的 Linux 发行版，体积仅约 4MB，内置 apk 包管理器',
    defaultShell: '/bin/sh',
    packageManager: 'apk',
    supportedArchs: ['aarch64', 'arm64-v8a'],
    assetPath: 'assets/distros/alpine-minirootfs-3.20.3-aarch64.tar.gz',
    isBuiltin: true,
    iconName: 'alpine',
  );

  /// 预设扩展：Debian GNU/Linux
  static const DistroInfo debian = DistroInfo(
    id: 'debian',
    name: 'Debian GNU/Linux',
    version: '12 (Bookworm)',
    description: '全能稳定的 Linux 发行版，标准 glibc 兼容，内置 apt 包管理器',
    defaultShell: '/bin/bash',
    packageManager: 'apt',
    supportedArchs: ['aarch64', 'x86_64'],
    downloadUrl: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/debian/bookworm/arm64/default/',
    isBuiltin: false,
    iconName: 'debian',
  );

  /// 预设扩展：Ubuntu
  static const DistroInfo ubuntu = DistroInfo(
    id: 'ubuntu',
    name: 'Ubuntu',
    version: '24.04 LTS',
    description: '应用与开发生态丰富的流行 Linux 发行版，内置 apt 包管理器',
    defaultShell: '/bin/bash',
    packageManager: 'apt',
    supportedArchs: ['aarch64', 'x86_64'],
    downloadUrl: 'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/',
    isBuiltin: false,
    iconName: 'ubuntu',
  );

  /// 预设：Android 本地 Shell
  static const DistroInfo host = DistroInfo(
    id: 'host',
    name: '本地 Shell',
    version: 'Android',
    description: '直接调用安卓系统内置的基础 Shell，无需虚拟环境',
    defaultShell: '/system/bin/sh',
    packageManager: 'none',
    supportedArchs: ['all'],
    isBuiltin: true,
    iconName: 'host',
  );

  /// 默认官方预设列表
  static const List<DistroInfo> defaults = [
    alpine,
    debian,
    ubuntu,
    host,
  ];

  DistroInfo copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    String? defaultShell,
    String? packageManager,
    List<String>? supportedArchs,
    String? assetPath,
    String? downloadUrl,
    bool? isBuiltin,
    String? iconName,
  }) {
    return DistroInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      defaultShell: defaultShell ?? this.defaultShell,
      packageManager: packageManager ?? this.packageManager,
      supportedArchs: supportedArchs ?? this.supportedArchs,
      assetPath: assetPath ?? this.assetPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'defaultShell': defaultShell,
      'packageManager': packageManager,
      'supportedArchs': supportedArchs,
      'assetPath': assetPath,
      'downloadUrl': downloadUrl,
      'isBuiltin': isBuiltin,
      'iconName': iconName,
    };
  }

  factory DistroInfo.fromJson(Map<String, dynamic> json) {
    return DistroInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      defaultShell: (json['defaultShell'] as String?) ?? '/bin/sh',
      packageManager: (json['packageManager'] as String?) ?? 'apk',
      supportedArchs: (json['supportedArchs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['aarch64'],
      assetPath: json['assetPath'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      isBuiltin: (json['isBuiltin'] as bool?) ?? false,
      iconName: (json['iconName'] as String?) ?? 'terminal',
    );
  }
}
