#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-sdhci-phandle-resolution-${STAMP}.txt"
REMOTE="/data/local/tmp/g2-sdhci-phandle-resolution-${STAMP}.txt"
G2SCRIPT="/data/local/tmp/g2-sdhci-phandle-resolution-${STAMP}.sh"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB=(fakeroot termux-adb)
ADB_ENV="ANDROID_NO_USE_FWMARK_CLIENT=1"
run_adb(){ env $ADB_ENV "${ADB[@]}" "$@"; }
if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2-phandle-resolution-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"
resolve(){ target="$1"; find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do v=$(od -An -tx1 "$p" 2>/dev/null | tr -d ' \n'); [ "$v" = "$target" ] && echo "$(dirname "$p")"; done; }
prop(){ echo "--- $1 ---"; od -An -tx1 "$NODE/$1" 2>&1; }
echo '===== IDENTITY ====='
getprop ro.product.model; getprop ro.product.device; getprop ro.boot.slot_suffix
 echo; echo '===== SDHCI PHANDLE PROPERTIES ====='
for f in clocks resets vdd-supply vdd-io-supply iommus interconnects operating-points-v2 pinctrl-0 pinctrl-1; do prop "$f"; done
 echo; echo '===== RESOLVED CLOCK/RESET CONTROLLER 0x0000016f ====='; resolve 0000016f
 echo; echo '===== RESOLVED VDD 0x00000352 ====='; resolve 00000352
 echo; echo '===== RESOLVED VDD-IO 0x00000359 ====='; resolve 00000359
 echo; echo '===== RESOLVED IOMMU 0x0000012a ====='; resolve 0000012a
 echo; echo '===== RESOLVED PINCTRL 0x000003ac ====='; resolve 000003ac
 echo; echo '===== RESOLVED PINCTRL 0x000003ad ====='; resolve 000003ad
 echo; echo '===== RELATED NODE PROPERTIES ====='
 for d in $(find "$BASE" -type d \( -name '*rpmh-regulator*' -o -name '*gcc*' -o -name '*clock*' -o -name '*interconnect*' -o -name '*smmu*' -o -name '*pinctrl*' \) 2>/dev/null | head -n 300); do
   echo "--- $d ---"
   for f in name compatible regulator-name clock-output-names; do
     if [ -f "$d/$f" ]; then echo -n "$f: "; tr '\000' ' ' < "$d/$f" 2>/dev/null; echo; fi
   done
 done
 echo; echo '===== SAFETY ====='
echo 'READ-ONLY Device Tree/sysfs audit only.'
echo 'No UFS/SD block contents, flash, erase, format, repartition, slot, AVB or firmware operation performed.'
EOF
chmod 700 "$TMP"
echo '===== PUSH G2 READ-ONLY SCRIPT ====='
run_adb push "$TMP" "$G2SCRIPT" || exit 1
echo '===== G2 SCRIPT SYNTAX ====='
run_adb shell sh -n "$G2SCRIPT" || exit 1
echo '===== RUN G2 AUDIT ====='
run_adb shell sh "$G2SCRIPT" "$REMOTE" || exit 1
echo '===== PULL RESULT ====='
mkdir -p dumps/g2
run_adb pull "$REMOTE" "$OUT" || exit 1
if [ ! -s "$OUT" ]; then echo "ERROR: result file missing or empty: $OUT"; exit 1; fi
echo '===== CLEANUP G2 TEMP FILES ====='
run_adb shell rm -f "$G2SCRIPT" "$REMOTE" || true
rm -f "$TMP"
echo '===== COMMIT + PUSH ====='
git add "$OUT" scripts/run-g2-sdhci-phandle-resolution-readonly-v2.sh
git commit -m "data: save G2 SDHCI phandle resolution" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
