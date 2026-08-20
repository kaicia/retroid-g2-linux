#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-sdhci-linux-dt-audit-${STAMP}.txt"
REMOTE_OUT="/sdcard/g2-sdhci-linux-dt-audit-${STAMP}.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB='ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb'
if ! eval "$ADB devices" | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2_sdhci_linux_dt_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
sec(){ echo; echo "===== $1 ====="; }
NODE=/sys/firmware/devicetree/base/soc/sdhci@8804000
sec "IDENTITY"
getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint; getprop ro.boot.slot_suffix
sec "SDHCI NODE"
ls -ld "$NODE" 2>&1 || true
for f in compatible reg status bus-width interrupts interrupt-names clocks clock-names resets reset-names pinctrl-0 pinctrl-1 pinctrl-names cd-gpios cd-debounce-delay-ms vdd-supply vdd-io-supply iommus interconnects operating-points-v2 qcom,dll-hsr-list qcom,restore-after-cx-collapse qcom,iommu-dma qcom,iommu-geometry; do
  p="$NODE/$f"; echo "--- $f ---"; if [ -f "$p" ]; then wc -c "$p"; od -An -tx1 "$p"; echo -n "strings: "; tr '\000' ' ' < "$p" 2>/dev/null; echo; else echo MISSING; fi
done
sec "SDHCI CHILD/RELATED NODES"
find "$NODE" -maxdepth 2 -print 2>/dev/null | sort
sec "PINCTRL REFERENTS"
P=/sys/firmware/devicetree/base/soc/pinctrl@f000000
for x in "$P"/*sdc2* "$P"/*sd*; do [ -e "$x" ] && { echo "--- $x ---"; find "$x" -maxdepth 1 -type f -print 2>/dev/null | sort; }; done
sec "MMIO/SYSFS DRIVER"
D=/sys/devices/platform/soc/8804000.sdhci
find "$D" -maxdepth 2 -type f -print 2>/dev/null | sort | head -n 300
readlink -f "$D/driver" 2>/dev/null || true
sec "MMC HOST"
find /sys/devices/platform/soc/8804000.sdhci/mmc_host/mmc1 -maxdepth 2 -print 2>/dev/null | sort
sec "KERNEL CONFIG ACCESS"
for f in /proc/config.gz /system/lib/modules/*/build/.config /vendor/lib/modules/*/build/.config; do [ -e "$f" ] && echo "$f"; done
sec "SAFETY"
echo "READ-ONLY Device Tree/sysfs audit only"
echo "No UFS/SD block contents were read and no flash/erase/format/repartition/slot/AVB operation was performed."
EOF
printf '===== push script =====\n'
eval "$ADB push "$TMP" /data/local/tmp/g2-sdhci-linux-dt-audit.sh" || exit 1
printf '===== run on G2 =====\n'
eval "$ADB shell sh /data/local/tmp/g2-sdhci-linux-dt-audit.sh "$REMOTE_OUT"" || exit 1
printf '===== pull result =====\n'
mkdir -p dumps/g2
eval "$ADB pull "$REMOTE_OUT" "$OUT"" || exit 1
printf '===== cleanup =====\n'
eval "$ADB shell rm -f /data/local/tmp/g2-sdhci-linux-dt-audit.sh "$REMOTE_OUT"" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-sdhci-linux-dt-audit-readonly.sh
git commit -m "data: save G2 SDHCI Linux DT audit" || exit 1
git push origin main || exit 1
printf '\nDONE: %s\n' "$OUT"
