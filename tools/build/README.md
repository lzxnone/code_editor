# tool/ —— proot / shmem 的构建与补丁

这里的产物**已经编译好并提交在仓库里**（`android/app/src/main/jniLibs/*/lib*.so` 与 `assets/shims/*/`），
正常开发**不需要**重新构建。只有在升级 proot、改补丁、或换 ABI 时才需要。

构建所需的中间目录（`proot-source/`、`build_proot_deps/`、`build_proot_out/`）都在 `.gitignore` 里，
可随时删除、按下面步骤重建。

---

## 一、重建 proot（含本地补丁）

```powershell
# 1) 取源码（必须是 termux 的 fork —— 我们需要它的 --link2symlink/--kill-on-exit/l2s）
git clone --depth 1 --branch v5.1.107.92 https://github.com/termux/proot.git proot-source

# 2) 应用本地补丁（proot 层"传统 syscall 现代化"，见补丁头部注释）
git -C proot-source apply tools\patches\proot-legacy-syscalls.patch

# 3) 取 talloc 头文件（编译期需要；libtalloc.so 用仓库里现成的）
#    任一 talloc 2.x 版本即可：
git clone --depth 1 --filter=blob:none --sparse https://github.com/samba-team/samba.git build_proot_deps\samba
git -C build_proot_deps\samba sparse-checkout set lib/talloc
#    之后 -TallocInclude 指向 build_proot_deps\samba\lib\talloc

# 4) 编译（双架构，loader 内嵌，链接仓库里的 libtalloc.so / libandroid-shmem.so）
pwsh tools\build\build-proot.ps1 -TallocInclude build_proot_deps\samba\lib\talloc `
                          -ShmemLib build_proot_out\shmem `
                          -Install
```

## 二、重建 libandroid-shmem（仅当要改 `--sysvipc` 后端时）

```powershell
pwsh tools\build\build-shmem.ps1      # 自动克隆 termux/libandroid-shmem 并应用 tools\patches\libandroid-shmem-runtime-ashmem.patch
```

## 三、重建 shim

shim 是 freestanding C（无 libc），直接用 NDK clang 编：

```powershell
$ndk = "D:\Android\SDK\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin"
$src = "android\app\src\main\cpp"
foreach ($t in @(@("x86_64","x86_64-linux-android24"), @("arm64-v8a","aarch64-linux-android24"))) {
  & "$ndk\clang.exe" --target=$($t[1]) -shared -fPIC -nostdlib -ffreestanding `
     -fno-builtin -fno-stack-protector -O2 -o "assets\shims\$($t[0])\libfix_seccomp.so" `
     "$src\libfix_seccomp.c" "$src\libfix_dns.c"
  Copy-Item "assets\shims\$($t[0])\libfix_seccomp.so" "android\app\src\main\assets\shims\$($t[0])\libfix_seccomp.so" -Force
}
```

## 四、补丁清单

| 补丁 | 作用 |
|---|---|
| `patches/proot-legacy-syscalls.patch` | proot 层把 Android 在 x86_64 上拒绝的传统 syscall 改写成现代等价形式（`poll→ppoll`、`select→pselect6`、`epoll_wait→epoll_pwait`、`pipe→pipe2`、`dup2→dup3`、`fork/vfork→clone(SIGCHLD)`、`clone` 去掉 `CLONE_VM\|CLONE_VFORK`、`clone3→clone`）。新增 `src/syscall/legacy.c`，并在 `src/syscall/seccomp.c` 的过滤表里登记这些调用 |
| `patches/libandroid-shmem-runtime-ashmem.patch` | `libandroid-shmem` 的后端选择从**编译期**（`__ANDROID_API__ >= 26`）改成**运行时** `dlsym(ASharedMemory_*)`，拿不到再回退 `/dev/ashmem`。原因：Android 11+ 对应用进程已拒绝 `/dev/ashmem`（实测 EACCES），而 API 26 编译又会把设备门槛抬到 8.0 |

## 五、注意

- **不要用 proot-me 上游**：`--link2symlink`（本环境禁止 `link(2)`，必须用 l2s 模拟）与 `--kill-on-exit` 都来自 termux fork。
- **不要原地覆盖运行中的 shim**：必须「写临时文件 → `mv`」，否则正在映射它的进程会 SIGSEGV。
- 构建产物请用 `-Install` 安装（会自动把旧文件备份到 `build_proot_out/backup/`）。
