#!/usr/bin/env bash
#
# Build the Path A "Stage 0" microSD image for the Retroid Pocket G2.
#
# Replicates the RP5's PRODUCTION arm-efi card contract from holodor/pocknix
# (scripts/build-sd-image.sh there), changing only what the 2026-09-15 Path A
# test did NOT try:
#
#   GPT p1  FAT32, GPT name "system", legacy_boot attribute, basic-data type
#           (NOT the ESP type GUID), label ROCKNIX, PARTUUID fixed
#             /EFI/BOOT/bootaa64.efi     GRUB arm64-efi (-p /boot/grub)
#             /boot/grub/grub.cfg        repo: boot/grub-stage0.cfg
#             /boot/grub/cliffs-g2.dtb   our board device tree
#             /KERNEL                    SM8635 arm64 Image
#   GPT p2  ext4, GPT name + label POCKNIX_ROOT, PARTUUID fixed (empty)
#
# Question it answers: does the G2's factory ABL chainload bootaa64.efi from a
# card in this shape? GRUB menu on screen = yes. See
# docs/g2-path-a-reverify-20260929.md and docs/g2-boot-test-20260929.md.
#
# Writes a FILE only. Never touches a block device or the G2's internal storage.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO/.build}"
OUT="${OUT:-$WORK/g2-stage0-sd.img}"
IMG_MB="${IMG_MB:-448}"      # p1 FAT 320 MiB + p2 ext4 ~127 MiB
FAT_MB="${FAT_MB:-320}"

KERNEL="${KERNEL:-$WORK/linux712/arch/arm64/boot/Image}"
DTB="${DTB:-$WORK/linux712/arch/arm64/boot/dts/qcom/cliffs-g2.dtb}"
CFG="${CFG:-$REPO/boot/grub-stage0.cfg}"

# Same fixed PARTUUIDs as holodor's config/pocknix.conf (SD_BOOT/SD_ROOT_PARTUUID).
BOOT_PARTUUID="706f636b-6e69-7830-626f-6f7400000001"
ROOT_PARTUUID="706f636b-6e69-7830-726f-6f7400000002"

# Pinned so the bootloader is reproducible (same pin as build-g2-tier0-sd-image.sh).
GRUB_DEB="${GRUB_DEB:-grub-efi-arm64-bin_2.12-5ubuntu11_arm64.deb}"
GRUB_URL="${GRUB_URL:-http://ports.ubuntu.com/ubuntu-ports/pool/main/g/grub2-unsigned/$GRUB_DEB}"
GRUB_SHA256="${GRUB_SHA256:-eb6ee2605529ac8f7a8efe62f42022bb9060058ebc277a6908670d17559d30b7}"
GRUB_MODULES="part_gpt fat ext2 search search_fs_file search_label search_fs_uuid
              configfile normal linux fdt echo test boot reboot halt sleep
              all_video efi_gop video video_fb gfxterm terminal font
              gzio loadenv minicmd ls cat help"

say(){ echo; echo "==> $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

for t in grub-mkimage mkfs.vfat mkfs.ext4 sgdisk mcopy mmd curl dpkg-deb; do
  command -v "$t" >/dev/null || die "missing tool: $t
       Debian/Ubuntu: apt-get install grub-common dosfstools e2fsprogs gdisk mtools curl dpkg"
done
[ -f "$KERNEL" ] || die "kernel Image not found: $KERNEL (set KERNEL=)"
[ -f "$DTB" ]    || die "device tree not found: $DTB (set DTB=)"
[ -f "$CFG" ]    || die "grub.cfg not found: $CFG"

mkdir -p "$WORK/grub"
if [ ! -d "$WORK/grub/root/usr/lib/grub/arm64-efi" ]; then
  say "fetching arm64 GRUB modules"
  curl -fsSL -o "$WORK/grub/$GRUB_DEB" "$GRUB_URL"
  echo "$GRUB_SHA256  $WORK/grub/$GRUB_DEB" | sha256sum -c - || die "checksum mismatch on $GRUB_DEB"
  ( cd "$WORK/grub" && dpkg-deb -x "$GRUB_DEB" root )
fi
MODDIR="$WORK/grub/root/usr/lib/grub/arm64-efi"

say "building bootaa64.efi"
# shellcheck disable=SC2086
grub-mkimage -d "$MODDIR" -O arm64-efi -p /boot/grub -o "$WORK/grub/bootaa64.efi" $GRUB_MODULES
file "$WORK/grub/bootaa64.efi" | grep -q "Aarch64" || die "grub-mkimage did not produce an AArch64 EFI app"

say "partitioning ${IMG_MB} MiB image (RP5 arm-efi contract)"
rm -f "$OUT"; truncate -s "${IMG_MB}M" "$OUT"
# 0700 = Microsoft basic data (what parted's 'mkpart ... fat32' gives holodor),
# attribute bit 2 = legacy BIOS bootable (parted's legacy_boot flag).
sgdisk --clear \
  --new=1:2048:+${FAT_MB}M --typecode=1:0700 --change-name=1:system --attributes=1:set:2 \
  --partition-guid=1:"$BOOT_PARTUUID" \
  --new=2:0:0 --typecode=2:8300 --change-name=2:POCKNIX_ROOT \
  --partition-guid=2:"$ROOT_PARTUUID" \
  "$OUT" >/dev/null

p_start(){ sgdisk -i "$1" "$OUT" | awk '/First sector/{print $3}'; }
p_end(){   sgdisk -i "$1" "$OUT" | awk '/Last sector/{print $3}'; }
S1=$(p_start 1); E1=$(p_end 1); S2=$(p_start 2); E2=$(p_end 2)

say "building FAT32 p1 (label ROCKNIX)"
FS="$WORK/g2-stage0-p1.fat"; rm -f "$FS"
truncate -s $(( (E1 - S1 + 1) * 512 )) "$FS"
mkfs.vfat -F 32 -n ROCKNIX "$FS" >/dev/null
mmd   -i "$FS" ::/EFI ::/EFI/BOOT ::/boot ::/boot/grub
mcopy -i "$FS" "$WORK/grub/bootaa64.efi" ::/EFI/BOOT/bootaa64.efi
mcopy -i "$FS" "$CFG"                    ::/boot/grub/grub.cfg
mcopy -i "$FS" "$DTB"                    ::/boot/grub/cliffs-g2.dtb
mcopy -i "$FS" "$KERNEL"                 ::/KERNEL
dd if="$FS" of="$OUT" bs=512 seek="$S1" conv=notrunc status=none; rm -f "$FS"

say "building ext4 p2 (POCKNIX_ROOT, empty)"
FS2="$WORK/g2-stage0-p2.ext4"; rm -f "$FS2"
truncate -s $(( (E2 - S2 + 1) * 512 )) "$FS2"
mkfs.ext4 -q -F -L POCKNIX_ROOT "$FS2"
dd if="$FS2" of="$OUT" bs=512 seek="$S2" conv=notrunc status=none; rm -f "$FS2"

say "verify"
sgdisk -p "$OUT" | sed -n '/Number/,$p'
sgdisk -i 1 "$OUT" | grep -E 'Partition GUID code|unique GUID|Attribute flags|Partition name'
mdir -i "$OUT@@$(( S1 * 512 ))" -/ ::/ 2>/dev/null | grep -vE '^\s*$' | head -20

say "done"
echo "  image  : $OUT"
echo "  sha256 : $(sha256sum "$OUT" | cut -d' ' -f1)"
