#!/bin/sh
# acceptance for the slimmed shim (arm64: utimensat only)
exec >/root/acc.log 2>&1

echo "### slimmed-shim acceptance ###"
echo "shim: $(ls -l /lib/libfix_seccomp.so)"

echo
echo "=== [1] DNS via NATIVE musl resolver (no override on arm64) ==="
S=$(date +%s); apk update; echo "apk_update_rc=$?"; E=$(date +%s); echo "elapsed=$((E-S))s"
wget -T 8 -O /dev/null http://example.com/ ; echo "wget_rc=$?"

echo
echo "=== [2] hardlink-heavy package, fresh cycle (utimensat fix) ==="
apk del tzdata >/dev/null 2>&1
apk add tzdata 2>&1 | head -8
echo "tzdata_rc=$?"
ls -l /usr/share/zoneinfo/Africa/Accra 2>&1

echo
echo "=== [3] package with trigger (fork/pipe/dup2 no longer overridden) ==="
apk del tree >/dev/null 2>&1
apk add tree; echo "tree_rc=$?"

echo
echo "=== [4] broken flags (expect none) ==="
awk '/^P:/{p=$0} /^f:/{print "BROKEN: "p" "$0}' /lib/apk/db/installed
echo "(end)"

echo
echo "=== [5] stat family still fine without the shim ==="
/root/probe5

echo
echo "=== [6] syscall baseline ==="
/root/probe3 | tail -12

echo
echo "=== [7] coreutils-ish sanity ==="
ls -l /usr/bin/tree /usr/share/zoneinfo/Asia/Shanghai 2>&1
sha256sum /etc/profile >/dev/null 2>&1 && echo "sha256sum ok"
echo "pipe test: $(echo hi | cat)"
echo "subshell: $( (echo nested) )"

echo "### acceptance done ###"
