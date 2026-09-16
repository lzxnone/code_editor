# PRoot 环境下 `apt install perl` 失败问题修复计划

## 一、问题现象与背景

在 Ubuntu / Debian 容器环境中执行 `apt install perl` 时报错：
```text
dpkg: error processing archive /var/cache/apt/archives/perl_5.38.2-3.2ubuntu0.4_arm64.deb (--unpack):
 error setting ownership of '/usr/bin/perlthanks.dpkg-new': No such file or directory
```

---

## 二、底层根因分析（深度对标 Termux / proot-distro）

### 1. 核心诱因：硬链接解包转换
- Perl 软件包在解压时，`/usr/bin/perlthanks` 是指向 `/usr/bin/perlbug` 的硬链接（Hard Link）。
- Android 应用私有目录下，底层文件系统/SELinux 策略禁止非 root 应用直接创建硬链接（`link(2)` 返回 `EPERM`）。
- PRoot 启用了 `--link2symlink`，它将硬链接拦截并转换为：**指向 `.l2s` 目录下替身文件的符号链接（Symlink）**。

### 2. 缺陷一：`.l2s` 目录路径错位（位于 Rootfs 外部）
- **现状**：
  在 `lib/services/distro_manager.dart` 中：
  ```dart
  final l2sDir = Directory(p.join(baseDir.path, systemName, '.l2s'));
  ```
  该路径在宿主为 `<baseDir>/<systemName>/.l2s`，而容器 Rootfs 为 `<baseDir>/<systemName>/rootfs`。`.l2s` 位于 Rootfs **外部**。
- **Termux 官方规范**：
  在 Termux `proot-distro` 的 `l2s.py` 源码中明确声明：
  > `(proot-distro sets it to <rootfs>/.l2s)`
- **导致的问题**：
  PRoot 在创建替身符号链接时，记录的是绝对路径。当 `.l2s` 位于 rootfs 外时，PRoot 内部的路径逆向规范化（`detranslate_path`）无法将其识别为容器内合法路径；容器内应用跟随链接访问时也无法访问容器外的宿主目录，从而触发 `ENOENT`（No such file or directory）。

### 3. 缺陷二：`libfix_seccomp.so` 遗漏导出 `chown` 与 `lchown` 符号
- **现状**：
  此前为 Alpine（musl libc）修复 `apk add tzdata` 时，Shim 仅拦截了 `fchownat`，因为 musl 的 `chown/lchown` 内部均调用 `fchownat`。
- **Ubuntu/Debian (glibc) 差异**：
  - `dpkg` 在解包硬链接后会直接调用 `chown(fnamenew, uid, gid)`。
  - glibc 的 `chown()` 函数实现是**直接执行内联系统调用指令（inline syscall `svc 0`）**，并不走 `fchownat` 的 PLT 动态重定位跳转。
  - 因此 `dpkg` 调用的 `chown` 彻底绕过了 Shim 的 `fchownat` 拦截，直达 PRoot/内核。PRoot 在跟随 l2s 替身链接时返回 `ENOENT`。

---

## 三、修改计划与实施步骤

### 步骤 1：Dart 端 `.l2s` 路径对标 Termux 并自动迁移
**修改文件**：[`lib/services/distro_manager.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/distro_manager.dart)
1. 将 `_ensureL2sDir(String systemName)` 升级为 `_ensureL2sDir(String systemName, Directory rootDir)`：
   - 目录指向 `p.join(rootDir.path, '.l2s')`。
   - 若此前存在旧路径 `<baseDir>/<systemName>/.l2s` 且内含文件，自动平滑移动至新位置。
2. 环境变量配置：
   - PRoot 宿主环境传递：`'PROOT_L2S_DIR': l2sDir.path`。
   - 容器内 guest 环境变量同步注入：`'PROOT_L2S_DIR=/.l2s'`。

### 步骤 2：Debian / Ubuntu 环境部署 `dpkg` 优化配置
**修改文件**：[`lib/services/distro_installer.dart`](file:///d:/Flutter/Projects/code_editor/lib/services/distro_installer.dart)
1. 新增 `ensureDpkgConfiguration(Directory rootfsDir)` 方法：
   - 检查 `etc/dpkg` 是否存在（判断是否为 Debian/Ubuntu 环境）。
   - 确保 `/etc/dpkg/dpkg.cfg.d/` 目录存在。
   - 写入 `/etc/dpkg/dpkg.cfg.d/01_proot`，内容包含：
     ```text
     force-unsafe-io
     ```
   - 避免容器内因 fsync / flash I/O 阻塞或权限校验引发的解包异常（Docker / proot-distro 官方推荐实践）。
2. 在 `postInstallConfigure` 与容器启动检查中自动调用。

### 步骤 3：Shim (`libfix_seccomp.c`) 补充 `chown` 与 `lchown` 导出
**修改文件**：[`android/app/src/main/cpp/libfix_seccomp.c`](file:///d:/Flutter/Projects/code_editor/android/app/src/main/cpp/libfix_seccomp.c)
1. 增加标准 `chown` 和 `lchown` 导出符号：
   ```c
   __attribute__((visibility("default")))
   int chown(const char *path, int owner, int group) {
       return fchownat(AT_FDCWD, path, owner, group, 0);
   }

   __attribute__((visibility("default")))
   int lchown(const char *path, int owner, int group) {
       return fchownat(AT_FDCWD, path, owner, group, AT_SYMLINK_NOFOLLOW);
   }
   ```
2. 如此一来，无论是 glibc 还是 musl 的应用程序直接调用 `chown` 或 `lchown`，均会走入已有的 `fchownat` 机制：在遭遇 `ENOENT` 时自动以 `AT_SYMLINK_NOFOLLOW` 重试设置替身属性，保证硬链接解压 100% 成功。

---

## 四、验证与验收方案

1. **单元测试回归**：
   - 运行全量单元测试：`flutter test`（确保现有 282 项测试无任何回退）。
   - 增加关于 `.l2s` 位于 `rootDir/.l2s` 以及 `dpkg.cfg.d/01_proot` 的自动化测试用例。
2. **静态分析**：
   - 运行 `flutter analyze` 确保无任何语法和类型告警。
3. **真实场景（Ubuntu 容器）验证**：
   - 在容器中执行 `apt update && apt install perl -y`。
   - 验证 `/usr/bin/perlthanks` 与 `/usr/bin/perlbug` 成功安装且解包 ownership 正确设置，退出码为 0。
