#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-sdhci-node-complete-${STAMP}.txt"
G2SCRIPT="/data/local/tmp/g2-sdhci-node-complete-${STAMP}.sh"
REMOTE="$G2SCRIPT.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
run_adb(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb "$@"; }
if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2-sdhci-node-complete-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"
prop(){ p="$NODE/$1"; echo "===== $1 ====="; if [ -f "$p" ]; then od -An -tx1 "$p"; echo; else echo MISSING; fi; }
text(){ p="$NODE/$1"; echo "===== $1 (text) ====="; if [ -f "$p" ]; then tr '\000' '\n' < "$p" 2>/dev/null; else echo MISSING; fi; }
echo '===== IDENTITY ====='; getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint; getprop ro.boot.slot_suffix
text compatible
for f in reg interrupts interrupt-names clock-names clocks reset-names resets interconnect-names interconnects bus-width max-frequency non-removable cap-mmc-hs200 cap-mmc-hs400 qcom,dll-hsr-list qcom,dll-config qcom,ice qcom,ice-instance qcom,core_3_0 qcom,ddr-config operating-points-v2 vmmc-supply vqmmc-supply vdd-supply vdd-io-supply iommus pinctrl-0 pinctrl-1; do prop "$f"; done

echo '===== NODE DIRECTORY ====='; ls -la "$NODE" 2>&1
echo '===== PARENT / RELATED NODES ====='; PARENT=$(dirname "$NODE"); echo "PARENT=$PARENT"; ls -la "$PARENT" 2>&1 | head -200
for d in "$BASE/soc/gcc@100000" "$BASE/soc/clock-controller@100000" "$BASE/soc/interconnect@16e0000" "$BASE/soc/interconnect@1" "$BASE/soc/interconnect@24100000" "$BASE/soc/interconnect@1600000"; do
    if [ -d "$d" ]; then
        echo "===== RELATED $d ====="
        for f in compatible reg; do
            if [ -f "$d/$f" ]; then
                echo "--- $f ---"
                od -An -tx1 "$d/$f"
            fi
        done
    fi
done

echo '===== SDHC2 OPP TABLE RAW ====='; OPP=$(find "$BASE" -type d -name 'sdhc2-opp-table' 2>/dev/null | head -1); echo "OPP=$OPP"; if [ -n "$OPP" ] && [ -d "$OPP" ]; then find "$OPP" -maxdepth 2 -type f | sort | while read f; do echo "--- $f ---"; od -An -tx1 "$f" 2>&1; done; fi

echo '===== PINCTRL RAW ====='; for n in sdc2_on sdc2_off; do D=$(find "$BASE" -type d -name "$n" 2>/dev/null | head -1); echo "NODE=$D"; [ -n "$D" ] && find "$D" -maxdepth 2 -type f | sort | while read f; do echo "--- $f ---"; od -An -tx1 "$f" 2>&1; done; done

echo '===== SAFETY ====='; echo 'READ-ONLY Device Tree/sysfs audit only. No block-device contents, flash, erase, format, repartition, slot, AVB or firmware operation.'
EOF
chmod 700 "$TMP"
run_adb push "$TMP" "$G2SCRIPT" || exit 1
run_adb shell sh -n "$G2SCRIPT" || exit 1
run_adb shell sh "$G2SCRIPT" "$REMOTE" || exit 1
mkdir -p "$REPO/dumps/g2"
run_adb pull "$REMOTE" "$OUT" || exit 1
[ -s "$OUT" ] || { echo 'ERROR: empty result'; exit 1; }
run_adb shell rm -f "$G2SCRIPT" "$REMOTE" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-sdhci-node-complete-readonly-v1.sh
git commit -m "data: save complete G2 SDHCI node audit" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
