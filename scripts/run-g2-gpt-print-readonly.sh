#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-gpt-print-${STAMP}.txt"
REMOTE_OUT="/sdcard/g2-gpt-print-${STAMP}.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB='ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb'
if ! eval "$ADB devices" | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2_gpt_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
sec(){ echo; echo "===== $1 ====="; }
sec "IDENTITY"
getprop ro.product.model; getprop ro.product.device; getprop ro.boot.slot_suffix; getprop ro.boot.boot_devices; getprop ro.boot.bootdevice
sec "SGDISK VERSION"
sgdisk --version 2>&1 || true
sec "UFS GPT PRINT READONLY"
for d in /dev/block/sda /dev/block/sdb /dev/block/sdc /dev/block/sdd /dev/block/sde /dev/block/sdf; do
  echo "--- $d ---"
  sgdisk --print "$d" 2>&1 || true
done
sec "UFS GPT PARTITION INFO"
for p in xbl_a xbl_b abl_a abl_b uefi_a uefi_b uefisecapp_a uefisecapp_b boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b recovery_a recovery_b; do
  b="$(readlink -f "/dev/block/by-name/$p" 2>/dev/null || true)"
  [ -n "$b" ] || continue
  echo "--- $p -> $b ---"
  # --info only reads GPT metadata; it does not modify the disk.
  # Extract the partition number from the final block-device name.
  n="${b##*[!0-9]}"
  [ -n "$n" ] && sgdisk --info="$n" "${b%[0-9]*}" 2>&1 || true
done
sec "MICROSD GPT PRINT READONLY"
if [ -b /dev/block/mmcblk1 ]; then
  sgdisk --print /dev/block/mmcblk1 2>&1 || true
else
  echo "mmcblk1 not present"
fi
sec "MICROSD PARTITION INFO"
if [ -b /dev/block/mmcblk1 ]; then
  sgdisk --info=1 /dev/block/mmcblk1 2>&1 || true
fi
sec "BLKID"
blkid /dev/block/sda /dev/block/mmcblk1 /dev/block/mmcblk1p1 2>&1 || true
sec "SAFETY"
echo "READ-ONLY GPT AUDIT ONLY"
echo "No partition contents were read and no write/erase/format/repartition/slot/AVB operations were performed."
EOF
printf '===== push script =====\n'
eval "$ADB push "$TMP" /data/local/tmp/g2-gpt-print-readonly.sh" || exit 1
printf '===== run on G2 =====\n'
eval "$ADB shell sh /data/local/tmp/g2-gpt-print-readonly.sh "$REMOTE_OUT"" || exit 1
printf '===== pull result =====\n'
mkdir -p dumps/g2
eval "$ADB pull "$REMOTE_OUT" "$OUT"" || exit 1
printf '===== cleanup =====\n'
eval "$ADB shell rm -f /data/local/tmp/g2-gpt-print-readonly.sh "$REMOTE_OUT"" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-gpt-print-readonly.sh
git commit -m "data: save G2 GPT readonly print" || exit 1
git push origin main || exit 1
printf '\nDONE: %s\n' "$OUT"
