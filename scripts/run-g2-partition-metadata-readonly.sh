#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-partition-metadata-${STAMP}.txt"
REMOTE_OUT="/sdcard/g2-partition-metadata-${STAMP}.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB='ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb'
if ! eval "$ADB devices" | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2_partition_metadata_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
sec(){ echo; echo "===== $1 ====="; }
sec "IDENTITY"
getprop ro.product.model; getprop ro.product.device; getprop ro.boot.slot_suffix; getprop ro.boot.boot_devices; getprop ro.boot.bootdevice
sec "BLOCK SYSFS METADATA"
for b in sda sdb sdc sdd sde sdf mmcblk1; do
  [ -e "/sys/class/block/$b" ] || continue
  echo "--- $b ---"
  for f in dev size start alignment alignment_offset logical_block_size physical_block_size ro removable range stat; do
    [ -f "/sys/class/block/$b/$f" ] && { echo -n "$f: "; cat "/sys/class/block/$b/$f" 2>/dev/null; }
  done
  echo -n "device: "; readlink -f "/sys/class/block/$b/device" 2>/dev/null || true
  echo -n "driver: "; readlink -f "/sys/class/block/$b/device/driver" 2>/dev/null || true
done
sec "PARTITION SYSFS METADATA"
for b in sda sdb sdc sdd sde sdf mmcblk1; do
  [ -e "/sys/class/block/$b" ] || continue
  echo "--- $b children ---"
  for p in /sys/class/block/${b}p* /sys/class/block/${b}[0-9]*; do
    [ -e "$p" ] || continue
    n="$(basename "$p")"
    echo "[$n]"
    for f in partition start size dev alignment alignment_offset ro; do
      [ -f "$p/$f" ] && { echo -n "$f: "; cat "$p/$f" 2>/dev/null; }
    done
    echo -n "uevent:\n"; cat "$p/uevent" 2>/dev/null || true
  done
done
sec "BY-NAME RESOLUTION"
for p in xbl_a xbl_b xbl_config_a xbl_config_b abl_a abl_b uefi_a uefi_b uefisecapp_a uefisecapp_b boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b recovery_a recovery_b super userdata misc persist modem_a modem_b; do
  t="$(readlink -f "/dev/block/by-name/$p" 2>/dev/null || true)"
  [ -n "$t" ] || continue
  b="$(basename "$t")"
  echo "$p -> $t"
  for f in partition start size dev ro alignment alignment_offset; do
    [ -f "/sys/class/block/$b/$f" ] && { echo -n "  $f: "; cat "/sys/class/block/$b/$f" 2>/dev/null; }
  done
done
sec "PARTUUID / DISK LINKS"
for d in /dev/block/by-partuuid /dev/disk/by-partuuid /dev/block/by-name; do
  echo "--- $d ---"
  ls -la "$d" 2>&1 || true
done
sec "MICROSD"
ls -l /dev/block/mmcblk1 /dev/block/mmcblk1p1 2>&1 || true
readlink -f /sys/class/block/mmcblk1/device 2>&1 || true
readlink -f /sys/class/block/mmcblk1/device/driver 2>&1 || true
sec "SAFETY"
echo "READ-ONLY SYSFS PARTITION METADATA AUDIT ONLY"
echo "No raw block reads, dd, flash, erase, format, repartition, mount, slot change, or AVB change were performed."
EOF
printf '===== push script =====\n'
eval "$ADB push "$TMP" /data/local/tmp/g2-partition-metadata-readonly.sh" || exit 1
printf '===== run on G2 =====\n'
eval "$ADB shell sh /data/local/tmp/g2-partition-metadata-readonly.sh "$REMOTE_OUT"" || exit 1
printf '===== pull result =====\n'
mkdir -p dumps/g2
eval "$ADB pull "$REMOTE_OUT" "$OUT"" || exit 1
printf '===== cleanup =====\n'
eval "$ADB shell rm -f /data/local/tmp/g2-partition-metadata-readonly.sh "$REMOTE_OUT"" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-partition-metadata-readonly.sh
git commit -m "data: save G2 partition metadata audit" || exit 1
git push origin main || exit 1
printf '\nDONE: %s\n' "$OUT"
