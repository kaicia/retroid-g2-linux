#!/usr/bin/env bash
#
# Build the Tier 0 microSD boot image for the Retroid Pocket G2.
#
# Produces a GPT disk image with one FAT32 EFI system partition laid out as:
#
#   /EFI/BOOT/BOOTAA64.EFI    GRUB, built here for arm64-efi
#   /boot/grub/grub.cfg       boot menu (repo: boot/grub.cfg)
#   /cliffs-g2.dtb            Tier 0 device tree (repo: dts/)
#   /KERNEL                   arm64 kernel Image
#
# This is Path A from docs/g2-decisions-20260914.md: the firmware runs the
# removable-media fallback \EFI\BOOT\BOOTAA64.EFI off the card, GRUB supplies
# the kernel and the DTB. NOTHING is written to the device's internal storage,
# and no bootloader is flashed.
#
# The image is written to a FILE. Putting it on a card is a separate, manual
# step -- this script never touches a block device.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO/.build}"
OUT="${OUT:-$WORK/g2-tier0-sd.img}"
IMG_MB="${IMG_MB:-256}"

KERNEL="${KERNEL:-$WORK/linux/arch/arm64/boot/Image}"
DTB="${DTB:-$WORK/linux/arch/arm64/boot/dts/qcom/cliffs-g2.dtb}"

# Pinned so the bootloader is reproducible.
GRUB_DEB="${GRUB_DEB:-grub-efi-arm64-bin_2.12-5ubuntu11_arm64.deb}"
GRUB_URL="${GRUB_URL:-http://ports.ubuntu.com/ubuntu-ports/pool/main/g/grub2-unsigned/$GRUB_DEB}"
GRUB_SHA256="${GRUB_SHA256:-eb6ee2605529ac8f7a8efe62f42022bb9060058ebc277a6908670d17559d30b7}"

GRUB_MODULES="part_gpt fat search search_fs_file search_label search_fs_uuid
              configfile normal linux fdt echo test boot reboot halt sleep
              all_video efi_gop video video_fb gfxterm terminal font
              gzio loadenv minicmd ls cat help"

say(){ echo; echo "==> $*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }

for t in grub-mkimage mkfs.vfat sgdisk mcopy mmd curl; do
  command -v "$t" >/dev/null || die "missing tool: $t
       Debian/Ubuntu: apt-get install grub-common dosfstools gdisk mtools curl"
done

[ -f "$DTB" ] || die "device tree not found: $DTB
       Build it first: scripts/build-g2-dtb-compile-candidate.sh cliffs-g2"
[ -f "$KERNEL" ] || die "kernel Image not found: $KERNEL
       Build one with:  make -C \$WORK/linux ARCH=arm64 LLVM=1 -j\$(nproc) Image
       or point KERNEL= at an existing arm64 Image."

mkdir -p "$WORK/grub"

# ---------------------------------------------------------------- bootloader
if [ ! -d "$WORK/grub/root/usr/lib/grub/arm64-efi" ]; then
  say "fetching arm64 GRUB modules"
  curl -fsSL -o "$WORK/grub/$GRUB_DEB" "$GRUB_URL"
  echo "$GRUB_SHA256  $WORK/grub/$GRUB_DEB" | sha256sum -c - \
    || die "checksum mismatch on $GRUB_DEB"
  ( cd "$WORK/grub" && dpkg-deb -x "$GRUB_DEB" root )
fi
MODDIR="$WORK/grub/root/usr/lib/grub/arm64-efi"
[ -d "$MODDIR" ] || die "arm64-efi modules missing at $MODDIR"

say "building bootaa64.efi"
# -p must match where grub.cfg lands on the ESP.
# shellcheck disable=SC2086
grub-mkimage -d "$MODDIR" -O arm64-efi -p /boot/grub \
             -o "$WORK/grub/bootaa64.efi" $GRUB_MODULES
file "$WORK/grub/bootaa64.efi" | grep -q "Aarch64" \
  || die "grub-mkimage did not produce an AArch64 EFI application"

# --------------------------------------------------------------------- image
say "creating ${IMG_MB}MiB image with one FAT32 ESP"
rm -f "$OUT"
truncate -s "${IMG_MB}M" "$OUT"
sgdisk --clear \
       --new=1:2048:0 --typecode=1:ef00 --change-name=1:G2BOOT \
       "$OUT" >/dev/null

# Build the filesystem separately, then splice it in: mkfs.vfat on an offset
# inside a file needs a loop device, and this script deliberately avoids those.
PART_OFFSET=$((2048 * 512))
PART_BYTES=$(( IMG_MB * 1024 * 1024 - PART_OFFSET - 34 * 512 ))
FS="$WORK/g2-esp.fat"
rm -f "$FS"
truncate -s "$PART_BYTES" "$FS"
mkfs.vfat -F 32 -n G2BOOT "$FS" >/dev/null

say "populating the ESP"
mmd   -i "$FS" ::/EFI ::/EFI/BOOT ::/boot ::/boot/grub
mcopy -i "$FS" "$WORK/grub/bootaa64.efi" ::/EFI/BOOT/BOOTAA64.EFI
mcopy -i "$FS" "$REPO/boot/grub.cfg"     ::/boot/grub/grub.cfg
mcopy -i "$FS" "$DTB"                    ::/cliffs-g2.dtb
mcopy -i "$FS" "$KERNEL"                 ::/KERNEL

dd if="$FS" of="$OUT" bs=512 seek=2048 conv=notrunc status=none
rm -f "$FS"

say "contents"
mdir -i "$OUT@@$PART_OFFSET" -/ ::/ 2>/dev/null || true

say "done"
echo "  image  : $OUT"
echo "  size   : $(du -h "$OUT" | cut -f1)"
echo "  sha256 : $(sha256sum "$OUT" | cut -d' ' -f1)"
echo
echo "To use it, write the image to a microSD card from a PC, e.g."
echo "  sudo dd if=$OUT of=/dev/sdX bs=4M conv=fsync status=progress"
echo "Check /dev/sdX carefully -- that command overwrites whatever it names."
echo
echo "Then insert the card and power the G2 on. Expected result is a kernel"
echo "panic about a missing root filesystem: see docs/g2-tier0-boot-plan-20260915.md."
