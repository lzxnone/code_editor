# 容器（PRoot + Alpine）问题修复总结

> 日期：2026-09-13
> 真机验证：**OnePlus PLC110 / Android 16 (SDK 36) / arm64-v8a / SELinux Enforcing / 非 root**
> 复现环境：Pixel 8 Pro 模拟器 `emulator-5554` / Android 14 / **x86_64**
> 本文是本次工作的**唯一汇总入口**（根因、修复、实机验收、工具与注意事项）；自检工具的用法见
> `tools/container-selfcheck/README.md`。

---

## 一、一页结论

| # | 问题 | 状态 | 性质 |
|---|---|---|---|
| A | `apk` 报 `temporary error (try again later)` | ✅ 已修复 | **x86_64 模拟器专属**，arm64 真机不存在 |
| B | `apk` 报 `IO ERROR` | ✅ 已修复 | 同 A（`select`） |
| C | `apk add` 报 `Failed to preserve modification time`（硬链接包，如 tzdata） | ✅ 已修复并真机验收 | **跨架构** PRoot 级缺陷 |
| D | `ps` 软链接 `Permission denied` | ⏸ 本轮未复现 | 历史偶发，待观察 |

**三句话根因**

1. **A/B（仅 x86_64）**：Android 给应用进程装的 seccomp 策略把传统 `poll(2)`/`select(2)` 返回 **ENOSYS**；x86_64 的系统调用表里有这两个调用而 **musl 的 `poll()` 正是 `#ifdef SYS_poll` 选择它**，且 **musl 的 DNS 解析器在 libc 内部调用 `poll()`（`LD_PRELOAD` 无法插桩）** ⇒ 解析器静默空转到超时 ⇒ `EAI_AGAIN` ⇒ libfetch `FETCH_TEMP` ⇒ `temporary error`。
   **arm64 的系统调用表里根本没有 `poll/select/epoll_wait`**，libc 只能用 `ppoll/pselect6/epoll_pwait`，**无处可封** ⇒ 真机不会出现该问题（这也解释了 Termux 生态"几乎遇不到"）。
2. **C（跨架构）**：Android 不允许应用数据区创建硬链接（实测：去掉 `--link2symlink` 会报 `Failed to create …: Permission denied`），所以 PRoot 用 **symlink + 隐藏记账文件**模拟硬链接；实测替身指向宿主绝对路径
   （`.../Africa/Accra -> /data/data/<pkg>/…/.l2s/.proot.l2s..apk.<hash>`），apk 用**跟随符号链接**语义的 `utimensat` 保 mtime ⇒ 落到不可解析的隐藏名字 ⇒ ENOENT ⇒ 包被标记 broken（`f:f`），**此后每次 apk 操作恒定输出 "1 error"**。
3. **rootfs 本身没问题**：内置的两个 Alpine minirootfs 均与官方 **sha256 逐字节一致**
   （x86_64 `d4e6fd67…1efa0c` / aarch64 `041fa34a…f3de`）。

---

## 二、修复内容（只保留"正确且必要"）

### 1. Shim：`android/app/src/main/cpp/`

| 覆盖 | 架构 | 原因 |
|---|---|---|
| `utimensat` | **两个 ABI** | C：ENOENT 时带 `AT_SYMLINK_NOFOLLOW` 重试（设置替身自身时间，最接近真实硬链接语义） |
| `poll` / `select` / `pipe` / `dup2` | **仅 x86_64** | A/B：转发到 `ppoll`/`pselect6`/`pipe2`/`dup3`（musl 在有传统调用的架构上优先用它们） |
| `getaddrinfo` / `freeaddrinfo`（`libfix_dns.c`） | **仅 x86_64** | A：用 `ppoll` 自建解析（先查 `/etc/hosts`；并行询问所有 nameserver、单次 5s 等待；不校验应答源地址——与 busybox/c-ares 一致） |

**删除的冗余/错误归因**：`fork`/`vfork`（musl 本就用 `clone(SIGCHLD)`）、
`stat`/`lstat`/`fstat`/`fstatat`/`__fstatat`/`*64`（与 musl 自身实现相同）、
`fstatat` 空路径 workaround（真机实测 `newfstatat(fd,"",st,AT_EMPTY_PATH)=0`，PRoot 正常）、
arm64 上的 `poll/select/pipe/dup2`（该架构无这些 syscall）。

| ABI | 修复前 | 修复后 | 导出符号 |
|---|---|---|---|
| x86_64 | 15824 B / 17 个 | **11112 B** | `poll, select, pipe, dup2, utimensat, getaddrinfo, freeaddrinfo` |
| arm64-v8a | 5512 B / 17 个 | **2936 B** | **仅 `utimensat`** |

### 2. Dart 侧：`lib/services/`

| 项目 | 之前 | 现在 | 依据 |
|---|---|---|---|
| rootfs 权限 | 解压后 `chmod -R 755` 一把梭 | 按 **tar 头 mode 分组批量 chmod**（跳过符号链接，避免 chmod 跟随链接改坏目标） | dart:io 无 chmod，但"全部 755"会把 `/etc` 配置也变可执行 |
| guest `/etc/profile` | 安装后重写 | **不再改写** | 实测原版与旧模板**逐行相同** ⇒ 对 Alpine 零影响，同时修掉"破坏 Debian/Ubuntu 登录环境"的缺陷 |
| DNS | `8.8.8.8` 优先、两处不一致 | 统一 **可达优先**：`223.5.5.5 / 119.29.29.29 / 114.114.114.114` | 8.8.8.8/1.1.1.1 境内常丢包，排首位先吃一次超时 |
| `--sysvipc` | （原计划新增） | **不加** | 实测本项目 `libproot.so` 不支持：`unknown option '--sysvipc'`（Termux 是带 `libandroid-shmem` 的 proot fork） |
| `--kernel-release` | `-k 5.4.0-proot` | 保持 | proot-distro 的完整 uname 串是给 Termux fork 版用的 |

---

## 三、实机验收（重新构建 APK → 删除实例 → 全新导入）

| 验收项 | 结果 |
|---|---|
| `/etc/profile` | ✅ 与官方原版 **sha256 逐字节一致**（`87e8643d…`，547 B）→ 未被改写 |
| 权限恢复 | ✅ `bin/busybox`、`sbin/apk` = 0755；`/etc/passwd`、`/etc/profile` = **0644**（不再是 0755） |
| DNS | ✅ `223.5.5.5 / 119.29.29.29 / 114.114.114.114` |
| shim | ✅ 2936 B（arm64 精简版） |
| `apk update` | ✅ rc=0，3 s，`OK: 24059 distinct packages available`（走**原生** musl 解析器） |
| `apk add tzdata`（硬链接密集） | ✅ `OK: 10 MiB in 15 packages`，文件落地（`Africa/Accra` nlink=14） |
| `apk add tree`（含 busybox 触发器） | ✅ 触发器正常执行，rc=0 |
| broken 标记 / `.apk.*` 残留 | ✅ 无 |
| `pipe` / 子 shell / `sha256sum` | ✅ 正常 |
| syscall 基线 | ✅ `ppoll/pselect6/epoll_pwait/utimensat/clone/fstat/statfs/getrandom/uname` 全 0 |

`flutter analyze`：**No issues found**。

---

## 四、为什么 Termux+proot 顺、而本次问题多

1. **proot-distro 只是 Python 编排层**（rootfs 组装、sysdata/shm/l2s、bind 校验、session/lock）；它不负责 guest libc 与 Android 策略的兼容，也不负责宿主 DNS/`/proc`/seccomp 语义。**抄编排层 ≠ 抄 Termux 的运行环境。**
2. **架构差异**：Termux 用户几乎都在 **arm64 真机**（无 `poll/select` syscall）；本次复现环境是 **x86_64 模拟器**（有且被封）。
3. **上游刻意不做的事我们做了**：注入 `LD_PRELOAD` shim（proot-distro 明确剥离）、改写 guest `/etc/profile`、`chmod -R 755`、硬编码公共 DNS。
4. **可观测性差距**：真机可 `strace`，proot 内因嵌套 ptrace 不可用（实测 rc=182）⇒ 只能自造裸 syscall 探针，排查更慢。

---

## 五、工具（已入库）

`tools/container-selfcheck/`：`probe3.c`（syscall 策略自检，双架构）、`probe4.c`（复现 apk 安装序列）、
`probe5.c`（空路径 stat）、`selfcheck.sh`（一键验收）、`guest-run.sh`（**免重装 APK** 的 adb 跑手）、
`README.md`（用法 + 已定位结论表）。

**两条铁律**

1. **不要在容器运行时原地覆盖 `/lib/libfix_seccomp.so`** —— 正在映射该文件的进程会 SIGSEGV
   （实测：`proot info: vpid 1: terminated with signal 11`）。必须「写临时文件 → `mv` 重命名」。
2. **换 shim 后需新起进程才生效**（`am force-stop` 重启 App，或新开一个会话）。

---

## 六、已知但未处理（均无功能影响）

| 现象 | 说明 |
|---|---|
| `openat(dir, O_RDONLY\|O_DIRECTORY)` → **EINVAL** | 本项目 proot 的怪癖（`O_PATH\|O_DIRECTORY` 正常，x86_64 上同调用成功）；当前无功能影响 |
| `.proot-meta-file.*` / `.l2s` 残留 | `--link2symlink` 机制的固有产物，已不再导致安装失败 |
| `unshare(CLONE_NEWNS)` EPERM / `chroot` ENOENT | 应用进程预期行为，apk 脚本执行不受影响 |
| `/proc` 为宿主共享 | 容器内 `ps` 可见宿主 App 进程（信息隔离偏弱，非缺陷） |
| 多发行版 | guest `/etc/profile` 不再被改写后，Debian/Ubuntu 等可保留自身登录环境 |

---

## 七、运维注意

- **验收基准用 arm64 真机**；模拟器只用于 UI 迭代。
- **MIUI 设备**（如 Redmi K60）`adb install` 会被拦（`INSTALL_FAILED_USER_RESTRICTED`），需手动安装或开启开发者选项里的「USB 安装」；OnePlus / 原生 Android 无此限制。
- `/data/local/tmp` 下**不能执行**二进制（SELinux `execute` denied）——测试用的 proot/shim 必须放到应用数据目录。

---

## 八、proot 重建（2026-09-13：App 已内置新 proot）

### 为什么重建

原来的 `jniLibs/*/libproot.so` 是 **termux/proot fork @ `dcc74e9b`（2018-12-05，UserLAnd 那条线）**，
NDK clang 7.0.2 构建、loader 内嵌、未编 libandroid-shmem（无 `--sysvipc`）。
相对当前上游 tag **`v5.1.107.92` 落后 166 个提交且已分叉**（缺 f2fs、l2s、SIGSYS、seccomp 等一批 Android 修复）。

### 怎么重建（本机无 make/sh/awk ⇒ PowerShell 复刻 GNUmakefile）

| 项目 | 内容 |
|---|---|
| 源码 | `git clone --depth 1 --branch v5.1.107.92 https://github.com/termux/proot.git proot-source` |
| talloc | 头文件取自稀疏克隆的 samba（`build_proot_deps/samba/lib/talloc/talloc.h`）；`libtalloc.so` 沿用仓库现有（SONAME 匹配） |
| 脚本 | `tools/build/build-proot.ps1`：架构宏探测（clang -E -dM）→ `build.h` → 66 个目标文件 → loader 编译 + `objcopy` 内嵌 → POKEDATA `loader-info.c` → 链接单个 `.so` |
| 关键参数 | `-DARG_MAX=131072`；**不设** `PROOT_UNBUNDLE_LOADER`（loader 内嵌）；API 24（`getifaddrs`）；**关闭 `HAVE_PROCESS_VM`**（与旧二进制一致，走 POKEDATA 路径，规避 Android 策略风险） |
| 产物 | `jniLibs/arm64-v8a/libproot.so` **257712 B**、`jniLibs/x86_64/libproot.so` **272672 B**（旧文件备份在 `build_proot_out/backup/`） |
| 新增能力 | `--sysvipc`（需配 libandroid-shmem 才能真正使用，暂未启用）、`--change-id`、f2fs-bug 修复 |

### 必须配套的 shim 改动（实测得出）

新版把 `link2symlink.c` **重写（+838 行）**、`fake_id0/helper_functions.c` **删掉 84 行**，于是 apk 的
`fchownat(dirfd, ".apk.<hash>", 0, 0, 0)` 也会解析 l2s 隐藏替身 → `Failed to set ownership`。
⇒ shim 新增 **`fchownat` 的 `AT_SYMLINK_NOFOLLOW` 重试**（与 `utimensat` 同套路；musl 的 `chown/lchown/fchownat` 都走 `SYS_fchownat`）。

对照矩阵（真机 arm64，`apk add tzdata`）：

| 组合 | 结果 |
|---|---|
| 旧 proot + 旧 shim | ✅ rc=0（基线） |
| 旧 proot 无 shim | ❌ `Failed to preserve modification time` |
| 新 proot + 旧 shim | ❌ **`Failed to set ownership`** |
| **新 proot + 新 shim（含 fchownat）** | ✅ **rc=0，无 broken 标记** |
| 新 proot 不加 `--link2symlink` | ❌ `failed to rename .apk.<hash>`（**l2s 仍必须保留**） |

shim 体积：arm64 2936 → **3088 B**；x86_64 11112 → **11168 B**。

### 验证状态

| 项目 | 状态 |
|---|---|
| 双架构编译 | ✅ |
| arm64 真机（容器 + `apk update/add tzdata/tree` 全流程） | ✅ |
| x86_64 运行时 | ⏳ 待模拟器在线（产物已就绪，源码/参数与 arm64 同源） |
| 回滚方式 | 用 `build_proot_out/backup/*` 覆盖回 `jniLibs/*/libproot.so`（或 `git checkout` 对应文件） |

---

## 九、启用 SysV IPC（`--sysvipc`，2026-09-13）

### 它是什么

**System V IPC**：共享内存 `shmget/shmat`、信号量 `semget/semop`、消息队列 `msgget/msgsnd`
（`ipcs` 命令列的就是它们）。数据库（PostgreSQL 等）、部分老工具与科学计算依赖它。
**Android 的 app seccomp 策略把这套调用全部返回 ENOSYS**，因此 PRoot 提供 `--sysvipc`
在容器内用用户态模拟（共享内存靠 ashmem/memfd 支撑）。

### 实测（真机 arm64，probe6 裸 syscall）

| 探针项 | 不开 `--sysvipc` | 开 `--sysvipc` |
|---|---|---|
| `shmget(IPC_PRIVATE)` / `shmat` / `shmctl` | ENOSYS | ✅ 成功 |
| `shmget(key=0x1234)`（命名 key）/ 同 key 复用 | ENOSYS | ✅ 同一段（跨进程共享语义正确） |
| `semget` / `msgget` | ENOSYS | ✅ 成功 |
| 容器基本 / `apk update` / `apk add tzdata` / broken 标记 | ✅ 正常 | ✅ **依然正常（0/0/0）** |
| `/dev/shm` 读写、`whoami/ls/pipe/apk info/ps` | ✅ | ✅ |

⇒ **不开时与旧行为逐项一致（证明重编中立），开了无负面影响。**

### 构建（`tools/build/build-shmem.ps1`）

| 项目 | 内容 |
|---|---|
| 源码 | `git clone --depth 1 https://github.com/termux/libandroid-shmem.git` |
| 本地补丁 | `tools/patches/libandroid-shmem-runtime-ashmem.patch`：把上游的**编译期**后端选择（`__ANDROID_API__ >= 26`）改成**运行时** `dlopen("libandroid.so")` + `dlsym(ASharedMemory_*)`，拿不到再回退 `/dev/ashmem` |
| 为什么需要补丁 | 实测 Android 16 上 `open("/dev/ashmem", O_RDWR)` = **EACCES**（应用进程被拒），而 `ASharedMemory_create()` = 4 ✅（memfd 支撑）。不补丁则 `shmget` 返回 EACCES；改成 API 26 编译又会要求设备 ≥26 |
| 其他参数 | `-D_PATH_TMP="/data/data/<applicationId>/cache/"`（上游引用了 bionic 未定义的 `_PATH_TMP`，它是命名 key 的 symlink 存放处；applicationId 由脚本从 `build.gradle.kts` 读取）；`-Wno-implicit-function-declaration`（上游漏 `<fcntl.h>`） |
| 产物 | `jniLibs/{arm64-v8a,x86_64}/libandroid-shmem.so`（21976 / 21128 B） |

### 启用后的依赖关系（重要）

`jniLibs/*/libproot.so` 现在是 **shmem 版**（258432 / 273424 B），其 `NEEDED` 含
`libandroid-shmem.so` ⇒ **必须一起打包**，否则 proot 无法启动。启动参数在
`lib/services/distro_manager.dart` 中新增了 `--sysvipc`。

回滚：`build_proot_out/backup/*preshmem-*` 是本次之前的非 shmem 版 proot；去掉
`--sysvipc` 一行即可退回旧行为（此时 libandroid-shmem.so 仍会被打包但不被使用）。

---

## 十、本轮最终形态（2026-09-13 收尾总结）

### 1. 仓库里现在是什么

| 产物 | 说明 |
|---|---|
| `jniLibs/arm64-v8a/libproot.so` **259696 B** ／ `x86_64` **274800 B** | `termux/proot` **v5.1.107.92** + 本地补丁，**loader 内嵌**（单个自包含 .so） |
| `jniLibs/*/libandroid-shmem.so` | `--sysvipc` 的共享内存后端（运行时 ashmem/ASharedMemory 双路径） |
| `jniLibs/*/libtalloc.so` | proot 依赖（沿用原有） |
| `assets/shims/arm64-v8a` **3088 B** ／ `x86_64` **11488 B** | freestanding shim：`utimensat`/`fchownat`（l2s 硬链接兜底）；x86_64 另含 `poll/select/pipe/dup2/fork/vfork` 与 `getaddrinfo` |
| `tools/build/build-proot.ps1`、`tools/build/build-shmem.ps1`、`tools/patches/*` | 可复现构建链（用法见 `tools/build/README.md`） |
| `tools/container-selfcheck/` | 探针 `probe3/4/5/6/8` + 一键验收 + adb 跑手 + README |
| `lib/services/distro_manager.dart` | 启动参数含 `--sysvipc` |

构建中间目录（`proot-source/`、`build_proot_deps/`、`build_proot_out/`）**已删除**，可按 `tools/build/README.md` 随时重建；
旧版 proot 二进制都在 git 历史里，可回滚。

### 2. proot 层"传统 syscall 现代化"（本轮核心）

Android 的 app seccomp 策略在 **x86_64** 上拒绝下列调用（arm64 的系统调用表里根本没有它们，所以只有 x86_64 中招）：

| 被拒调用 | proot 层改写 | 状态 |
|---|---|---|
| `poll` / `select` / `epoll_wait` | `ppoll` / `pselect6` / `epoll_pwait`（timespec 写进 tracee 栈） | ✅ **实测生效**（静态探针 = 0，shim 影响不到） |
| `pipe` / `dup2` | `pipe2` / `dup3` | ✅ |
| `vfork`（`clone` 带 `CLONE_VM\|CLONE_VFORK`） | 去掉这两位（vfork 降级为 fork，POSIX 允许） | ✅ |
| `fork`(57) / `clone3`(435) | → `clone(SIGCHLD)` / 结构体→寄存器参数转换 | ⚠️ **改写未生效**（见下） |

**已知限制（实测定位）**：`fork` 与 `clone3` 确实被平台拒（`ENOSYS`），但它们属于**创建进程**的调用，
**PRoot 走自己的子进程跟踪路径（ptrace 的 CLONE/FORK 事件），不经过 `translate_syscall_enter`**，
所以补丁里对这两条的改写不会被执行。

- 影响面：**仅静态链接程序**（Go/Rust 静态二进制）在 x86_64 上 `fork` 会失败；
- 动态程序不受影响：shim 替换了 libc 的 `fork`/`vfork` ⇒ guest 永远不会发出 `clone3`（这是当前可用的保证）；
- 彻底的修法：在 PRoot 的 clone/子进程跟踪路径里挂钩（更深、更侵入的改动）。

### 3. 验收记录

| 平台 | 项目 | 结果 |
|---|---|---|
| **arm64 真机**（OnePlus PLC110 / Android 16 / 非 root） | 全新导入、`apk update`（3 s / 24059 包）、`apk add tzdata`（`Africa/Accra` nlink=14）、`apk add tree`（busybox 触发器）、broken=0、`unshare`=0、`chroot("/")`=0、SysV IPC 跨进程 `verify=OK` | ✅ 全绿 |
| **x86_64 模拟器**（Android 14 / SDK 34） | 真实 app 过滤器（`Seccomp_filters: 2`）下：静态探针 `poll/select/epoll_wait`=0、子 shell/后台任务/管道、`apk` 0/0/0、SysV IPC 跨进程 `verify=OK`、`/dev/shm` 读写、`profile_sha` 与官方一致 | ✅ 全绿（清空 `LD_PRELOAD` 时 `fork` 受限，见 2 的已知限制） |

### 4. 复现方式（三步）

1. `git clone --depth 1 --branch v5.1.107.92 https://github.com/termux/proot.git proot-source`
2. `git -C proot-source apply tools/patches/proot-legacy-syscalls.patch`（另需 talloc 头文件，见 `tools/build/README.md`）
3. `pwsh tools/build/build-proot.ps1 -TallocInclude <talloc 目录> -ShmemLib build_proot_out/shmem -Install`
   （shmem 库用 `pwsh tools/build/build-shmem.ps1` 生成；shim 直接用 NDK clang 编，见 README）
