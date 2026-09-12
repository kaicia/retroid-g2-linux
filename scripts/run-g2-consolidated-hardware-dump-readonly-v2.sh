#!/data/data/com.termux/files/usr/bin/bash
#
# Consolidated read-only G2 hardware dump, v2.
#
# Produces TWO artifacts:
#
#   1. dumps/g2/g2-devicetree-<stamp>.tar.gz
#      The ENTIRE /sys/firmware/devicetree/base tree. This is the important
#      one: with the whole DT in the repository, every future device-tree
#      question is answerable offline and never needs the device again.
#
#   2. dumps/g2/g2-consolidated-hardware-<stamp>.txt
#      A readable report: SoC identity, SDCC2 gaps, boot chain and console
#      paths, subsystem inventory, and kernel/proc/sys state.
#
# STRICTLY READ-ONLY. No flash, erase, format, repartition, slot switch, AVB
# or firmware operation. No block-device content is read -- partitions are
# listed by name only. Nothing is written to the device outside
# /data/local/tmp, and those files are removed at the end.
#
# On success both artifacts are committed and pushed to the branch currently
# checked out in $REPO. It never switches branches and never force-pushes.
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-consolidated-hardware-${STAMP}.txt"
DTOUT="$REPO/dumps/g2/g2-devicetree-${STAMP}.tar.gz"
REMOTE_SCRIPT="/data/local/tmp/g2-consolidated-${STAMP}.sh"
REMOTE_OUT="/data/local/tmp/g2-consolidated-${STAMP}.txt"
REMOTE_DT="/data/local/tmp/g2-devicetree-${STAMP}.tar.gz"

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
# $1 = text report path, $2 = device-tree tarball path
OUT="$1"; DT="$2"
BASE=/sys/firmware/devicetree/base

# ---- archive the whole device tree first -------------------------------
# /sys/firmware/devicetree/base is a static representation of the DTB, so
# archiving it is a plain read. Only this subtree is touched, never all of /sys.
tar czf "$DT" -C /sys/firmware/devicetree base 2>/dev/null \
  || tar czf "$DT" -C /sys/firmware/devicetree/.. devicetree 2>/dev/null

exec >"$OUT" 2>&1

hex(){ [ -f "$1" ] && od -An -tx1 "$1" 2>/dev/null | tr -d ' \n'; }
txt(){ [ -f "$1" ] && tr '\000' ' ' < "$1" 2>/dev/null; }
sec(){ echo; echo "############ $* ############"; }
sub(){ echo; echo "===== $* ====="; }
cat_if(){ if [ -r "$1" ]; then echo "--- $1 ---"; cat "$1" 2>/dev/null; else echo "--- $1 --- UNREADABLE"; fi; }
ls_if(){ if [ -e "$1" ]; then echo "--- ls $1 ---"; ls -l "$1" 2>/dev/null; else echo "--- ls $1 --- MISSING"; fi; }
props(){
  d="$1"; sub "NODE $d"
  [ -d "$d" ] || { echo MISSING; return; }
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    case "$b" in
      compatible|name|label|status|*-names|*-path|bootargs|qcom,*-name)
        echo "$b= $(txt "$f")" ;;
      *) echo "$b= $(hex "$f")" ;;
    esac
  done
}
tree_props(){ props "$1"; for c in "$1"/*; do [ -d "$c" ] && props "$c"; done; }
resolve(){
  v="$1"
  find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do
    [ "$(hex "$p")" = "$v" ] && { dirname "$p"; break; }
  done
}

echo "G2 CONSOLIDATED READ-ONLY HARDWARE DUMP"
echo "date=$(date)"
echo "schema=2"
echo "devicetree_archive=$(basename "$DT")"
echo "id=$(getprop ro.product.model) / $(getprop ro.product.device)"

############################################################
sec "A. SOC IDENTITY"

sub "A1 all read-only properties (full getprop)"
getprop

sub "A2 /sys/devices/soc0 -- decisive SoC identity"
if [ -d /sys/devices/soc0 ]; then
  for f in /sys/devices/soc0/*; do
    [ -f "$f" ] && echo "$(basename $f) = $(cat $f 2>/dev/null)"
  done
else
  echo "/sys/devices/soc0 MISSING"
fi
ls_if /sys/bus/soc/devices

sub "A3 device tree root identity"
for p in model compatible qcom,msm-id qcom,board-id qcom,pmic-id serial-number; do
  case "$p" in
    model|compatible) echo "$p = $(txt $BASE/$p)" ;;
    *)               echo "$p = $(hex $BASE/$p)" ;;
  esac
done

sub "A4 kernel / cpu / memory"
uname -a
cat_if /proc/version
cat_if /proc/cmdline
cat_if /proc/bootconfig
cat_if /proc/meminfo
echo "--- cpuinfo ---"; cat /proc/cpuinfo 2>/dev/null
echo "--- cpu topology / freq ---"
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  [ -d "$c" ] || continue
  echo "$(basename $c): max=$(cat $c/cpufreq/cpuinfo_max_freq 2>/dev/null) min=$(cat $c/cpufreq/cpuinfo_min_freq 2>/dev/null) $(cat $c/topology/core_id 2>/dev/null)/$(cat $c/topology/cluster_id 2>/dev/null)"
done
echo "--- kernel config ---"
if [ -r /proc/config.gz ]; then
  echo "/proc/config.gz present:"; zcat /proc/config.gz 2>/dev/null | grep -vE "^#|^$" | head -400
else
  echo "no /proc/config.gz"
fi

############################################################
sec "B. SDCC2 REMAINING GAPS"
SD=$BASE/soc/sdhci@8804000

sub "B1 full SDHCI node"
props "$SD"

sub "B2 pinctrl states behind pinctrl-0 / pinctrl-1"
for ph in $(hex $SD/pinctrl-0) $(hex $SD/pinctrl-1); do
  [ -n "$ph" ] || continue
  D=$(resolve "$ph")
  echo ">>> phandle $ph -> $D"
  [ -n "$D" ] && tree_props "$D"
done

sub "B3 card-detect and debounce"
echo "cd-gpios             = $(hex $SD/cd-gpios)"
echo "cd-debounce-delay-ms = $(hex $SD/cd-debounce-delay-ms)"

sub "B4 SD regulator nodes (PMXR2230 L13 / L23)"
for ph in $(hex $SD/vdd-supply) $(hex $SD/vdd-io-supply); do
  [ -n "$ph" ] || continue
  D=$(resolve "$ph")
  echo ">>> phandle $ph -> $D"
  [ -n "$D" ] && props "$D"
done
cat_if /sys/kernel/debug/regulator/regulator_summary

sub "B5 live SMMU stream id -- settles DT 0x140 vs upstream 0x540"
ls_if /sys/class/iommu
for d in /sys/class/iommu/*; do
  [ -e "$d" ] || continue
  echo "--- $d ---"; ls -l "$d/devices" 2>/dev/null
done
ls_if /sys/devices/platform/soc/8804000.sdhci/iommu
ls_if /sys/devices/platform/soc/8804000.sdhci/iommu_group
ls_if /sys/kernel/debug/iommu

sub "B6 live mmc host state"
ls_if /sys/class/mmc_host
for h in /sys/class/mmc_host/mmc*; do
  [ -e "$h" ] || continue
  echo "--- $h ---"
  for f in "$h"/*; do [ -f "$f" ] && echo "$(basename $f) = $(cat $f 2>/dev/null)"; done
done
cat_if /sys/kernel/debug/mmc1/ios

sub "B7 live clock rates"
if [ -r /sys/kernel/debug/clk/clk_summary ]; then
  grep -iE "sdcc|qup|gcc_sdcc" /sys/kernel/debug/clk/clk_summary 2>/dev/null
else
  echo "clk_summary unreadable (needs root)"
fi

############################################################
sec "C. BOOT CHAIN / CONSOLE / SD BOOT FEASIBILITY"

sub "C1 chosen node -- bootargs, stdout-path, initrd"
tree_props "$BASE/chosen"

sub "C2 debug UART designated by stdout-path (qup_uart@a94000)"
# Upstream calls this uart5: serial@a94000, compatible qcom,geni-debug-uart.
# What we need is the G2's PIN assignment for it, since the G2 TLMM map is
# known to differ from upstream milos.
for d in \
  "$BASE/soc/qcom,qupv3_0_geni_se@ac0000/qcom,qup_uart@a94000" \
  "$BASE/soc/qcom,qupv3_0_geni_se@ac0000" ; do
  props "$d"
done
echo "--- resolve that uart's pinctrl phandles ---"
U="$BASE/soc/qcom,qupv3_0_geni_se@ac0000/qcom,qup_uart@a94000"
for ph in $(hex $U/pinctrl-0) $(hex $U/pinctrl-1); do
  [ -n "$ph" ] || continue
  D=$(resolve "$ph")
  echo ">>> phandle $ph -> $D"
  [ -n "$D" ] && tree_props "$D"
done
echo "--- any other geni uart nodes ---"
find "$BASE/soc" -maxdepth 2 -type d -name "*uart*" 2>/dev/null

sub "C3 reserved-memory -- ramoops, splash, uefi/xbl logs"
# ramoops gives a console-less evidence channel: a kernel log that survives
# reboot and can be read back from Android. splash_region is the candidate
# simple-framebuffer handoff area.
for n in ramoops_region splash_region uefi_log_region@81ce4000 \
         xbl_dtlog_region@81a00000 tme_log_region@81ce0000 \
         debug_kinfo_region mem_dump_region va_md_mem_region; do
  props "$BASE/reserved-memory/$n"
done
echo "--- every reserved-memory child, name + reg + size ---"
for d in "$BASE"/reserved-memory/*; do
  [ -d "$d" ] || continue
  echo "$(basename $d): compatible=$(txt $d/compatible) reg=$(hex $d/reg) size=$(hex $d/size) no-map=$([ -e $d/no-map ] && echo yes || echo no)"
done

sub "C4 existing pstore / ramoops readback"
ls_if /sys/fs/pstore
for f in /sys/fs/pstore/*; do [ -f "$f" ] && { echo "--- $f ---"; head -60 "$f" 2>/dev/null; }; done
ls_if /dev/pstore

sub "C5 boot / verified boot / slot state"
getprop | grep -iE "ro\.boot\.|bootloader|verifiedboot|slot|avb|vbmeta|secure|unlock"

sub "C6 partition names only -- no content is read"
ls_if /dev/block/by-name
ls_if /dev/block/bootdevice/by-name
echo "--- EFI/ESP-looking partitions ---"
for n in esp efi EFI uefi uefi_a uefi_b uefivarstore; do
  [ -e "/dev/block/by-name/$n" ] && echo "present: /dev/block/by-name/$n"
done
cat_if /proc/mounts
cat_if /proc/partitions
echo "--- filesystems the kernel knows ---"; cat /proc/filesystems 2>/dev/null

sub "C7 external SD"
ls_if /sys/block
for f in /sys/block/mmcblk1/size /sys/block/mmcblk1/ro /sys/block/mmcblk1/removable; do
  [ -r "$f" ] && echo "$f = $(cat $f 2>/dev/null)"
done
ls_if /sys/block/mmcblk1

############################################################
sec "D. SUBSYSTEM INVENTORY"

sub "D1 display -- panel is qcom,mdss_dsi_g1548_fhd_plus_60_video per bootargs"
ls_if /sys/class/drm
for d in /sys/class/drm/*/status; do [ -r "$d" ] && echo "$d = $(cat $d 2>/dev/null)"; done
for d in /sys/class/drm/*/modes; do [ -r "$d" ] && { echo "--- $d ---"; cat "$d" 2>/dev/null; }; done
echo "--- panel / dsi nodes in DT ---"
find "$BASE" -maxdepth 5 -type d \( -name "*panel*" -o -name "*dsi*" -o -name "*g1548*" \) 2>/dev/null | head -40
for p in $(find "$BASE" -maxdepth 5 -type d -name "*g1548*" 2>/dev/null | head -3); do tree_props "$p"; done
echo "--- mdss / display controller ---"
for p in $(find "$BASE/soc" -maxdepth 1 -type d \( -name "*mdss*" -o -name "*display*" \) 2>/dev/null | head -4); do props "$p"; done

sub "D2 GPU"
ls_if /sys/class/kgsl/kgsl-3d0
for f in gpu_model gpumodel gpu_clock max_gpuclk devfreq/cur_freq gpubusy; do
  [ -r "/sys/class/kgsl/kgsl-3d0/$f" ] && echo "$f = $(cat /sys/class/kgsl/kgsl-3d0/$f 2>/dev/null)"
done
for p in $(find "$BASE/soc" -maxdepth 2 -type d -name "*gpu*" 2>/dev/null | head -4); do props "$p"; done

sub "D3 input -- buttons, sticks, touch"
cat_if /proc/bus/input/devices
ls_if /dev/input
for d in /sys/class/input/input*/name; do [ -r "$d" ] && echo "$d = $(cat $d 2>/dev/null)"; done

sub "D4 usb"
ls_if /sys/class/udc
cat_if /sys/kernel/debug/usb/devices
for p in $(find "$BASE/soc" -maxdepth 1 -type d -name "*usb*" 2>/dev/null | head -4); do props "$p"; done

sub "D5 audio"
ls_if /proc/asound
cat_if /proc/asound/cards
cat_if /proc/asound/pcm

sub "D6 wifi / bluetooth"
getprop | grep -iE "wifi|wlan|bluetooth|bt\.|kiwi"
ls_if /sys/class/net

sub "D7 power / battery / thermal / regulators"
ls_if /sys/class/power_supply
for s in /sys/class/power_supply/*; do
  [ -d "$s" ] || continue
  echo "--- $s ---"
  for f in "$s"/*; do [ -f "$f" ] && echo "$(basename $f) = $(cat $f 2>/dev/null)"; done
done
echo "--- thermal zones ---"
for z in /sys/class/thermal/thermal_zone*/type; do [ -r "$z" ] && echo "$z = $(cat $z 2>/dev/null)"; done

############################################################
sec "E. KERNEL / PROC / SYS STATE"

sub "E1 loaded modules"
cat_if /proc/modules

sub "E2 interrupts -- cross-checks the SDCC2 IRQ conflict (207/223)"
cat_if /proc/interrupts

sub "E3 iomem / ioports"
cat_if /proc/iomem

sub "E4 devices / misc / drivers"
cat_if /proc/devices
cat_if /proc/misc
ls_if /sys/bus/platform/drivers

sub "E5 dmesg (usually root-only)"
dmesg 2>/dev/null | tail -400 || echo "dmesg unreadable"

sub "E6 device-tree size accounting"
echo "DT node count : $(find $BASE -type d 2>/dev/null | wc -l)"
echo "DT prop count : $(find $BASE -type f 2>/dev/null | wc -l)"

############################################################
sec "SAFETY"
echo "READ-ONLY audit only."
echo "No block-device content was read; partitions listed by name only."
echo "No flash, erase, format, repartition, slot, AVB or firmware operation."
echo "END schema=2"
EOF

echo "==> pushing collector to device"
run_adb push "$TMP" "$REMOTE_SCRIPT" >/dev/null || { echo 'ERROR: adb push failed'; rm -f "$TMP"; exit 1; }
run_adb shell "chmod 755 $REMOTE_SCRIPT" >/dev/null

echo "==> running collector on device (read-only; archiving the device tree may take a minute)"
run_adb shell "sh $REMOTE_SCRIPT $REMOTE_OUT $REMOTE_DT" >/dev/null

echo "==> retrieving artifacts"
mkdir -p "$REPO/dumps/g2"
run_adb pull "$REMOTE_OUT" "$OUT" >/dev/null || { echo 'ERROR: adb pull (report) failed'; exit 1; }
run_adb pull "$REMOTE_DT" "$DTOUT" >/dev/null || echo 'WARNING: device-tree archive could not be pulled'

echo "==> cleaning up device temp files"
run_adb shell "rm -f $REMOTE_SCRIPT $REMOTE_OUT $REMOTE_DT" >/dev/null
rm -f "$TMP"

if [ ! -s "$OUT" ]; then
  echo "ERROR: report is empty; nothing will be committed."
  exit 1
fi
if ! grep -q "END schema=2" "$OUT"; then
  echo "ERROR: report is truncated (no end marker); nothing will be committed."
  echo "       Kept for inspection: $OUT"
  exit 1
fi

echo "==> report   : $(wc -c < "$OUT") bytes, $(wc -l < "$OUT") lines"
ADD="$OUT"
if [ -s "$DTOUT" ]; then
  echo "==> DT archive: $(wc -c < "$DTOUT") bytes"
  ADD="$ADD $DTOUT"
else
  rm -f "$DTOUT"
  echo "==> DT archive: MISSING (report still usable)"
fi

echo "==> committing"
git add $ADD || exit 1
if git diff --cached --quiet; then
  echo "Nothing staged (identical dump already committed?). Stopping."
  exit 0
fi
git commit -m "data: consolidated G2 read-only hardware dump ${STAMP}" \
           -m "Collected by scripts/$(basename "$0"). Full device-tree archive plus SoC identity, SDCC2 gaps, boot/console paths, subsystem inventory and kernel state. Read-only: no device write, flash, erase, repartition, slot, AVB or firmware operation." || exit 1

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
echo "  report : $OUT"
echo "  dt     : $DTOUT"
echo "  branch : $BRANCH"
echo "  commit : $(git rev-parse --short HEAD)"
