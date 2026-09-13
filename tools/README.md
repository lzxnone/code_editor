# tools/ —— 构建与自检工具

```
tools/
├── build/                   构建 proot / libandroid-shmem（用法见 build/README.md）
│   ├── build-proot.ps1
│   └── build-shmem.ps1
├── patches/                 构建时应用的本地补丁
│   ├── proot-legacy-syscalls.patch            proot 层"传统 syscall 现代化"
│   └── libandroid-shmem-runtime-ashmem.patch  shmem 后端改成运行时选择
└── container-selfcheck/     容器自检（用法见 container-selfcheck/README.md）
    ├── probe3/4/5/6/8.c     裸 syscall 探针（策略、apk 安装序列、空路径 stat、SysV IPC、fork 变体）
    ├── selfcheck.sh         一键验收
    └── guest-run.sh         adb 跑手（免重装 APK 在容器里跑命令）
```

**日常开发不需要它们**：proot / shmem / shim 的成品都已提交在
`android/app/src/main/jniLibs/` 与 `assets/shims/`。只有在升级 proot、修改补丁、或换 ABI 时才需要重新构建。

⚠️ 自检里的 `guest-run.sh` 经 `run-as` 启动，**没有** Android 的 app seccomp 过滤器
（容器里看到的 `Seccomp:2` 是 proot 自己的加速过滤器）。涉及平台策略的结论必须在
**App 自己的会话**里验证 —— 详见 `container-selfcheck/README.md`。
