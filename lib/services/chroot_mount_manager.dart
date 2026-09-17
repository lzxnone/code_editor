import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Chroot 环境准备、挂载管理与生命周期服务
class ChrootMountManager {
  static final ChrootMountManager instance = ChrootMountManager._();
  ChrootMountManager._();

  /// 测试桩：用于单测模拟挂载准备是否成功
  @visibleForTesting
  bool? mockPrepareSuccess;

  /// 准备并挂载 Chroot 运行环境
  ///
  /// 执行步骤：
  /// 1. 预先执行懒卸载清理旧挂载，保证环境纯净；
  /// 2. 挂载 /data suid；
  /// 3. 安全挂载 /dev, /dev/pts, /dev/shm, /proc, /sys；
  /// 4. 挂载手机外部存储 /sdcard 与工程工作区目录 /workspace；
  /// 5. 确保 /etc/resolv.conf 存在有效 DNS；
  /// 6. 执行最小化探针测试，若失败返回 false。
  Future<bool> prepareChrootEnvironment({
    required Directory rootDir,
    String? workspacePath,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (mockPrepareSuccess != null) {
      return mockPrepareSuccess!;
    }

    if (!kIsWeb && !Platform.isAndroid) {
      // 非 Android 平台测试环境降级
      return false;
    }

    final rootfs = rootDir.path;
    final workspace = workspacePath ?? '';

    final script = StringBuffer();
    // 1. 懒卸载陈旧挂载
    script.writeln('umount -l "$rootfs/workspace" 2>/dev/null');
    script.writeln('umount -l "$rootfs/sdcard" 2>/dev/null');
    script.writeln('umount -l "$rootfs/dev/pts" 2>/dev/null');
    script.writeln('umount -l "$rootfs/dev/shm" 2>/dev/null');
    script.writeln('umount -l "$rootfs/dev" 2>/dev/null');
    script.writeln('umount -l "$rootfs/proc" 2>/dev/null');
    script.writeln('umount -l "$rootfs/sys" 2>/dev/null');

    // 2. 基础目录与权限
    script.writeln('mount -o remount,suid /data 2>/dev/null');
    script.writeln('mkdir -p "$rootfs/dev" "$rootfs/proc" "$rootfs/sys" "$rootfs/etc" "$rootfs/root" "$rootfs/sdcard" "$rootfs/workspace" 2>/dev/null');

    // 3. 核心虚拟文件系统挂载
    script.writeln('mount --bind /dev "$rootfs/dev" 2>/dev/null');
    script.writeln('mkdir -p "$rootfs/dev/pts" "$rootfs/dev/shm" 2>/dev/null');
    script.writeln('mount -t devpts devpts -o gid=5,mode=620 "$rootfs/dev/pts" 2>/dev/null');
    script.writeln('mount -t tmpfs tmpfs -o mode=1777 "$rootfs/dev/shm" 2>/dev/null');
    script.writeln('mount -t proc proc "$rootfs/proc" 2>/dev/null');
    script.writeln('mount --bind /sys "$rootfs/sys" 2>/dev/null');

    // 4. 存储与工作区
    script.writeln('if [ -d /sdcard ]; then mount --bind /sdcard "$rootfs/sdcard" 2>/dev/null; fi');
    if (workspace.isNotEmpty) {
      script.writeln('if [ -d "$workspace" ]; then mount --bind "$workspace" "$rootfs/workspace" 2>/dev/null; fi');
    }

    // 5. DNS 配置
    script.writeln('if [ ! -s "$rootfs/etc/resolv.conf" ]; then');
    script.writeln('  echo "nameserver 223.5.5.5" > "$rootfs/etc/resolv.conf" 2>/dev/null');
    script.writeln('  echo "nameserver 119.29.29.29" >> "$rootfs/etc/resolv.conf" 2>/dev/null');
    script.writeln('  echo "nameserver 1.1.1.1" >> "$rootfs/etc/resolv.conf" 2>/dev/null');
    script.writeln('  echo "nameserver 8.8.8.8" >> "$rootfs/etc/resolv.conf" 2>/dev/null');
    script.writeln('fi');

    // 6. 验证环境是否能通过 chroot 执行最小探针
    script.writeln('CHROOT_BIN="\$(command -v chroot 2>/dev/null || echo "/system/bin/chroot")"');
    script.writeln('"\$CHROOT_BIN" "$rootfs" /bin/sh -c "exit 0"');

    try {
      final result = await Process.run(
        'su',
        ['-c', script.toString()],
      ).timeout(timeout);

      if (result.exitCode == 0) {
        return true;
      } else {
        debugPrint('[ChrootMountManager] 挂载或探针校验失败 (exitCode ${result.exitCode}): ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('[ChrootMountManager] 准备 Chroot 异常: $e');
      return false;
    }
  }

  /// 安全释放清理挂载点
  Future<void> cleanupMounts(Directory rootDir) async {
    if (!kIsWeb && !Platform.isAndroid) return;
    final rootfs = rootDir.path;
    final script = '''
umount -l "$rootfs/workspace" 2>/dev/null
umount -l "$rootfs/sdcard" 2>/dev/null
umount -l "$rootfs/dev/pts" 2>/dev/null
umount -l "$rootfs/dev/shm" 2>/dev/null
umount -l "$rootfs/dev" 2>/dev/null
umount -l "$rootfs/proc" 2>/dev/null
umount -l "$rootfs/sys" 2>/dev/null
''';
    try {
      await Process.run('su', ['-c', script]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// 探测并解析容器内首选 Shell（优先 zsh，其次 bash，兜底 sh）
  String resolveTargetShell(Directory rootDir) {
    if (File(p.join(rootDir.path, 'bin', 'zsh')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'zsh')).existsSync()) {
      return '/bin/zsh';
    }
    if (File(p.join(rootDir.path, 'bin', 'bash')).existsSync() ||
        File(p.join(rootDir.path, 'usr', 'bin', 'bash')).existsSync()) {
      return '/bin/bash';
    }
    return '/bin/sh';
  }
}
