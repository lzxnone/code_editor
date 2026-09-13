# 容器自检工具（container-selfcheck）

在 **Android app 进程内**的 PRoot 容器里做系统调用级自检，用于定位"某个 syscall 被平台策略
拦掉 / PRoot 语义不对"这类问题。本目录是 2026-09-13 排查 `apk temporary error` /
`Failed to preserve modification time` 时用的工具，已固化为可复用资产。

结论与证据见仓库根目录 `CONTAINER_FIX_SUMMARY.md`。

---

## 组件

| 文件 | 作用 |
|---|---|
| `probe3.c` | 系统调用策略自检：`poll/ppoll/select/pselect6/epoll_wait(epoll_pwait)/fcntl/ioctl/utimensat/fstat/statfs/clone/unshare/chroot/getrandom`。**支持 x86_64 与 arm64**（两者系统调用表不同，代码里已按架构区分）。 |
| `probe4.c` | 复现 apk 安装动作序列：`建目录 → openat 解包 → utimensat 保 mtime → linkat 硬链接 → renameat 改名`，用来定位 PRoot `--link2symlink` 的问题。 |
| `probe5.c` | 检查 PRoot 对空路径 `newfstatat(fd,"",st,AT_EMPTY_PATH)` 的处理（曾用于判定旧 workaround 是否还必要）。 |
| `selfcheck.sh` | 容器内一键验收：`apk update` / 硬链接包全新安装 / 带触发器安装 / broken 标记 / 三个 probe。 |
| `guest-run.sh` | **免重装 APK** 的 adb 侧跑手：用 `pm path` 推导原生库目录，自己拼 PRoot 命令行，在容器里执行任意命令。 |

## 编译探针

```bash
NDK=<ndk>/toolchains/llvm/prebuilt/<host>/bin
# arm64 真机
"$NDK/clang" --target=aarch64-linux-android21 -nostdlib -static -fno-stack-protector -O1 -o probe3 probe3.c
# x86_64 模拟器
"$NDK/clang" --target=x86_64-linux-android21  -nostdlib -static -fno-stack-protector -O1 -o probe3 probe3.c
```

无 libc、无依赖：所有系统调用直接发 `svc #0` / `syscall`，结果用 `write(2)` 打印。

## 用法（真机 / 模拟器都适用）

前提：app 为 **debug** 构建（`run-as` 需要），设备已连 adb。

```bash
PKG=com.example.code_editor
BASE=/data/data/$PKG/files/distros/alpine
R=$BASE/rootfs

# 1) 把探针与自检脚本放进容器
adb push probe3 /data/local/tmp/probe3
adb push selfcheck.sh /data/local/tmp/selfcheck.sh
adb shell "run-as $PKG sh -c 'cat /data/local/tmp/probe3 > $R/root/probe3; chmod 755 $R/root/probe3; \
  cat /data/local/tmp/selfcheck.sh > $R/root/selfcheck.sh; chmod 755 $R/root/selfcheck.sh'"

# 2) 在容器里跑（adb 侧免重装）
adb shell "run-as $PKG sh /data/local/tmp/guest-run.sh /bin/sh /root/selfcheck.sh"
# 或者：push guest-run.sh 后
adb shell "run-as $PKG sh /data/local/tmp/guest-run.sh /root/probe3"

# 3) 读结果
adb shell "run-as $PKG cat $R/root/acc.log"
```

### 在「App 自己的终端会话」里跑（需要 app 上下文时）

App 上下文（有 zygote 装上的 seccomp filter）才是线上真实环境。两种方式：

- 直接在终端里敲：`sh /root/selfcheck.sh`
- **免打字**：把钩子挂到 `/etc/profile.d`，新会话自动执行（本目录不含该钩子文件，按需创建）：
  ```sh
  # <rootfs>/etc/profile.d/zz-selfcheck.sh
  ( sh /root/selfcheck.sh >/dev/null 2>&1 ) &
  ```
  然后重启 App 并进入终端页，结果写入 `/root/acc.log`。

## 两条铁律

1. **不要在容器运行中原地覆盖 `/lib/libfix_seccomp.so`**：正在映射该文件的进程会 SIGSEGV
   （实测：会话 `proot info: vpid 1: terminated with signal 11`）。必须
   「写临时文件 → `mv` 重命名」。
2. **换 shim 后需要新起进程才生效**：已运行的进程仍映射旧库。用 `am force-stop` 重启 App，
   或直接新开一个会话。

## 已定位（供参考，不必重跑）

| 现象 | 结论 |
|---|---|
| `apk` 报 `temporary error (try again later)` | **x86_64 专属**：arm64 无 `poll/select` 系统调用；x86_64 有且被 app seccomp 封为 ENOSYS，musl 的 `#ifdef SYS_poll` 命中 ⇒ 解析器超时 ⇒ `EAI_AGAIN`。 |
| `apk` 报 `IO ERROR` | 同上（`select`），libfetch 失败时不设错误码。 |
| `Failed to preserve modification time`（tzdata 等硬链接包） | **跨架构**：Android 禁止 `link(2)` ⇒ PRoot 用 symlink + `.proot-meta-file.*` 模拟 ⇒ apk 跟随语义的 `utimensat` 落到隐藏名 ⇒ ENOENT ⇒ 包被标 broken。 |
| `newfstatat(fd,"",st,AT_EMPTY_PATH)` | PRoot 处理正常（=0），旧的 workaround 已删除。 |
| `--sysvipc` | 本项目 `libproot.so` **不支持**（`unknown option`），不能加；Termux 的 proot 是带 libandroid-shmem 的 fork 版。 |
| `openat(dir, O_DIRECTORY)` | 在本项目 proot 下返回 **EINVAL**（`O_PATH|O_DIRECTORY` 正常）——已知怪癖，当前无功能影响。 |
