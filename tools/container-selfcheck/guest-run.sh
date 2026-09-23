#!/system/bin/sh
# run an arbitrary guest binary inside the PRoot container (adb harness)
# 注意：这条路径经 run-as 启动，**没有** Android 的 app seccomp 过滤器
#（容器里看到的 Seccomp:2 是 proot 自己的加速过滤器）。因此涉及
# poll/select 等平台策略的结论必须在 App 自己的会话里验证。
PKG=com.lzxnone.code_editor
BASE=/data/data/$PKG/files/distros/alpine
ROOT=$BASE/rootfs
# 按设备 ABI 选择（arm64-v8a / x86_64），避免写死导致换架构失效
ABI=$(getprop ro.product.cpu.abi)
[ -z "$ABI" ] && ABI=arm64-v8a
LIBDIR=$(pm path $PKG 2>/dev/null | head -1 | sed 's|package:||; s|/base.apk$||')/lib/$ABI
[ -d "$LIBDIR" ] || LIBDIR=$(pm path $PKG 2>/dev/null | head -1 | sed 's|package:||; s|/base.apk$||')/lib/arm64
export LD_LIBRARY_PATH=$LIBDIR
export PROOT_TMP_DIR=/data/data/$PKG/cache
export PROOT_L2S_DIR=$BASE/.l2s
P=$LIBDIR/libproot.so
cd $ROOT
exec $P --kill-on-exit --link2symlink -0 -r . -b /dev -b /dev/urandom:/dev/random \
  -b $BASE/shm:/dev/shm -b /proc -b /sys -b /data/data/$PKG/cache:/tmp -w /root \
  /usr/bin/env -i HOME=/root USER=root TERM=dumb LANG=C.UTF-8 \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  LD_PRELOAD=/lib/libfix_seccomp.so "$@"
