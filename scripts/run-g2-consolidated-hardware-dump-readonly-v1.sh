#!/data/data/com.termux/files/usr/bin/bash
#
# Consolidated read-only G2 hardware dump.
#
# Collects, in one pass, every outstanding hardware fact the Linux port needs:
#   A  SoC identity            -- settles Cliffs <-> upstream milos equivalence
#   B  SDCC2 remaining gaps    -- pinctrl/regulator/debounce/live SMMU + clocks
#   C  Boot chain / SD boot    -- can the stock bootloader reach removable media
#   D  Subsystem inventory     -- display, GPU, input, USB, audio, wifi/bt, power
#
# STRICTLY READ-ONLY. No flash, erase, format, repartition, slot switch, AVB or
# firmware operation. No block-device content is read. Nothing is written to the
# device outside /data/local/tmp, and that file is removed at the end.
#
# On success the dump is committed and pushed to the branch that is currently
# checked out in $REPO. It never switches branches and never force-pushes.
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-consolidated-hardware-${STAMP}.txt"
REMOTE_SCRIPT="/data/local/tmp/g2-consolidated-${STAMP}.sh"
REMOTE_OUT="/data/local/tmp/g2-consolidated-${STAMP}.txt"

cd "$REPO" || { echo "ERROR: $REPO not found"; exit 1; }
run_adb(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb "$@"; }

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  echo "ERROR: no branch checked out in $REPO (detached HEAD?)."
  exit 1
fi
echo "==> repo branch: $BRANCH"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes. Commit or stash them first,"
  echo "       so the dump lands as its own commit."
  git status --short
  exit 1
fi

echo "==> syncing branch"
git pull --ff-only origin "$BRANCH" || {
  echo "ERROR: git pull --ff-only failed. Resolve it before collecting a dump."
  exit 1
}

if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then
  echo 'ERROR: exactly one ADB device must be connected and authorized.'
  run_adb devices
  exit 1
fi

TMP="$REPO/.g2-consolidated-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base

hex(){ [ -f "$1" ] && od -An -tx1 "$1" 2>/dev/null | tr -d ' \n'; }
txt(){ [ -f "$1" ] && tr '\000' ' ' < "$1" 2>/dev/null; }
sec(){ echo; echo "############ $* ############"; }
sub(){ echo; echo "===== $* ====="; }
cat_if(){ if [ -r "$1" ]; then echo "--- $1 ---"; cat "$1" 2>/dev/null; else echo "--- $1 --- UNREADABLE"; fi; }
ls_if(){ if [ -e "$1" ]; then echo "--- ls $1 ---"; ls -l "$1" 2>/dev/null; else echo "--- ls $1 --- MISSING"; fi; }
# dump every property file of a DT node, as name=hex (compatible/name as text)
node(){
  d="$1"; sub "NODE $d"
  [ -d "$d" ] || { echo MISSING; return; }
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    case "$b" in
      compatible|name|label|status|*-names|qcom,*-name) echo "$b= $(txt "$f")" ;;
      *) echo "$b= $(hex "$f")" ;;
    esac
  done
}
# find the DT node owning a given phandle (hex, 8 digits)
resolve(){
  v="$1"
  find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do
    [ "$(hex "$p")" = "$v" ] && { dirname "$p"; break; }
  done
}

echo "G2 CONSOLIDATED READ-ONLY HARDWARE DUMP"
echo "date=$(date)"
echo "schema=1"

############################################################
sec "A. SOC IDENTITY"

sub "A1 getprop identity"
for p in ro.product.model ro.product.device ro.product.name ro.product.board \
         ro.board.platform ro.soc.model ro.soc.manufacturer \
         ro.boot.hardware ro.boot.hardware.revision ro.boot.product.vendor.sku \
         ro.boot.product.hardware.sku ro.boot.dtb_idx ro.boot.dtbo_idx \
         ro.build.fingerprint ro.vendor.build.fingerprint \
         ro.boot.bootloader ro.bootloader ro.revision ro.hardware.chipname; do
  echo "$p = $(getprop $p)"
done

sub "A2 /sys/devices/soc0 (SoC ID -- the decisive identity evidence)"
if [ -d /sys/devices/soc0 ]; then
  for f in /sys/devices/soc0/*; do
    [ -f "$f" ] && echo "$(basename $f) = $(cat $f 2>/dev/null)"
  done
else
  echo "/sys/devices/soc0 MISSING"
fi
ls_if /sys/bus/soc/devices

sub "A3 device tree root"
echo "model      = $(txt $BASE/model)"
echo "compatible = $(txt $BASE/compatible)"
echo "qcom,msm-id   = $(hex $BASE/qcom,msm-id)"
echo "qcom,board-id = $(hex $BASE/qcom,board-id)"
echo "qcom,pmic-id  = $(hex $BASE/qcom,pmic-id)"

sub "A4 kernel / cpu"
uname -a
cat_if /proc/version
cat_if /proc/cmdline
echo "--- cpuinfo (implementer/part/revision only) ---"
grep -iE "implementer|architecture|variant|part|revision|processor" /proc/cpuinfo 2>/dev/null
echo "--- CPU topology ---"
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  [ -d "$c" ] || continue
  echo "$(basename $c): max=$(cat $c/cpufreq/cpuinfo_max_freq 2>/dev/null) min=$(cat $c/cpufreq/cpuinfo_min_freq 2>/dev/null)"
done
echo "--- /proc/config.gz present? ---"
ls -l /proc/config.gz 2>/dev/null || echo "no /proc/config.gz"

############################################################
sec "B. SDCC2 REMAINING GAPS"
SD=$BASE/soc/sdhci@8804000

sub "B1 full SDHCI node (every property)"
node "$SD"

sub "B2 pinctrl states"
echo "pinctrl-0 phandle = $(hex $SD/pinctrl-0)"
echo "pinctrl-1 phandle = $(hex $SD/pinctrl-1)"
for ph in $(hex $SD/pinctrl-0) $(hex $SD/pinctrl-1); do
  [ -n "$ph" ] || continue
  D=$(resolve "$ph")
  echo ">>> phandle $ph -> $D"
  [ -n "$D" ] && { node "$D"; for c in "$D"/*; do [ -d "$c" ] && node "$c"; done; }
done

sub "B3 card-detect gpio + debounce"
echo "cd-gpios              = $(hex $SD/cd-gpios)"
echo "cd-debounce-delay-ms  = $(hex $SD/cd-debounce-delay-ms)"

sub "B4 regulator nodes (PMXR2230 L13 / L23)"
for ph in $(hex $SD/vdd-supply) $(hex $SD/vdd-io-supply); do
  [ -n "$ph" ] || continue
  D=$(resolve "$ph")
  echo ">>> phandle $ph -> $D"
  [ -n "$D" ] && node "$D"
done
echo "--- live regulator summary (SD rails) ---"
if [ -r /sys/kernel/debug/regulator/regulator_summary ]; then
  grep -iE "l13|l23|pmxr2230|regulator" /sys/kernel/debug/regulator/regulator_summary 2>/dev/null | head -60
else
  echo "regulator_summary unreadable (needs root)"
fi

sub "B5 live SMMU stream id (cross-check DT 0x140 vs upstream 0x540)"
ls_if /sys/class/iommu
for d in /sys/class/iommu/*; do
  [ -e "$d" ] || continue
  echo "--- $d ---"; ls -l "$d/devices" 2>/dev/null
done
echo "--- sdhci device iommu group ---"
ls_if /sys/devices/platform/soc/8804000.sdhci/iommu
ls_if /sys/devices/platform/soc/8804000.sdhci/iommu_group
echo "--- arm-smmu masters (if exposed) ---"
ls_if /sys/kernel/debug/iommu

sub "B6 live mmc host state"
ls_if /sys/class/mmc_host
for h in /sys/class/mmc_host/mmc*; do
  [ -e "$h" ] || continue
  echo "--- $h ---"
  for f in "$h"/*; do [ -f "$f" ] && echo "$(basename $f) = $(cat $f 2>/dev/null)"; done
done
cat_if /sys/kernel/debug/mmc1/ios

sub "B7 live SDCC2 clock rates"
if [ -r /sys/kernel/debug/clk/clk_summary ]; then
  grep -iE "sdcc2|gcc_sdcc" /sys/kernel/debug/clk/clk_summary 2>/dev/null
else
  echo "clk_summary unreadable (needs root)"
fi

sub "B8 driver binding evidence"
ls_if /sys/bus/platform/drivers/sdhci_msm
ls_if /sys/devices/platform/soc/8804000.sdhci
cat_if /sys/devices/platform/soc/8804000.sdhci/uevent

############################################################
sec "C. BOOT CHAIN / SD BOOT FEASIBILITY"

sub "C1 boot properties"
getprop | grep -iE "ro\.boot\.|bootloader|verifiedboot|slot|avb|secure" 2>/dev/null

sub "C2 partition names (names only -- no content is read)"
ls_if /dev/block/by-name
ls_if /dev/block/bootdevice/by-name

sub "C3 EFI system partition / removable-media evidence"
for n in efi esp EFI uefi boot_a boot_b; do
  [ -e "/dev/block/by-name/$n" ] && echo "present: /dev/block/by-name/$n"
done
echo "--- mounts ---"
cat_if /proc/mounts
echo "--- vfat/efi filesystems known to the kernel ---"
grep -iE "vfat|msdos|exfat|efi" /proc/filesystems 2>/dev/null

sub "C4 external SD state"
ls_if /sys/block
echo "--- mmcblk1 (external SD) attributes ---"
for f in /sys/block/mmcblk1/size /sys/block/mmcblk1/ro /sys/block/mmcblk1/removable; do
  [ -r "$f" ] && echo "$f = $(cat $f 2>/dev/null)"
done
ls_if /sys/block/mmcblk1

sub "C5 dtbo / dt index"
echo "dtbo_idx = $(getprop ro.boot.dtbo_idx)"
echo "dtb_idx  = $(getprop ro.boot.dtb_idx)"

############################################################
sec "D. SUBSYSTEM INVENTORY (for later bring-up phases)"

sub "D1 display"
ls_if /sys/class/drm
for d in /sys/class/drm/*/status; do [ -r "$d" ] && echo "$d = $(cat $d 2>/dev/null)"; done
echo "--- DSI panel nodes in DT ---"
find $BASE -maxdepth 4 -type d -name "*panel*" 2>/dev/null | head -20
for p in $(find $BASE -maxdepth 4 -type d -name "*panel*" 2>/dev/null | head -5); do
  echo "$p compatible = $(txt $p/compatible)"
done

sub "D2 GPU"
ls_if /sys/class/kgsl/kgsl-3d0
for f in gpu_model gpumodel gpu_clock max_gpuclk devfreq/cur_freq; do
  [ -r "/sys/class/kgsl/kgsl-3d0/$f" ] && echo "$f = $(cat /sys/class/kgsl/kgsl-3d0/$f 2>/dev/null)"
done
echo "--- DT gpu node ---"
for p in $(find $BASE -maxdepth 3 -type d -name "gpu*" 2>/dev/null | head -5); do
  echo "$p compatible = $(txt $p/compatible)"
done

sub "D3 input (buttons, sticks, touch)"
cat_if /proc/bus/input/devices

sub "D4 usb"
ls_if /sys/class/udc
cat_if /sys/kernel/debug/usb/devices
for p in $(find $BASE/soc -maxdepth 1 -type d -name "usb*" 2>/dev/null | head -5); do
  echo "$p compatible = $(txt $p/compatible)"
done

sub "D5 audio"
ls_if /proc/asound
cat_if /proc/asound/cards
for p in $(find $BASE -maxdepth 3 -type d -name "*codec*" -o -maxdepth 3 -type d -name "*audio*" 2>/dev/null | head -8); do
  echo "$p compatible = $(txt $p/compatible)"
done

sub "D6 wifi / bluetooth"
getprop | grep -iE "wifi|wlan|bluetooth|bt\." 2>/dev/null | head -30
ls_if /sys/class/net
for p in $(find $BASE -maxdepth 3 -type d \( -name "wifi*" -o -name "wlan*" -o -name "bluetooth*" -o -name "*qca*" \) 2>/dev/null | head -8); do
  echo "$p compatible = $(txt $p/compatible)"
done

sub "D7 power / battery / thermal"
ls_if /sys/class/power_supply
for s in /sys/class/power_supply/*; do
  [ -d "$s" ] || continue
  echo "--- $s ---"
  for f in type status present technology voltage_now current_now capacity charge_full_design; do
    [ -r "$s/$f" ] && echo "$f = $(cat $s/$f 2>/dev/null)"
  done
done
echo "--- thermal zone types ---"
for z in /sys/class/thermal/thermal_zone*/type; do [ -r "$z" ] && echo "$z = $(cat $z 2>/dev/null)"; done

sub "D8 loaded vendor modules (platform driver inventory)"
cat_if /proc/modules

############################################################
sec "SAFETY"
echo "READ-ONLY audit only."
echo "No block-device content was read; no flash, erase, format, repartition,"
echo "slot, AVB or firmware operation was performed."
echo "END schema=1"
EOF

echo "==> pushing collector to device"
run_adb push "$TMP" "$REMOTE_SCRIPT" >/dev/null || { echo 'ERROR: adb push failed'; rm -f "$TMP"; exit 1; }
run_adb shell "chmod 755 $REMOTE_SCRIPT" >/dev/null

echo "==> running collector on device (read-only)"
run_adb shell "sh $REMOTE_SCRIPT $REMOTE_OUT" >/dev/null

echo "==> retrieving dump"
mkdir -p "$REPO/dumps/g2"
run_adb pull "$REMOTE_OUT" "$OUT" >/dev/null || { echo 'ERROR: adb pull failed'; exit 1; }

echo "==> cleaning up device temp files"
run_adb shell "rm -f $REMOTE_SCRIPT $REMOTE_OUT" >/dev/null
rm -f "$TMP"

if [ ! -s "$OUT" ]; then
  echo "ERROR: dump is empty; nothing will be committed."
  exit 1
fi
if ! grep -q "END schema=1" "$OUT"; then
  echo "ERROR: dump is truncated (no end marker); nothing will be committed."
  echo "       Kept for inspection: $OUT"
  exit 1
fi

echo "==> dump looks complete: $(wc -c < "$OUT") bytes, $(wc -l < "$OUT") lines"

echo "==> committing"
git add "$OUT" || exit 1
if git diff --cached --quiet; then
  echo "Nothing staged (identical dump already committed?). Stopping."
  exit 0
fi
git commit -m "data: consolidated G2 read-only hardware dump ${STAMP}" \
           -m "Collected by scripts/$(basename "$0"). Read-only: SoC identity, SDCC2 gaps, boot chain, subsystem inventory. No device write, flash, erase, repartition, slot, AVB or firmware operation." || exit 1

echo "==> pushing to origin/$BRANCH"
DELAY=2
ATTEMPT=1
until git push -u origin "$BRANCH"; do
  if [ "$ATTEMPT" -ge 5 ]; then
    echo "ERROR: push failed after 5 attempts. The commit is safe locally:"
    git log --oneline -1
    echo "Retry manually with: git push -u origin $BRANCH"
    exit 1
  fi
  echo "push failed (attempt $ATTEMPT), retrying in ${DELAY}s..."
  sleep "$DELAY"
  DELAY=$((DELAY * 2))
  ATTEMPT=$((ATTEMPT + 1))
done

echo
echo "DONE"
echo "  file   : $OUT"
echo "  branch : $BRANCH"
echo "  commit : $(git rev-parse --short HEAD)"
