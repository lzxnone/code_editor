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
- 若将来需要 `--sysvipc`/完整 uname 伪装，必须改用 Termux 的 proot fork（`github.com/termux/proot`，带 `PROOT_WITH_LIBANDROID_SHMEM`）重新编译。
