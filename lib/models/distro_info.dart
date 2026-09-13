import 'dart:ffi';

/// 内置 Linux 发行版资源信息常量
class DistroInfo {
  /// 根据当前运行环境的 CPU 架构自动选取匹配的内置 Alpine Minirootfs
  static String get builtinAlpineAssetPath {
    final currentAbi = Abi.current();
    if (currentAbi == Abi.androidX64 ||
        currentAbi == Abi.linuxX64 ||
        currentAbi == Abi.windowsX64) {
      return 'assets/distros/alpine-minirootfs-3.20.3-x86_64.tar.gz';
    }
    return 'assets/distros/alpine-minirootfs-3.20.3-aarch64.tar.gz';
  }

  /// 默认系统实例名称
  static const String defaultSystemName = 'alpine';
}
