#!/usr/bin/env bash
#
# build-g2-kernel.sh — build the G2 (Cliffs) SD-only boot-test candidate.
#
# Phase B pipeline, mirroring the pocknix/ROCKNIX kernel recipe structure:
#   stock kernel.org linux-${KERNEL_VERSION}   (pinned in kernel/g2/kernel.conf)
#     + G2 DTS input set integrated into arch/arm64/boot/dts/qcom/
#       (with an ensured Makefile entry so it builds as a real DT target)
#     + the G2 config fragment (kernel/g2/config/linux.aarch64.conf)
#   -> make Image dtbs (kernel's own DT build produces the G2 DTB)
#
# Optionally also builds the minimal busybox rootfs and assembles the
# microSD image (boot + rootfs partitions) used for the first removable-media
# Linux boot experiment.
#
# SAFETY (absolute project rule)
#  - This script only creates files in the repository's build/ output tree or
#    an explicit --outdir. It never writes a block device unless the operator
#    passes --device AND that device passes the removable-microSD guards.
#  - Internal Android/UFS/ABL/vbmeta/dtbo/GPT storage is NEVER modified.
#  - Removing the microSD must always leave the stock Android boot path intact.
#
# Usage:
#   scripts/build-g2-kernel.sh [--outdir DIR] [--jobs N] [--with-rootfs] [--device /dev/mmcblkN] [--dry-run]
#
# Steps (all reproducible):
#   1. download + sha256-verify linux-${KERNEL_VERSION} (kernel/g2/kernel.conf)
#   2. apply the G2 patch stack under kernel/g2/patches/ (patch -p1 --forward)
#   3. copy kernel/g2/dts/qcom/g2-cliffs-sd.dts into arch/arm64/boot/dts/qcom/
#   4. ensure "dtb-\$(CONFIG_ARCH_QCOM) += g2-cliffs-sd.dtb" in the qcom Makefile
#   5. make defconfig; merge kernel/g2/config/linux.aarch64.conf fragment
#   6. make Image dtbs  (G2 DTB built by the kernel DT build system)
#   7. optional: busybox minimal rootfs (scripts/build-g2-rootfs.sh)
#   8. optional: microSD image (scripts/prepare-g2-sd-image.sh --kernel --dtb --rootfs)
#   9. non-destructive validation (scripts/validate-g2-sd-artifacts.sh)

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/kernel/g2/kernel.conf"

OUTDIR="${G2_BUILD_DIR:-$ROOT/build/g2}"
JOBS="$(nproc)"
WITH_ROOTFS=0
DEVICE=""
DRY_RUN=0
CACHE_DIR="${G2_CACHE_DIR:-$ROOT/build/cache}"

usage() {
    cat <<EOF
Usage: $0 [options]
  --outdir DIR     build output directory (default: $OUTDIR)
  --jobs N         make jobs (default: nproc)
  --with-rootfs    also build the busybox minimal rootfs
  --device PATH    write the SD image to a removable microSD (gated, confirmed)
  --dry-run        validate plan without building
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"; }

for t in curl tar xz make gcc sha256sum patch; do need "$t"; done

while [ $# -gt 0 ]; do
    case "$1" in
        --outdir) OUTDIR="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        --with-rootfs) WITH_ROOTFS=1; shift ;;
        --device) DEVICE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
done

mkdir -p "$OUTDIR" "$CACHE_DIR"
echo "== G2 SD-only kernel build (Phase B) =="
echo "  kernel version : $KERNEL_VERSION"
echo "  kernel source  : $KERNEL_SOURCE_URL"
echo "  sha256 pin     : $KERNEL_SOURCE_SHA256"
echo "  output dir     : $OUTDIR"
echo "  jobs           : $JOBS"

if [ "$DRY_RUN" = "1" ]; then
    echo "Dry-run: plan valid; nothing built. Safety: no device write performed."
    exit 0
fi

# --- 1. fetch + verify ------------------------------------------------------
TB="$CACHE_DIR/linux-$KERNEL_VERSION.tar.xz"
if [ ! -f "$TB" ]; then
    echo ">> downloading kernel source: $KERNEL_SOURCE_URL"
    curl -fL --retry 3 -o "$TB" "$KERNEL_SOURCE_URL"
fi
echo ">> verifying kernel source sha256"
echo "$KERNEL_SOURCE_SHA256  $TB" | sha256sum -c - || die "kernel source sha256 mismatch"

KSRC="$OUTDIR/linux-$KERNEL_VERSION"
if [ ! -d "$KSRC" ]; then
    echo ">> extracting kernel source"
    mkdir -p "$OUTDIR"
    tar -xf "$TB" -C "$OUTDIR"
fi
echo "  kernel source  : $KSRC"

# --- 2. apply the G2 patch stack (kernel/g2/patches/*.patch) -----------------
echo ">> applying G2 patch stack from kernel/g2/patches/"
PATCHES_DIR="$ROOT/kernel/g2/patches"
if [ -d "$PATCHES_DIR" ]; then
    for P in "$PATCHES_DIR"/*.patch; do
        [ -f "$P" ] || continue
        echo "  applying: $(basename "$P")"
        (cd "$KSRC" && patch -p1 --forward --batch < "$P") || die "patch failed: $P"
    done
else
    echo "  (no patches directory: $PATCHES_DIR)"
fi

# --- 3. integrate the G2 DTS into the real kernel DT build target ----------
echo ">> integrating G2 DTS into arch/arm64/boot/dts/qcom/"
G2_DTS_SRC="$ROOT/kernel/g2/dts/qcom/g2-cliffs-sd.dts"
G2_DTS_DST="$KSRC/arch/arm64/boot/dts/qcom/g2-cliffs-sd.dts"
G2_MAKEFILE="$KSRC/arch/arm64/boot/dts/qcom/Makefile"
[ -f "$G2_DTS_SRC" ] || die "G2 DTS not found: $G2_DTS_SRC"
cp -f "$G2_DTS_SRC" "$G2_DTS_DST"
if ! grep -q "g2-cliffs-sd.dtb" "$G2_MAKEFILE"; then
    printf '\n# G2 SD-only target (Retroid Pocket G2 / Cliffs)\n' >> "$G2_MAKEFILE"
    printf 'dtb-$(CONFIG_ARCH_QCOM) += g2-cliffs-sd.dtb\n' >> "$G2_MAKEFILE"
fi
echo "  integrated: $G2_DTS_DST"

# --- 4. configure + build ---------------------------------------------------
KBUILD="$OUTDIR/kbuild"
kmake() { make -C "$KSRC" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" O="$KBUILD" "$@"; }

echo ">> configuring kernel (defconfig + G2 config fragment)"
kmake defconfig >/dev/null
FRAG="$ROOT/kernel/g2/config/linux.aarch64.conf"
if [ -s "$FRAG" ]; then
    "$KSRC/scripts/kconfig/merge_config.sh" -m -O "$KBUILD" \
        "$KBUILD/.config" "$FRAG" >/dev/null
fi
kmake olddefconfig >/dev/null

echo ">> building Image dtbs (this builds the G2 DTB via the kernel DT build)"
kmake -j"$JOBS" Image dtbs

echo
echo "== Build results =="
IMAGE="$KBUILD/arch/arm64/boot/Image"
DTB="$KBUILD/arch/arm64/boot/dts/qcom/g2-cliffs-sd.dtb"
[ -f "$IMAGE" ] || die "kernel Image missing: $IMAGE"
[ -f "$DTB" ] || die "G2 DTB missing: $DTB"
echo "  kernel Image : $IMAGE ($(stat -c%s "$IMAGE") bytes)"
echo "  G2 DTB       : $DTB ($(stat -c%s "$DTB") bytes)"
echo "  kernelrelease: $(cat "$KBUILD/include/config/kernel.release")"

# --- 4/5. optional rootfs + image -------------------------------------------
if [ "$WITH_ROOTFS" = "1" ]; then
    echo ">> building minimal busybox rootfs"
    "$ROOT/scripts/build-g2-rootfs.sh" --outdir "$OUTDIR/rootfs"
fi

if [ -n "$DEVICE" ] || [ "$WITH_ROOTFS" = "1" ]; then
    ARGS=(--kernel "$IMAGE" --dtb "$DTB")
    if [ "$WITH_ROOTFS" = "1" ]; then
        ARGS+=(--rootfs "$OUTDIR/rootfs")
    fi
    if [ -n "$DEVICE" ]; then
        ARGS+=(--device "$DEVICE")
    fi
    echo ">> preparing microSD image"
    "$ROOT/scripts/prepare-g2-sd-image.sh" "${ARGS[@]}"
fi

echo
echo "Pipeline complete. Run scripts/validate-g2-sd-artifacts.sh for non-destructive validation."
