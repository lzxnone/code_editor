import 'dart:ffi';
import 'package:flutter/material.dart';

/// 系统架构类型
enum DistroArch {
  arm64,
  x86_64,
}

/// 单一主系统条目清单模型
class DistroManifestItem {
  final String id;
  final String name;
  final String version;
  final bool isBuiltin;
  final Map<DistroArch, String> packages;
  final IconData iconData;
  final Color brandColor;
  final String? assetIconPath;

  const DistroManifestItem({
    required this.id,
    required this.name,
    required this.version,
    this.isBuiltin = true,
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

  /// 获取当前设备适用的内置资源包路径
  String? get currentPackageSource {
    return packages[currentArch];
  }
}

/// 系统资源库静态目录（单一内置系统：Ubuntu 24.04 LTS）
class DistroRepository {
  static const String defaultSystemName = 'ubuntu';

  static const DistroManifestItem ubuntuItem = DistroManifestItem(
    id: defaultSystemName,
    name: 'Ubuntu',
    version: '24.04.5 LTS (Noble Numbat)',
    isBuiltin: true,
    iconData: Icons.donut_large_rounded,
    brandColor: Color(0xFFE95420), // Ubuntu Orange
    assetIconPath: 'assets/icons/distros/ubuntu.png',
    packages: {
      DistroArch.arm64: 'assets/distros/ubuntu-base-24.04.5-base-arm64.tar.gz',
      DistroArch.x86_64: 'assets/distros/ubuntu-base-24.04.5-base-x86_64.tar.gz',
    },
  );

  static const List<DistroManifestItem> availableDistros = [ubuntuItem];

  /// 根据 ID 查找系统配置
  static DistroManifestItem? getById(String id) {
    if (id == defaultSystemName) return ubuntuItem;
    return null;
  }

  /// 内置 Ubuntu 资源包路径（自动匹配当前 CPU 架构）
  static String get builtinUbuntuAssetPath {
    return ubuntuItem.currentPackageSource ??
        'assets/distros/ubuntu-base-24.04.5-base-arm64.tar.gz';
  }
}

