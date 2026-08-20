#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-dt-kernel-source-audit-${STAMP}.txt"
REMOTE_OUT="/sdcard/g2-dt-kernel-source-audit-${STAMP}.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB='ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb'
if ! eval "$ADB devices" | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2_dt_audit_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
sec(){ echo; echo "===== $1 ====="; }
show_prop(){ p="$1"; echo "--- $p ---"; if [ -f "$p" ]; then xxd -p -c 256 "$p" 2>/dev/null || od -An -tx1 "$p" 2>/dev/null; else echo MISSING; fi; }
sec "IDENTITY"
getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint; getprop ro.boot.slot_suffix; getprop ro.boot.boot_devices; getprop ro.boot.bootdevice; uname -a
sec "DT ROOT"
for f in model compatible chassis-type; do show_prop "/sys/firmware/devicetree/base/$f"; done
sec "DT CHOSEN"
find /sys/firmware/devicetree/base/chosen -maxdepth 2 -type f -print 2>/dev/null | sort
for f in /sys/firmware/devicetree/base/chosen/*; do [ -f "$f" ] && { echo "--- $f ---"; xxd -p -c 256 "$f" 2>/dev/null || od -An -tx1 "$f" 2>/dev/null; }; done
sec "DT FIRMWARE"
find /sys/firmware/devicetree/base/firmware -maxdepth 3 -print 2>/dev/null | sort
for d in /sys/firmware/devicetree/base/firmware/*; do [ -d "$d" ] && { echo "--- $d ---"; find "$d" -maxdepth 2 -type f -print 2>/dev/null | sort; }; done
sec "DT BOOT-RELEVANT NODES"
for d in /sys/firmware/devicetree/base/soc/sdhci@8804000 /sys/firmware/devicetree/base/soc/ufshc@1d84000 /sys/firmware/devicetree/base/soc/pinctrl@f000000 /sys/firmware/devicetree/base/reserved-memory; do echo "--- $d ---"; find "$d" -maxdepth 2 -type f -print 2>/dev/null | sort; done
sec "SDHCI DT PROPERTIES"
D=/sys/firmware/devicetree/base/soc/sdhci@8804000
for f in compatible status reg bus-width max-frequency clock-names clocks pinctrl-names pinctrl-0 pinctrl-1 cd-gpios cd-debounce-delay-ms vdd-supply vdd-io-supply; do show_prop "$D/$f"; done
sec "PINCTRL DT NODES"
P=/sys/firmware/devicetree/base/soc/pinctrl@f000000
find "$P" -maxdepth 3 -type f -print 2>/dev/null | grep -Ei 'sdc|sdhci|gpio|pin' | sort | while read f; do echo "--- $f ---"; xxd -p -c 256 "$f" 2>/dev/null || od -An -tx1 "$f" 2>/dev/null; done
sec "UFS DT PROPERTIES"
U=/sys/firmware/devicetree/base/soc/ufshc@1d84000
[ -d "$U" ] && find "$U" -maxdepth 2 -type f -print 2>/dev/null | sort | while read f; do echo "--- $f ---"; xxd -p -c 256 "$f" 2>/dev/null || od -An -tx1 "$f" 2>/dev/null; done
sec "KERNEL CONFIG AVAILABILITY"
for p in /proc/config.gz /sys/kernel/config /system/lib/modules /vendor/lib/modules; do echo "--- $p ---"; ls -la "$p" 2>&1 | head -n 80; done
sec "KERNEL MODULES"
cat /proc/modules 2>&1 | grep -Ei 'sdhci|mmc|pinctrl|ufs|qcom|pineapple|cliffs' || true
sec "DRIVER SYSFS"
for p in /sys/bus/platform/drivers/sdhci-msm /sys/bus/mmc/drivers/mmcblk /sys/bus/platform/drivers/qcom-ufs /sys/bus/platform/drivers/pinctrl-qcom; do echo "--- $p ---"; readlink -f "$p" 2>&1; ls -la "$p" 2>&1 | head -n 80; done
sec "FIRMWARE / DT COMPATIBLE SEARCH"
for root in /sys/firmware/devicetree/base/soc /sys/firmware/devicetree/base; do
  echo "--- $root compatible matches ---"
  find "$root" -type f -name compatible -print 2>/dev/null | while read f; do
    v="$(strings "$f" 2>/dev/null | tr '\n' ' ')"
    echo "$f :: $v"
  done | grep -Ei 'pineapple|cliffs|sdhci|qcom|ufshc' | head -n 300
 done
sec "BOOT PROPERTIES"
getprop | grep -Ei 'boot|uefi|abl|xbl|dtb|dtbo|slot|avb|vbmeta|efi|uefi' || true
sec "BOOT CMDLINE ACCESS"
cat /proc/cmdline 2>&1 || true
sec "SAFETY"
echo "READ-ONLY DT/KERNEL SOURCE AUDIT ONLY"
echo "No block-device contents were read. No dd, flash, erase, format, repartition, slot, AVB, mount-write, or firmware modification operations were performed."
EOF
printf '===== push script =====\n'
eval "$ADB push "$TMP" /data/local/tmp/g2-dt-kernel-source-audit.sh" || exit 1
printf '===== run on G2 =====\n'
eval "$ADB shell sh /data/local/tmp/g2-dt-kernel-source-audit.sh "$REMOTE_OUT"" || exit 1
printf '===== pull result =====\n'
mkdir -p dumps/g2
eval "$ADB pull "$REMOTE_OUT" "$OUT"" || exit 1
printf '===== cleanup =====\n'
eval "$ADB shell rm -f /data/local/tmp/g2-dt-kernel-source-audit.sh "$REMOTE_OUT"" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-dt-kernel-source-audit-readonly.sh
git commit -m "data: save G2 DT kernel source audit" || exit 1
git push origin main || exit 1
printf '\nDONE: %s\n' "$OUT"
