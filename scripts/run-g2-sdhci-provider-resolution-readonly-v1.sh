#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-sdhci-provider-resolution-${STAMP}.txt"
REMOTE_SCRIPT="/data/local/tmp/g2-sdhci-provider-resolution-${STAMP}.sh"
REMOTE_OUT="/data/local/tmp/g2-sdhci-provider-resolution-${STAMP}.txt"
cd "$REPO" || exit 1
run_adb(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb "$@"; }
if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2-sdhci-provider-resolution-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"
hex(){ od -An -tx1 "$1" 2>/dev/null | tr -d ' \n'; }
show(){ p="$1"; echo "--- $p ---"; if [ -e "$p" ]; then hex "$p"; echo; else echo MISSING; fi; }
resolve(){ label="$1"; val="$2"; echo "===== $label PHANDLE $val ====="; find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do if [ "$(hex "$p")" = "$val" ]; then echo "NODE=$(dirname "$p")"; fi; done; }
dump_node(){ d="$1"; echo "===== NODE $d ====="; if [ -d "$d" ]; then ls -la "$d" 2>&1; find "$d" -maxdepth 1 -type f | sort | while read -r p; do show "$p"; done; else echo MISSING; fi; }
echo '===== IDENTITY ====='; getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint

echo '===== CARD DETECT ====='; show "$NODE/cd-gpios"; show "$NODE/cd-debounce-delay-ms"
resolve 'CD GPIO CONTROLLER' 0000016c
GPIO_NODE=$(find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do if [ "$(hex "$p")" = "0000016c" ]; then dirname "$p"; break; fi; done)
[ -n "$GPIO_NODE" ] && dump_node "$GPIO_NODE"

for x in 000001a2 00000189 000001a3 000001a4; do
  resolve 'INTERCONNECT' "$x"
  D=$(find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do if [ "$(hex "$p")" = "$x" ]; then dirname "$p"; break; fi; done)
  [ -n "$D" ] && dump_node "$D"
done

echo '===== INTERCONNECT PROVIDER CANDIDATES ====='
find "$BASE" -type d 2>/dev/null | grep -E '/interconnect(@|$)|interconnect' | head -200 | while read -r d; do echo "NODE=$d"; for f in compatible '#interconnect-cells' '#address-cells' '#size-cells' reg; do [ -e "$d/$f" ] && show "$d/$f"; done; done

echo '===== GPIO CONTROLLER CANDIDATES ====='
find "$BASE" -type d 2>/dev/null | grep -Ei '/(gpio|tlmm)(@|$)|gpio|tlmm' | head -200 | while read -r d; do echo "NODE=$d"; for f in compatible '#gpio-cells' gpio-controller gpio-ranges reg; do [ -e "$d/$f" ] && show "$d/$f"; done; done

echo '===== SAFETY ====='; echo 'READ-ONLY Device Tree audit only. No block-device, flash, erase, format, repartition, slot, AVB or firmware operation.'
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
git add "$OUT" scripts/run-g2-sdhci-provider-resolution-readonly-v1.sh
git commit -m "data: save G2 GPIO and interconnect provider audit" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
