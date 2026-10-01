#!/usr/bin/env bash
#
# Assemble the G2 minimal rootfs directory: static busybox (Ubuntu arm64
# busybox-static, pinned by sha256) plus rootfs/g2-mini (/sbin/init etc.).
# The output is a directory; build-g2-qcomabl-sd-image.sh turns it into p2 with
# ROOTFS_DIR=<dir>. Writes files only.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO/.build}"
OUT="${OUT:-$WORK/g2-minirootfs}"

BB_DEB="${BB_DEB:-busybox-static_1.36.1-6ubuntu3.1_arm64.deb}"
BB_URL="${BB_URL:-http://ports.ubuntu.com/ubuntu-ports/pool/main/b/busybox/$BB_DEB}"
BB_SHA256="${BB_SHA256:-d96535e0402c011e0ee43449799df2f4504d44b842e4f2b3a6cbc845508eaafc}"

die(){ echo "ERROR: $*" >&2; exit 1; }
for t in curl dpkg-deb sha256sum; do command -v "$t" >/dev/null || die "missing tool: $t"; done

mkdir -p "$WORK/busybox"
if [ ! -f "$WORK/busybox/$BB_DEB" ]; then
  curl -fsSL -o "$WORK/busybox/$BB_DEB" "$BB_URL"
fi
echo "$BB_SHA256  $WORK/busybox/$BB_DEB" | sha256sum -c - >/dev/null || die "checksum mismatch on $BB_DEB"
rm -rf "$WORK/busybox/x" && dpkg-deb -x "$WORK/busybox/$BB_DEB" "$WORK/busybox/x"
BB="$WORK/busybox/x/usr/bin/busybox"
[ -f "$BB" ] || die "busybox binary not found in $BB_DEB"

rm -rf "$OUT"
mkdir -p "$OUT"/{bin,sbin,usr/bin,usr/sbin,etc,proc,sys,dev,tmp,run,root,mnt/boot,var/log}
chmod 1777 "$OUT/tmp"
install -m 0755 "$BB" "$OUT/bin/busybox"

# Applet symlinks. The list comes from the binary itself; run it through
# qemu-user when building on a non-arm64 host. Fall back to a fixed list.
if [ "$(uname -m)" = aarch64 ]; then
  APPLETS=$("$BB" --list)
elif command -v qemu-aarch64-static >/dev/null; then
  APPLETS=$(qemu-aarch64-static "$BB" --list)
else
  APPLETS="sh ash mount umount mkdir ls cat echo dmesg grep awk sed cut tr head tail sleep sync clear printf uname wc tee basename find df free uptime ps kill poweroff reboot"
fi
for a in $APPLETS; do
  [ "$a" = busybox ] && continue
  case "$a" in
    init|halt|poweroff|reboot|mount|umount|getty|mdev|modprobe|insmod|rmmod|lsmod|ifconfig|route|sysctl|switch_root) d=sbin ;;
    *) d=bin ;;
  esac
  [ -e "$OUT/$d/$a" ] || ln -s /bin/busybox "$OUT/$d/$a"
done

# Overlay (our /sbin/init replaces busybox's init applet link).
rm -f "$OUT/sbin/init"
cp -a "$REPO/rootfs/g2-mini/." "$OUT/"
chmod 0755 "$OUT/sbin/init"

echo "rootfs: $OUT ($(du -sh "$OUT" | cut -f1), $(echo $APPLETS | wc -w) applets)"
