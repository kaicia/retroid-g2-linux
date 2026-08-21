#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-sdhci-dependency-resolution-${STAMP}.txt"
REMOTE_SCRIPT="/data/local/tmp/g2-sdhci-dependency-resolution-${STAMP}.sh"
REMOTE_OUT="/data/local/tmp/g2-sdhci-dependency-resolution-${STAMP}.txt"
cd "$REPO" || exit 1
run_adb(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb "$@"; }
if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2-sdhci-dependency-resolution-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"
hex(){ od -An -tx1 "$1" 2>/dev/null | tr -d ' \n'; }
text(){ tr '\000' ' ' < "$1" 2>/dev/null; echo; }
show(){ p="$1"; echo "===== $p ====="; [ -e "$p" ] && { if [ -s "$p" ]; then hex "$p"; echo; else echo EMPTY_OR_BOOLEAN; fi; } || echo MISSING; }
resolve(){ label="$1"; val="$2"; echo "===== RESOLVE $label ($val) ====="; find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do [ "$(hex "$p")" = "$val" ] && echo "$(dirname "$p")"; done; }
echo '===== IDENTITY ====='; getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint
for f in cd-gpios cd-debounce-delay-ms pinctrl-names interconnect-names interconnects operating-points-v2 vdd-supply vdd-io-supply iommus; do show "$NODE/$f"; done
for f in qos0 qos1; do D="$NODE/$f"; echo "===== $f DIRECTORY ====="; ls -la "$D" 2>&1; [ -d "$D" ] && find "$D" -maxdepth 2 -type f | sort | while read -r p; do echo "--- $p ---"; hex "$p"; echo; done; done
for x in 0000016f 00000352 00000359 0000012a 000001a2 00000189 000001a3 000001a4 000001a5 000003ac 000003ad; do resolve PHANDLE "$x"; done

echo '===== SDHC2 OPP ====='; OPP=$(find "$BASE" -type d -name sdhc2-opp-table 2>/dev/null | head -1); echo "OPP=$OPP"; [ -n "$OPP" ] && find "$OPP" -maxdepth 2 -type f | sort | while read -r p; do echo "--- $p ---"; hex "$p"; echo; done

echo '===== SDHC2 PINCTRL ====='; for n in sdc2_on sdc2_off; do D=$(find "$BASE" -type d -name "$n" 2>/dev/null | head -1); echo "NODE=$D"; [ -n "$D" ] && find "$D" -maxdepth 3 -type f | sort | while read -r p; do echo "--- $p ---"; hex "$p"; echo; done; done

echo '===== ALL SDHCI BUS BANDWIDTH CANDIDATES ====='; find "$BASE" -type f \( -name '*bus*' -o -name '*bcm*' -o -name '*bw*' \) 2>/dev/null | grep -E 'sdh|soc|interconnect|bcm|bus' | head -300 | while read -r p; do echo "--- $p ---"; hex "$p"; echo; done

echo '===== SAFETY ====='; echo 'READ-ONLY Device Tree audit. No block-device, flash, erase, format, repartition, slot, AVB or firmware operation.'
EOF
chmod 700 "$TMP"
run_adb push "$TMP" "$REMOTE_SCRIPT" || exit 1
run_adb shell sh -n "$REMOTE_SCRIPT" || exit 1
run_adb shell sh "$REMOTE_SCRIPT" "$REMOTE_OUT" || exit 1
mkdir -p "$REPO/dumps/g2"
run_adb pull "$REMOTE_OUT" "$OUT" || exit 1
[ -s "$OUT" ] || { echo 'ERROR: empty result'; exit 1; }
run_adb shell rm -f "$REMOTE_SCRIPT" "$REMOTE_OUT" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-sdhci-dependency-resolution-readonly-v1.sh
git commit -m "data: save G2 SDHCI dependency resolution audit" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
