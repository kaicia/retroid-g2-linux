#!/usr/bin/env bash
#
# prepare-g2-sd-image.sh
#
# Stage B: first G2 microSD image preparation harness (NON-DESTRUCTIVE by
# default).
#
# This script builds a G2 SD-only image FILE. It does NOT write to any block
# device unless the operator explicitly passes --device with a REMOVABLE
# microSD path AND confirms the target. It NEVER touches internal Android
# storage (UFS/boot/vendor_boot/dtbo/vbmeta/ABL/GPT).
#
# Inputs (must be provided; the repository does not yet contain a kernel or
# rootfs, so at least --kernel, --dtb and --rootfs are required):
#   --kernel <path>   Linux kernel Image (aarch64)
#   --dtb    <path>   G2 DTB (use dts/g2/g2-cliffs-sd.dts compiled via
#                     scripts/validate-g2-cliffs-dts.sh)
#   --rootfs <path>   minimal root filesystem (tarball or directory)
#   --bootconfig <path>  boot configuration (default: config/g2-sd/extlinux.conf)
#   --output <path>   output image FILE (default: build/g2-cliffs-sd.img)
#   --size <MiB>      image size in MiB (default: 4096)
#   --device <path>   WRITE to a removable microSD device. Requires explicit
#                     confirmation and passes strict internal-storage guards.
#   --dry-run         validate inputs and print plan without creating anything
#
# Exit codes: 0 = ok, 1 = validation/operational failure, 2 = usage error.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Use sudo automatically for privileged block-device operations when the
# current user is not root. Never prompts for a password interactively.
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
OUTPUT="$ROOT/build/g2-cliffs-sd.img"
SIZE_MIB=4096
DEVICE=""
DRY_RUN=0

# Block-device names that belong to the internal Android/UFS installation.
# Never written by this script under any circumstance.
#
# G2 evidence (docs/boot-chain-comparison.md, dumps/g2/*.txt):
#   - internal Android boot device : soc/1d84000.ufshc -> internal UFS (sda)
#   - external microSD path       : sdhci@8804000 -> mmc1 -> mmcblk1
# Therefore the removable microSD slot is mmcblk[1-9], while sdX/nvme*
# and mmcblk0 are treated as internal storage.
INTERNAL_STORAGE_PATTERNS="^(/dev/)?(sda|sdb|sdc|nvme[0-9]|mmcblk0)([0-9p]|$)"

usage() {
    cat <<EOF
Usage: $0 [options]
  --kernel <path>    Linux kernel Image (required)
  --dtb <path>       G2 DTB file (required)
  --rootfs <path>    minimal rootfs tarball or directory (required)
  --bootconfig <path> boot configuration file (default: config/g2-sd/extlinux.conf)
  --output <path>    output image file (default: build/g2-cliffs-sd.img)
  --size <MiB>       image size in MiB (default: 4096)
  --device <path>    write to a removable microSD device (EXPLICIT + confirmed)
  --dry-run          validate and print the plan without writing anything
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

echo "== G2 microSD image preparation (Stage B) =="

[ -n "$KERNEL" ] || die "--kernel is required (repository has no kernel yet; supply the Image build input)"
[ -n "$DTB" ] || die "--dtb is required (compile dts/g2/g2-cliffs-sd.dts first)"
[ -n "$ROOTFS" ] || die "--rootfs is required (repository has no rootfs yet; supply a minimal rootfs tarball/dir)"

[ -r "$KERNEL" ] || die "kernel Image not readable: $KERNEL"
[ -r "$DTB" ] || die "DTB not readable: $DTB"
[ -e "$ROOTFS" ] || die "rootfs not found: $ROOTFS"
[ -r "$BOOTCONFIG" ] || die "boot configuration not readable: $BOOTCONFIG"

# Validate DTB is a device tree blob.
head -c 4 "$DTB" | od -An -tx1 | grep -q "d0 0d fe ed" || die "DTB does not have a valid FDT magic: $DTB"

# Validate the G2 DTB carries the expected SDHCI node.
if command -v fdtget >/dev/null 2>&1; then
    NODE=$(fdtget -l "$DTB" /soc 2>/dev/null | tr ' ' '\n' | grep -c sdhci || true)
    [ "$NODE" -ge 1 ] || echo "WARN: /soc/sdhci node not found in DTB (is this the G2 DTS?)"
fi

echo
echo "Input plan:"
echo "  kernel     : $KERNEL"
echo "  dtb        : $DTB"
echo "  rootfs     : $ROOTFS"
echo "  bootconfig : $BOOTCONFIG"
echo "  output     : $OUTPUT ($SIZE_MIB MiB)"
if [ -n "$DEVICE" ]; then
    echo "  device     : $DEVICE"
fi

# --- Safety guards -----------------------------------------------------------
if [ -n "$DEVICE" ]; then
    # Refuse obvious internal-storage device names.
    if [[ "$(basename "$DEVICE")" =~ $INTERNAL_STORAGE_PATTERNS ]]; then
        die "REFUSED: '$DEVICE' matches an internal Android storage pattern; this script only writes removable microSD media."
    fi
    # Only allow the removable microSD slot class /dev/mmcblk[1-9]*.
    # On the G2 the internal UFS presents as sdX (evidence: boot device
    # 1d84000.ufshc), so sdX/nvme*/mmcblk0 are always refused above.
    case "$DEVICE" in
        /dev/mmcblk[1-9]*)
            ;;
        *)
            die "REFUSED: '$DEVICE' is not a removable microSD path (/dev/mmcblk[1-9]*). Internal Android UFS must never be written."
            ;;
    esac
    [ -e "$DEVICE" ] || die "device not present: $DEVICE"
    [ -b "$DEVICE" ] || die "not a block device: $DEVICE"
    confirm "WARNING: This will DESTROY the content of $DEVICE (microSD only). Continue?" || die "aborted by user"
    echo "  (device write is gated on the removable-media guards and user confirmation)"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo
    echo "Dry-run: inputs valid, plan printed above. Nothing written."
    echo "Safety: internal Android/UFS/ABL/vbmeta/dtbo storage is never modified by this script."
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT")"

for tool in sgdisk mkfs.vfat; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

# --- Build image -------------------------------------------------------------
echo
echo "Building image file: $OUTPUT ($SIZE_MIB MiB)"
# Create a sparse image file.
truncate -s "${SIZE_MIB}M" "$OUTPUT" || die "failed to allocate image file"

# Partition layout (microSD-only):
#   1. EFI/boot partition (vfat) - kernel, DTB, boot config
#   2. rootfs partition (ext4) - minimal root filesystem
echo "Partitioning image (GPT)..."
if ! sgdisk -Z "$OUTPUT" >/dev/null 2>&1; then die "sgdisk -Z failed"; fi
if ! sgdisk -n 1:1M:+256M -t 1:ef00 -c 1:"G2-BOOT" "$OUTPUT" >/dev/null 2>&1; then die "sgdisk boot partition failed"; fi
if ! sgdisk -n 2:0:0 -t 2:8300 -c 2:"G2-ROOTFS" "$OUTPUT" >/dev/null 2>&1; then die "sgdisk rootfs partition failed"; fi

LOOP=""
CLEANUP() {
    [ -n "$LOOP" ] && $SUDO losetup -d "$LOOP" 2>/dev/null || true
}
trap CLEANUP EXIT

echo "Attaching loop device (image file only, never a block device)..."
LOOP="$($SUDO losetup --show --find --partscan "$OUTPUT")" || die "losetup failed for image file"
[ -b "${LOOP}p1" ] || die "loop partition 1 not available"
[ -b "${LOOP}p2" ] || die "loop partition 2 not available"

echo "Formatting boot partition (vfat)..."
$SUDO mkfs.vfat -n G2BOOT "${LOOP}p1" >/dev/null || die "mkfs.vfat boot failed"

echo "Formatting rootfs partition (ext4)..."
$SUDO mkfs.ext4 -q -L G2ROOT "${LOOP}p2" || die "mkfs.ext4 rootfs failed"

BOOTMNT="$ROOT/build/mnt-boot"
ROOTMNT="$ROOT/build/mnt-root"
mkdir -p "$BOOTMNT" "$ROOTMNT"

echo "Staging boot partition..."
$SUDO mount "${LOOP}p1" "$BOOTMNT" || die "mount boot failed"
$SUDO mkdir -p "$BOOTMNT/boot" "$BOOTMNT/extlinux"
$SUDO cp "$KERNEL" "$BOOTMNT/boot/Image" || die "copy kernel failed"
$SUDO cp "$DTB" "$BOOTMNT/boot/" || die "copy dtb failed"
$SUDO cp "$BOOTCONFIG" "$BOOTMNT/extlinux/extlinux.conf" || die "copy bootconfig failed"
sync
$SUDO umount "$BOOTMNT" || die "umount boot failed"

echo "Staging rootfs partition..."
$SUDO mount "${LOOP}p2" "$ROOTMNT" || die "mount rootfs failed"
if [ -d "$ROOTFS" ]; then
    $SUDO cp -a "$ROOTFS"/. "$ROOTMNT"/ || die "copy rootfs dir failed"
else
    $SUDO tar -x -C "$ROOTMNT" -f "$ROOTFS" || die "extract rootfs tarball failed"
fi
sync
$SUDO umount "$ROOTMNT" || die "umount rootfs failed"

$SUDO losetup -d "$LOOP"
LOOP=""
trap - EXIT

echo
echo "Image prepared: $OUTPUT"
echo "  kernel      : boot/Image"
echo "  dtb         : boot/$(basename "$DTB")"
echo "  bootconfig  : extlinux/extlinux.conf"
echo "  rootfs      : partition 2"
echo
echo "Safety summary:"
echo "  - Internal Android/UFS/ABL/vbmeta/dtbo/GPT storage: NOT modified."
echo "  - This image is microSD-only. Removing the microSD preserves stock Android."
echo "  - Flashing/verification on physical G2 hardware is a separate step that"
echo "    must never target internal storage."
