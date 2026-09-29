#!/usr/bin/env bash
#
# Build a microSD image for the Retroid Pocket G2 in the ROCKNIX-ABL (qcom-abl)
# shape: the card that ROCKNIX-ABL, flashed to abl_b, boots from.
# See docs/g2-sd-boot-rocknix-abl-20260929.md.
#
# Same contract as pocknix/holodor build-sd-image.sh for BOOTLOADER=qcom-abl:
#
#   GPT p1  FAT32, GPT name "system", legacy_boot attribute, label POCKNIX
#             /KERNEL       Android boot image header v0: gzip(Image) + appended
#                           cliffs-g2.dtb, empty cpio (scripts/mkbootimg-g2.py -H 0)
#             /KERNEL.md5
#   GPT p2  ext4, GPT name + label POCKNIX_ROOT (empty: no rootfs yet)
#
# With no root filesystem, a successful boot ends on screen at
# "VFS: Unable to mount root fs" - that is the Tier 0 success signal.
#
# Writes a FILE only. Never touches a block device or the G2's internal storage.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO/.build}"
OUT="${OUT:-$WORK/g2-qcomabl-sd.img}"
IMG_MB="${IMG_MB:-192}"      # p1 FAT 128 MiB + p2 ext4 ~63 MiB
FAT_MB="${FAT_MB:-128}"

IMAGE="${IMAGE:-$WORK/linux712/arch/arm64/boot/Image}"
DTB="${DTB:-$WORK/linux712/arch/arm64/boot/dts/qcom/cliffs-g2.dtb}"
CMDLINE="${CMDLINE:-console=tty0 loglevel=8 ignore_loglevel}"

BOOT_PARTUUID="706f636b-6e69-7830-626f-6f7400000001"
ROOT_PARTUUID="706f636b-6e69-7830-726f-6f7400000002"

say(){ echo; echo "==> $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

for t in mkfs.vfat mkfs.ext4 sgdisk mcopy python3 md5sum; do
  command -v "$t" >/dev/null || die "missing tool: $t
       Debian/Ubuntu: apt-get install dosfstools e2fsprogs gdisk mtools python3"
done
[ -f "$IMAGE" ] || die "kernel Image not found: $IMAGE (set IMAGE=)"
[ -f "$DTB" ]   || die "device tree not found: $DTB (set DTB=)"
mkdir -p "$WORK"

say "packing /KERNEL (header v0, gzip(Image) + dtb)"
KERNEL="$WORK/KERNEL"
python3 "$REPO/scripts/mkbootimg-g2.py" --header-version 0 \
  --kernel "$IMAGE" --dtb "$DTB" --cmdline "$CMDLINE" -o "$KERNEL"
( cd "$WORK" && md5sum KERNEL > KERNEL.md5 )

say "partitioning ${IMG_MB} MiB image (qcom-abl contract)"
rm -f "$OUT"; truncate -s "${IMG_MB}M" "$OUT"
# 0700 = basic data (parted 'mkpart ... fat32'); attribute bit 2 = legacy_boot.
sgdisk --clear \
  --new=1:2048:+${FAT_MB}M --typecode=1:0700 --change-name=1:system --attributes=1:set:2 \
  --partition-guid=1:"$BOOT_PARTUUID" \
  --new=2:0:0 --typecode=2:8300 --change-name=2:POCKNIX_ROOT \
  --partition-guid=2:"$ROOT_PARTUUID" \
  "$OUT" >/dev/null

p_start(){ sgdisk -i "$1" "$OUT" | awk '/First sector/{print $3}'; }
p_end(){   sgdisk -i "$1" "$OUT" | awk '/Last sector/{print $3}'; }
S1=$(p_start 1); E1=$(p_end 1); S2=$(p_start 2); E2=$(p_end 2)

say "building FAT32 p1 (label POCKNIX)"
FS="$WORK/g2-qcomabl-p1.fat"; rm -f "$FS"
truncate -s $(( (E1 - S1 + 1) * 512 )) "$FS"
mkfs.vfat -F 32 -n POCKNIX "$FS" >/dev/null
mcopy -i "$FS" "$KERNEL"          ::/KERNEL
mcopy -i "$FS" "$WORK/KERNEL.md5" ::/KERNEL.md5
dd if="$FS" of="$OUT" bs=512 seek="$S1" conv=notrunc status=none; rm -f "$FS"

say "building ext4 p2 (POCKNIX_ROOT, empty)"
FS2="$WORK/g2-qcomabl-p2.ext4"; rm -f "$FS2"
truncate -s $(( (E2 - S2 + 1) * 512 )) "$FS2"
mkfs.ext4 -q -F -L POCKNIX_ROOT "$FS2"
dd if="$FS2" of="$OUT" bs=512 seek="$S2" conv=notrunc status=none; rm -f "$FS2"

say "verify"
sgdisk -p "$OUT" | sed -n '/Number/,$p'
sgdisk -i 1 "$OUT" | grep -E 'Partition GUID code|Attribute flags|Partition name'
mdir -i "$OUT@@$(( S1 * 512 ))" ::/ 2>/dev/null | grep -E 'KERNEL'

say "done"
echo "  image  : $OUT"
echo "  sha256 : $(sha256sum "$OUT" | cut -d' ' -f1)"
