#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-gpt-boot-structure-${STAMP}.txt"
REMOTE_OUT="/sdcard/g2-gpt-boot-structure-${STAMP}.txt"

cd "$REPO" || exit 1
git pull --ff-only || exit 1

ADB='ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb'
if ! eval "$ADB devices" | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then
  echo 'ERROR: exactly one ADB device must be connected.'
  exit 1
fi

TMP="$REPO/.g2_boot_audit_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
sec(){ echo; echo "===== $1 ====="; }
sec "IDENTITY"
getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint; getprop ro.boot.slot_suffix; getprop ro.boot.boot_devices; getprop ro.boot.bootdevice
sec "BOOT PARTITION METADATA"
for p in xbl_a xbl_b abl_a abl_b uefi_a uefi_b uefisecapp_a uefisecapp_b boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b recovery_a recovery_b; do
  echo "--- $p ---"
  ls -l "/dev/block/by-name/$p" 2>&1 || true
  t="$(readlink -f "/dev/block/by-name/$p" 2>/dev/null || true)"
  [ -n "$t" ] || continue
  b="$(basename "$t")"
  for f in size ro alignment start dev; do
    [ -f "/sys/class/block/$b/$f" ] && { echo -n "$f: "; cat "/sys/class/block/$b/$f"; }
  done
done
sec "WHOLE BLOCK DEVICES"
for b in sda sdb sdc sdd sde sdf mmcblk1; do
  if [ -e "/sys/class/block/$b" ]; then
    echo "--- $b ---"
    for f in size ro removable dev; do [ -f "/sys/class/block/$b/$f" ] && { echo -n "$f: "; cat "/sys/class/block/$b/$f"; }; done
    readlink -f "/sys/class/block/$b/device" 2>&1 || true
  fi
done
sec "GPT/EFI USERSPACE AVAILABILITY"
command -v sgdisk 2>&1 || true
command -v gdisk 2>&1 || true
command -v blkid 2>&1 || true
command -v parted 2>&1 || true
command -v toybox 2>&1 || true
sec "GPT METADATA VIA SYSFS"
for b in sda sdb sdc sdd sde sdf; do
  echo "--- $b partitions ---"
  ls -l /sys/class/block/$b/*/partition 2>&1 || true
done
sec "UEFI/EFI NODES"
for p in /sys/firmware/efi /sys/firmware/devicetree/base/firmware /sys/firmware/devicetree/base/reserved-memory/uefi_log_region@81ce4000; do
  echo "--- $p ---"; ls -la "$p" 2>&1 || true
done
sec "DEVICE TREE FIRMWARE / BOOT NODES"
find /sys/firmware/devicetree/base/firmware /sys/firmware/devicetree/base/reserved-memory -maxdepth 2 -print 2>/dev/null | sort
sec "SD BOOT-RELEVANT DT NODES"
for d in /sys/firmware/devicetree/base/soc/sdhci@8804000 /sys/firmware/devicetree/base/soc/pinctrl@f000000; do
  echo "--- $d ---"; find "$d" -maxdepth 2 -type f -print 2>/dev/null | sort
done
sec "KERNEL BOOT LOGS"
dmesg 2>&1 | grep -Ei 'uefi|efi|abl|xbl|boot|sdhci|mmc|mmcblk1' | tail -n 800 || true
sec "SAFETY"
echo "READ-ONLY AUDIT ONLY"
echo "No dd, flash, erase, format, repartition, slot change, AVB change, or mount-readwrite operations were performed by this script."
EOF

printf '===== push script =====\n'
eval "$ADB push "$TMP" /data/local/tmp/g2-gpt-boot-structure.sh" || exit 1
printf '===== run on G2 =====\n'
eval "$ADB shell sh /data/local/tmp/g2-gpt-boot-structure.sh "$REMOTE_OUT"" || exit 1
printf '===== pull result =====\n'
mkdir -p dumps/g2
eval "$ADB pull "$REMOTE_OUT" "$OUT"" || exit 1
printf '===== remove temporary files =====\n'
eval "$ADB shell rm -f /data/local/tmp/g2-gpt-boot-structure.sh "$REMOTE_OUT"" || true
rm -f "$TMP"

git add "$OUT" scripts/run-g2-gpt-boot-structure-readonly.sh
git commit -m "data: save G2 GPT boot structure audit" || exit 1
git push origin main || exit 1
printf '\nDONE: %s\n' "$OUT"
