#!/usr/bin/env bash
#
# build-g2-rootfs.sh — build the minimal busybox rootfs for the first G2
# microSD boot-test candidate.
#
# This produces a plain ext4-ready rootfs directory (no initramfs) containing:
#   - statically linked aarch64 busybox (all core applets)
#   - /init (first-boot-test init script) and busybox inittab/rcS
#   - mount points for proc/sys/dev
#
# SAFETY
#  - Only creates files under --outdir. No block device is written.
#  - No internal Android/UFS/ABL/vbmeta/dtbo storage is ever touched.
#
# The rootfs is intentionally minimal: its purpose is to yield the first
# observable Linux boot evidence from the G2 (kernel log -> SDHCI probe ->
# rootfs mount). It is NOT a SteamOS desktop.
#
# Usage: scripts/build-g2-rootfs.sh [--outdir DIR] [--jobs N]

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${G2_ROOTFS_DIR:-$ROOT/build/g2/rootfs}"
JOBS="$(nproc)"
BUSYBOX_VERSION="1.36.1"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"
CACHE_DIR="${G2_CACHE_DIR:-$ROOT/build/cache}"

for t in curl tar make gcc; do command -v "$t" >/dev/null 2>&1 || {
    echo "ERROR: required tool not found: $t" >&2; exit 2; }; done

while [ $# -gt 0 ]; do
    case "$1" in
        --outdir) OUTDIR="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

mkdir -p "$OUTDIR" "$CACHE_DIR"
echo "== G2 minimal rootfs build =="
echo "  busybox        : $BUSYBOX_VERSION"
echo "  output dir     : $OUTDIR"

TB="$CACHE_DIR/busybox-${BUSYBOX_VERSION}.tar.bz2"
if [ ! -f "$TB" ]; then
    echo ">> downloading busybox: $BUSYBOX_URL"
    curl -fL --retry 3 -o "$TB" "$BUSYBOX_URL"
fi

SRC="$CACHE_DIR/busybox-${BUSYBOX_VERSION}"
if [ ! -d "$SRC" ]; then
    echo ">> extracting busybox"
    tar -xf "$TB" -C "$CACHE_DIR"
fi

CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
"${CROSS}gcc" --version >/dev/null 2>&1 || {
    echo "ERROR: aarch64 cross toolchain not found (need ${CROSS}gcc)" >&2; exit 2; }

echo ">> configuring busybox (static, minimal)"
make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" defconfig >/dev/null 2>&1
sed -i "s|^CONFIG_PREFIX=.*|CONFIG_PREFIX=\"$OUTDIR\"|" "$SRC/.config"
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$SRC/.config"
# 'tc' applet fails to build against Linux 7.x kernel headers; disable it.
sed -i 's/^CONFIG_TC=y/# CONFIG_TC is not set/' "$SRC/.config" || true

echo ">> building busybox (this can take several minutes)"
make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$JOBS" >/dev/null
make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" install >/dev/null

echo ">> assembling rootfs skeleton"
cd "$OUTDIR"
mkdir -p proc sys dev tmp run etc/init.d mnt root home/root
cat > init <<'EOF'
#!/bin/sh
# G2 minimal rootfs init (SD-only first-boot test)
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
echo "G2 SD Linux first-boot test init: $(uname -r)"
exec /bin/sh
EOF
chmod +x init
cat > etc/inittab <<'EOF'
::sysinit:/etc/init.d/rcS
::askfirst:/bin/sh
EOF
cat > etc/init.d/rcS <<'EOF'
#!/bin/sh
mount -a
echo "G2 SD Linux: rcS running"
EOF
chmod +x etc/init.d/rcS
cat > etc/fstab <<'EOF'
proc     /proc     proc     defaults 0 0
sysfs    /sys      sysfs    defaults 0 0
devtmpfs /dev      devtmpfs defaults 0 0
EOF

echo
echo "== Rootfs result =="
echo "  rootfs dir     : $OUTDIR"
echo "  busybox        : $(stat -c%s "$OUTDIR/bin/busybox") bytes (static aarch64)"
echo "  total size     : $(du -sh "$OUTDIR" | cut -f1)"
echo "  This is a first-boot-test rootfs only, not a desktop."
