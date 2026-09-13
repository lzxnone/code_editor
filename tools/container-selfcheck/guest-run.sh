#!/system/bin/sh
# run an arbitrary guest binary inside the PRoot container (adb harness)
PKG=com.example.code_editor
BASE=/data/data/$PKG/files/distros/alpine
ROOT=$BASE/rootfs
LIBDIR=$(pm path $PKG 2>/dev/null | head -1 | sed 's|package:||; s|/base.apk$||')/lib/arm64
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
