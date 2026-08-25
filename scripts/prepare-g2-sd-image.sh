#!/usr/bin/env bash
#
# prepare-g2-sd-image.sh — assemble the G2 SD-only microSD image (Phase B).
#
# Builds a GPT image FILE with:
#   1. boot partition (EFI/vfat, label G2-BOOT): boot/Image, boot/g2-cliffs-sd.dtb,
#      extlinux/extlinux.conf
#   2. rootfs partition (Linux/ext4, label G2-ROOT): minimal busybox rootfs
#
# SAFETY (absolute project rule)
#  - Writes only to the --output image FILE by default.
#  - --device writes to a REMOVABLE microSD path only (/dev/mmcblk[1-9]*),
#    and only after explicit confirmation. Internal storage patterns
#    (/dev/sda*, /dev/sdb*, /dev/nvme*, /dev/mmcblk0*) are always refused.
#  - Internal Android/UFS/ABL/vbmeta/dtbo/GPT storage is NEVER modified.
#  - Removing the microSD preserves the stock Android boot path.
#
# Usage:
#   scripts/prepare-g2-sd-image.sh --kernel <Image> --dtb <g2.dtb> --rootfs <dir>
#     [--bootconfig <extlinux.conf>] [--output <img>] [--size <MiB>] [--device <path>] [--dry-run]

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
        SUDO="sudo -n"
    fi
fi
KERNEL=""
DTB=""
ROOTFS=""
BOOTCONFIG="$ROOT/config/g2-sd/extlinux.conf"
OUTPUT="$ROOT/build/g2/g2-cliffs-sd.img"
SIZE_MIB=2048
DEVICE=""
DRY_RUN=0

# Internal Android/UFS device-name patterns. Never written by this script.
# G2 evidence: internal boot device is soc/1d84000.ufshc -> UFS (sda); the
# removable microSD is sdhci@8804000 -> mmc1 -> mmcblk1.
INTERNAL_STORAGE_PATTERNS="^(/dev/)?(sda|sdb|sdc|nvme[0-9]|mmcblk0)([0-9p]|$)"

usage() {
    cat <<EOF
Usage: $0 [options]
  --kernel <path>     Linux kernel Image (required)
  --dtb <path>        G2 DTB (required; built by scripts/build-g2-kernel.sh)
  --rootfs <path>     minimal rootfs directory or tarball (required)
  --bootconfig <path> boot config (default: config/g2-sd/extlinux.conf)
  --output <path>     output image file (default: $OUTPUT)
  --size <MiB>        image size in MiB (default: $SIZE_MIB)
  --device <path>     write to a removable microSD device (EXPLICIT + confirmed)
  --dry-run           validate and print the plan without writing anything
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

confirm() {
    echo -n "$1 [y/N] "
    read -r ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ]
}

while [ $# -gt 0 ]; do
    case "$1" in
        --kernel) KERNEL="$2"; shift 2 ;;
        --dtb) DTB="$2"; shift 2 ;;
        --rootfs) ROOTFS="$2"; shift 2 ;;
        --bootconfig) BOOTCONFIG="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --size) SIZE_MIB="$2"; shift 2 ;;
        --device) DEVICE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

echo "== G2 microSD image preparation (Phase B) =="

[ -n "$KERNEL" ] || die "--kernel is required"
[ -n "$DTB" ] || die "--dtb is required"
[ -n "$ROOTFS" ] || die "--rootfs is required"
[ -r "$KERNEL" ] || die "kernel Image not readable: $KERNEL"
[ -r "$DTB" ] || die "DTB not readable: $DTB"
[ -e "$ROOTFS" ] || die "rootfs not found: $ROOTFS"
[ -r "$BOOTCONFIG" ] || die "boot config not readable: $BOOTCONFIG"

head -c4 "$DTB" | od -An -tx1 | tr -d ' ' | grep -q "d00dfeed" || die "DTB does not have a valid FDT magic: $DTB"

echo
echo "Input plan:"
echo "  kernel     : $KERNEL"
echo "  dtb        : $DTB"
echo "  rootfs     : $ROOTFS"
echo "  bootconfig : $BOOTCONFIG"
echo "  output     : $OUTPUT ($SIZE_MIB MiB)"
[ -n "$DEVICE" ] && echo "  device     : $DEVICE"

# --- Safety guards -----------------------------------------------------------
if [ -n "$DEVICE" ]; then
    if [[ "$(basename "$DEVICE")" =~ $INTERNAL_STORAGE_PATTERNS ]]; then
        die "REFUSED: '$DEVICE' matches an internal Android storage pattern; only removable microSD is writable."
    fi
    case "$DEVICE" in
        /dev/mmcblk[1-9]*) ;;
        *) die "REFUSED: '$DEVICE' is not a removable microSD path (/dev/mmcblk[1-9]*)." ;;
    esac
    [ -e "$DEVICE" ] || die "device not present: $DEVICE"
    [ -b "$DEVICE" ] || die "not a block device: $DEVICE"
    confirm "WARNING: This will DESTROY the content of $DEVICE (microSD only). Continue?" || die "aborted by user"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "Dry-run: inputs valid, plan printed. Nothing written."
    echo "Safety: internal Android/UFS/ABL/vbmeta/dtbo storage is never modified."
    exit 0
fi

for tool in sgdisk mkfs.vfat mkfs.ext4 losetup mount umount; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done
mkdir -p "$(dirname "$OUTPUT")"

echo
echo "Building image file: $OUTPUT ($SIZE_MIB MiB)"
truncate -s "${SIZE_MIB}M" "$OUTPUT" || die "failed to allocate image file"

sgdisk -Z "$OUTPUT" >/dev/null || die "sgdisk -Z failed"
sgdisk -n 1:1M:+256M -t 1:ef00 -c 1:"G2-BOOT" "$OUTPUT" >/dev/null || die "sgdisk boot partition failed"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"G2-ROOTFS" "$OUTPUT" >/dev/null || die "sgdisk rootfs partition failed"

LOOP=""
CLEANUP() {
    [ -n "$LOOP" ] && $SUDO losetup -d "$LOOP" 2>/dev/null || true
    [ -n "${BOOTMNT:-}" ] && $SUDO umount "$BOOTMNT" 2>/dev/null || true
    [ -n "${ROOTMNT:-}" ] && $SUDO umount "$ROOTMNT" 2>/dev/null || true
}
trap CLEANUP EXIT

echo "Attaching loop device (image file only)..."
LOOP="$($SUDO losetup --show --find --partscan "$OUTPUT")" || die "losetup failed"
[ -b "${LOOP}p1" ] || die "loop partition 1 not available"
[ -b "${LOOP}p2" ] || die "loop partition 2 not available"

$SUDO mkfs.vfat -n G2BOOT "${LOOP}p1" >/dev/null || die "mkfs.vfat boot failed"
$SUDO mkfs.ext4 -q -L G2ROOT "${LOOP}p2" || die "mkfs.ext4 rootfs failed"

BOOTMNT="$(dirname "$OUTPUT")/mnt-boot"
ROOTMNT="$(dirname "$OUTPUT")/mnt-root"
mkdir -p "$BOOTMNT" "$ROOTMNT"

echo "Staging boot partition..."
$SUDO mount "${LOOP}p1" "$BOOTMNT" || die "mount boot failed"
$SUDO mkdir -p "$BOOTMNT/boot" "$BOOTMNT/extlinux"
$SUDO cp "$KERNEL" "$BOOTMNT/boot/Image" || die "copy kernel failed"
$SUDO cp "$DTB" "$BOOTMNT/boot/" || die "copy dtb failed"
$SUDO cp "$BOOTCONFIG" "$BOOTMNT/extlinux/extlinux.conf" || die "copy bootconfig failed"
sync
$SUDO umount "$BOOTMNT" || die "umount boot failed"
BOOTMNT=""

echo "Staging rootfs partition..."
$SUDO mount "${LOOP}p2" "$ROOTMNT" || die "mount rootfs failed"
if [ -d "$ROOTFS" ]; then
    $SUDO cp -a "$ROOTFS"/. "$ROOTMNT"/ || die "copy rootfs dir failed"
else
    $SUDO tar -x -C "$ROOTMNT" -f "$ROOTFS" || die "extract rootfs tarball failed"
fi
sync
$SUDO umount "$ROOTMNT" || die "umount rootfs failed"
ROOTMNT=""

$SUDO losetup -d "$LOOP"
LOOP=""
trap - EXIT

echo
echo "Image prepared: $OUTPUT"
echo "  kernel      : boot/Image"
echo "  dtb         : boot/$(basename "$DTB")"
echo "  bootconfig  : extlinux/extlinux.conf"
echo "  rootfs      : partition 2 (G2-ROOTFS)"
echo
echo "Safety summary:"
echo "  - Internal Android/UFS/ABL/vbmeta/dtbo/GPT storage: NOT modified."
echo "  - Image is microSD-only; removing the microSD preserves stock Android."
echo "  - Flashing/verification on physical G2 hardware is a separate step."
