#!/data/data/com.termux/files/usr/bin/bash
set -u

REPO="$HOME/retroid-g2-linux"
ADB_PREFIX=(env ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb)
STAMP="$(date +%Y%m%d-%H%M%S)"
REMOTE_SCRIPT="/data/local/tmp/g2-boot-readonly-${STAMP}.sh"
REMOTE_RESULT="/sdcard/g2-boot-readonly-${STAMP}.txt"
LOCAL_RESULT="$REPO/dumps/g2/g2-boot-readonly-${STAMP}.txt"

fail() { echo "ERROR: $*" >&2; exit 1; }

cd "$REPO" || fail "Repository not found: $REPO"
git pull --ff-only || fail "git pull failed"
command -v git >/dev/null || fail "git is not installed"
command -v fakeroot >/dev/null || fail "fakeroot is not installed"
command -v termux-adb >/dev/null || fail "termux-adb is not installed"

mkdir -p "$REPO/dumps/g2"

echo "===== ADB DEVICE CHECK ====="
"${ADB_PREFIX[@]}" devices || fail "ADB command failed"
DEVICE_COUNT=$("${ADB_PREFIX[@]}" devices | awk '$2=="device" {n++} END{print n+0}')
[ "$DEVICE_COUNT" = "1" ] || fail "Expected exactly one authorized G2 ADB device; found $DEVICE_COUNT"

TMP_SCRIPT="$REPO/.g2-boot-readonly-${STAMP}.sh"
trap 'rm -f "$TMP_SCRIPT"' EXIT

cat > "$TMP_SCRIPT" <<'DEVICE_SCRIPT'
#!/system/bin/sh
# READ-ONLY G2 boot/UEFI investigation.
# No partition contents are read. No UFS/bootloader/AVB/slot writes are performed.
OUT="$1"
exec >"$OUT" 2>&1
section(){ echo; echo "===== $1 ====="; }

section "IDENTITY"
getprop ro.product.model
getprop ro.product.device
getprop ro.build.fingerprint
getprop ro.build.id
getprop ro.build.version.release
uname -a

section "BOOT PROPERTIES"
getprop | grep -E '^\[ro.boot\.' || true

echo
section "BOOT DEVICE / SLOT / SECURITY"
for p in ro.boot.boot_devices ro.boot.bootdevice ro.boot.slot_suffix ro.boot.slot ro.boot.vbmeta.device_state ro.boot.verifiedbootstate ro.boot.veritymode ro.boot.flash.locked ro.boot.dynamic_partitions; do
  echo -n "$p="; getprop "$p"
done

section "CMDLINE AND BOOTCONFIG"
echo "--- /proc/cmdline ---"
cat /proc/cmdline 2>&1 || true
echo "--- /proc/bootconfig ---"
cat /proc/bootconfig 2>&1 || true

section "BOOT PARTITION NODE PRESENCE"
for p in xbl_a xbl_b abl_a abl_b uefi_a uefi_b uefisecapp_a uefisecapp_b boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b recovery_a recovery_b; do
  printf '%-20s ' "$p"
  ls -l "/dev/block/by-name/$p" 2>&1 || true
done

section "BOOT DEVICE SYSFS"
for d in /sys/class/block/sda /sys/class/block/sde /sys/class/block/mmcblk1; do
  [ -e "$d" ] || continue
  echo "--- $d ---"
  readlink -f "$d/device" 2>&1 || true
  readlink -f "$d/device/driver" 2>&1 || true
  for p in size removable dev; do [ -f "$d/$p" ] && { echo -n "$p="; cat "$d/$p"; }; done
done

section "UEFI / EFI / FIRMWARE NODES"
for d in /sys/firmware/efi /sys/firmware/devicetree/base/firmware /proc/device-tree/firmware /sys/firmware; do
  echo "--- $d ---"
  if [ -e "$d" ]; then
    ls -la "$d" 2>&1 | head -n 200
    find "$d" -maxdepth 3 -type f -print 2>/dev/null | head -n 300
  else
    echo "NOT PRESENT"
  fi
done

section "EFI VARIABLE ACCESS"
if [ -d /sys/firmware/efi/efivars ]; then
  ls -la /sys/firmware/efi/efivars 2>&1 | head -n 300
else
  echo "EFI efivars directory not present"
fi

section "DEVICE TREE BOOT / FIRMWARE NODES"
for base in /sys/firmware/devicetree/base /proc/device-tree; do
  echo "--- $base ---"
  if [ -d "$base" ]; then
    find "$base" -maxdepth 3 -type d \( -iname '*uefi*' -o -iname '*efi*' -o -iname '*boot*' -o -iname '*firmware*' -o -iname '*chosen*' \) -print 2>/dev/null | sort
  fi
done

section "SDHCI / MMC BOOT-RELEVANT SYSFS"
for d in /sys/devices/platform/soc/8804000.sdhci /sys/devices/platform/soc/8804000.sdhci/mmc_host/mmc1 /sys/class/mmc_host/mmc1; do
  echo "--- $d ---"
  if [ -e "$d" ]; then
    find "$d" -maxdepth 4 -type f -print 2>/dev/null | sort | head -n 500
    readlink -f "$d/device/driver" 2>/dev/null || true
  else
    echo "NOT PRESENT"
  fi
done

section "KERNEL BOOT / UEFI / MMC LOGS"
dmesg 2>&1 | grep -Ei 'uefi|efi|abl|xbl|boot|mmc|sdhci|mmcblk1|sd card' | tail -n 1000 || true

section "MOUNT AND STORAGE SUMMARY"
mount 2>&1 | grep -E 'mmcblk1|media_rw|storage|data' || true
df -h 2>&1 || true

echo
echo "===== END READ-ONLY G2 BOOT INVESTIGATION ====="
DEVICE_SCRIPT

chmod 700 "$TMP_SCRIPT"

echo "===== PUSH READ-ONLY COLLECTOR ====="
"${ADB_PREFIX[@]}" push "$TMP_SCRIPT" "$REMOTE_SCRIPT" || fail "ADB push failed"

echo "===== RUN ON G2 ====="
"${ADB_PREFIX[@]}" shell "sh '$REMOTE_SCRIPT' '$REMOTE_RESULT'" || fail "Remote collector failed"

echo "===== PULL RESULT ====="
"${ADB_PREFIX[@]}" pull "$REMOTE_RESULT" "$LOCAL_RESULT" || fail "ADB pull failed"

# Remove only the temporary investigation files from the G2 userspace.
"${ADB_PREFIX[@]}" shell "rm -f '$REMOTE_SCRIPT' '$REMOTE_RESULT'" >/dev/null 2>&1 || true

echo "===== GIT SAVE ====="
git add "$LOCAL_RESULT"
git commit -m "data: save G2 boot read-only investigation $STAMP" || fail "git commit failed"
git push origin main || fail "git push failed"

echo
echo "===== COMPLETE ====="
echo "Result saved to: $LOCAL_RESULT"
git log -1 --oneline
git status --short
