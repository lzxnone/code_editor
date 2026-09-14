import 'dart:ffi';
import 'package:flutter/material.dart';

/// 系统架构类型
enum DistroArch {
  arm64,
  x86_64,
}

/// LXC 容器镜像元数据规格（用于根据下载源动态解析真实下载路径）
class LxcImageSpec {
  /// 发行版代号 (例如 'debian', 'archlinux', 'fedora')
  final String distribution;

  /// 版本标识 (例如 'bookworm', 'current', '43')
  final String release;

  /// 变体标识 (例如 'default', 'cloud')
  final String variant;

  const LxcImageSpec({
    required this.distribution,
    required this.release,
    this.variant = 'default',
  });
}

/// 发行版下载镜像源定义
class DistroMirror {
  final String id;
  final String name;
  final String baseUrl;
  final bool isDefault;

  const DistroMirror({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.isDefault = false,
  });
}

/// 发行版条目清单模型
class DistroManifestItem {
  /// 唯一标识符 (例如 'ubuntu', 'alpine', 'debian')
  final String id;

  /// 显示名称 (例如 'Ubuntu', 'Alpine Linux', 'Debian')
  final String name;

  /// 版本文本 (例如 '24.04.5 LTS', '3.20.3', '12 (Bookworm)')
  final String version;

  /// 是否推荐
  final bool isRecommended;

  /// 是否为软件内置安装包（打包在 assets 中，受删除保护且无需网络下载）
  final bool isBuiltin;

  /// LXC 镜像元数据（在线下载型系统专属，用于动态源解析器自动发现真实路径）
  final LxcImageSpec? lxcSpec;

  /// 对应架构资源包映射 (架构 -> 下载 URL 或 Asset 路径)
  final Map<DistroArch, String> packages;

  /// 系统图标或装饰图标
  final IconData iconData;

  /// 品牌主题色（用于图标底色/装饰）
  final Color brandColor;

  /// 本地资产图标路径 (例如 'assets/icons/distros/ubuntu.png')
  final String? assetIconPath;

  const DistroManifestItem({
    required this.id,
    required this.name,
    required this.version,
    this.isRecommended = false,
    this.isBuiltin = false,
    this.lxcSpec,
    required this.packages,
    required this.iconData,
    required this.brandColor,
    this.assetIconPath,
  });

  /// 获取当前运行环境的 CPU 架构
  static DistroArch get currentArch {
    final abi = Abi.current();
    if (abi == Abi.androidArm64 || abi == Abi.linuxArm64) {
      return DistroArch.arm64;
    }
    return DistroArch.x86_64;
  }

  /// 当前机器架构是否有可用的资源包
  bool get isSupportedOnCurrentDevice {
    return packages.containsKey(currentArch);
  }

  /// 获取当前设备适用的资源包路径或 URL
  String? get currentPackageSource {
    return packages[currentArch];
  }
}

/// 系统资源库静态目录（包含内置与经过验证的高速在线源）
class DistroRepository {
  static const List<DistroManifestItem> availableDistros = [
    // 1. Ubuntu 24.04 LTS (推荐，软件内置)
    DistroManifestItem(
      id: 'ubuntu',
      name: 'Ubuntu',
      version: '24.04.5 LTS (Noble Numbat)',
      isRecommended: true,
      isBuiltin: true,
      iconData: Icons.donut_large_rounded,
      brandColor: Color(0xFFE95420), // Ubuntu Orange
      assetIconPath: 'assets/icons/distros/ubuntu.png',
      packages: {
        DistroArch.arm64: 'assets/distros/ubuntu-base-24.04.5-base-arm64.tar.gz',
        DistroArch.x86_64: 'assets/distros/ubuntu-base-24.04.5-base-x86_64.tar.gz',
      },
    ),

    // 2. Alpine 3.20 (软件内置)
    DistroManifestItem(
      id: 'alpine',
      name: 'Alpine Linux',
      version: '3.20.3 (musl libc)',
      isRecommended: false,
      isBuiltin: true,
      iconData: Icons.landscape_rounded,
      brandColor: Color(0xFF0D597F), // Alpine Blue
      assetIconPath: 'assets/icons/distros/alpine.png',
      packages: {
        DistroArch.arm64: 'assets/distros/alpine-minirootfs-3.20.3-aarch64.tar.gz',
        DistroArch.x86_64: 'assets/distros/alpine-minirootfs-3.20.3-x86_64.tar.gz',
      },
    ),

    // 3. Debian 12 (Bookworm) - 在线下载，不占 APK 体积
    DistroManifestItem(
      id: 'debian',
      name: 'Debian',
      version: '12 (Bookworm)',
      isRecommended: false,
      isBuiltin: false,
      lxcSpec: LxcImageSpec(
        distribution: 'debian',
        release: 'bookworm',
        variant: 'default',
      ),
      iconData: Icons.all_inclusive_rounded,
      brandColor: Color(0xFFA80030), // Debian Red
      assetIconPath: 'assets/icons/distros/debian.png',
      packages: {
        DistroArch.arm64: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/debian/bookworm/arm64/default/20260913_05:24/rootfs.tar.xz',
        DistroArch.x86_64: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/debian/bookworm/amd64/default/20260913_05:24/rootfs.tar.xz',
      },
    ),

    // 4. Arch Linux - 在线源
    DistroManifestItem(
      id: 'arch',
      name: 'Arch Linux',
      version: 'Rolling Release',
      isRecommended: false,
      isBuiltin: false,
      lxcSpec: LxcImageSpec(
        distribution: 'archlinux',
        release: 'current',
        variant: 'default',
      ),
      iconData: Icons.change_history_rounded,
      brandColor: Color(0xFF1793D1), // Arch Cyan
      assetIconPath: 'assets/icons/distros/arch.png',
      packages: {
        DistroArch.arm64: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/archlinux/current/arm64/default/20260913_04:18/rootfs.tar.xz',
        DistroArch.x86_64: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/archlinux/current/amd64/default/20260913_04:18/rootfs.tar.xz',
      },
    ),

    // 5. Fedora 43 - 在线源
    DistroManifestItem(
      id: 'fedora',
      name: 'Fedora',
      version: '43 (Container Base)',
      isRecommended: false,
      isBuiltin: false,
      lxcSpec: LxcImageSpec(
        distribution: 'fedora',
        release: '43',
        variant: 'default',
      ),
      iconData: Icons.language_rounded,
      brandColor: Color(0xFF51A2DA), // Fedora Blue
      assetIconPath: 'assets/icons/distros/fedora.png',
      packages: {
        DistroArch.arm64: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/fedora/43/arm64/default/20260913_20:33/rootfs.tar.xz',
        DistroArch.x86_64: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/fedora/43/amd64/default/20260913_20:33/rootfs.tar.xz',
      },
    ),
  ];

  /// 可选的高速开源软件镜像源
  static const List<DistroMirror> availableMirrors = [
    DistroMirror(
      id: 'tsinghua',
      name: 'Tsinghua TUNA Mirror',
      baseUrl: 'https://mirrors.tuna.tsinghua.edu.cn/lxc-images/',
      isDefault: true,
    ),
    DistroMirror(
      id: 'bfsu',
      name: 'BFSU Open Source Mirror',
      baseUrl: 'https://mirrors.bfsu.edu.cn/lxc-images/',
    ),
    DistroMirror(
      id: 'iscas',
      name: 'ISCAS Open Source Mirror',
      baseUrl: 'https://mirror.iscas.ac.cn/lxc-images/',
    ),
    DistroMirror(
      id: 'official',
      name: 'LinuxContainers Official Mirror',
      baseUrl: 'https://images.linuxcontainers.org/',
    ),
  ];

  /// 默认推荐镜像源（清华大学源）
  static DistroMirror get defaultMirror =>
      availableMirrors.firstWhere((m) => m.isDefault, orElse: () => availableMirrors.first);

  /// 根据 ID 检索镜像源
  static DistroMirror getMirrorById(String id) {
    return availableMirrors.firstWhere(
      (m) => m.id == id,
      orElse: () => defaultMirror,
    );
  }

  /// 根据当前机器架构过滤，仅返回本架构支持的发行版列表
  static List<DistroManifestItem> get currentArchDistros {
    return availableDistros.where((d) => d.isSupportedOnCurrentDevice).toList();
  }

  /// 默认系统实例名称
  static const String defaultSystemName = 'ubuntu';

  /// 根据 ID 查找发行版配置
  static DistroManifestItem? getById(String id) {
    try {
      return availableDistros.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 内置 Ubuntu 资源包路径（自动匹配当前 CPU 架构）
  static String get builtinUbuntuAssetPath {
    return getById('ubuntu')?.currentPackageSource ??
        'assets/distros/ubuntu-base-24.04.5-base-arm64.tar.gz';
  }

  /// 内置 Alpine 资源包路径（自动匹配当前 CPU 架构）
  static String get builtinAlpineAssetPath {
    return getById('alpine')?.currentPackageSource ??
        'assets/distros/alpine-minirootfs-3.20.3-aarch64.tar.gz';
  }
}

