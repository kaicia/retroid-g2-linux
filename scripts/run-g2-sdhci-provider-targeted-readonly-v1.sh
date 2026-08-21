#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-sdhci-provider-targeted-${STAMP}.txt"
REMOTE_SCRIPT="/data/local/tmp/g2-sdhci-provider-targeted-${STAMP}.sh"
REMOTE_OUT="/data/local/tmp/g2-sdhci-provider-targeted-${STAMP}.txt"
cd "$REPO" || exit 1
run_adb(){ ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb "$@"; }
if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2-sdhci-provider-targeted-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
hex(){ od -An -tx1 "$1" 2>/dev/null | tr -d ' \n'; }
text(){ tr '\000' ' ' < "$1" 2>/dev/null; echo; }
resolve(){ val="$1"; find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do [ "$(hex "$p")" = "$val" ] && dirname "$p" && break; done; }
show(){ f="$1"; [ -e "$f" ] || return; echo -n "$(basename "$f")="; case "$(basename "$f")" in compatible|name) text "$f";; *) hex "$f"; echo;; esac; }
dump(){ d="$1"; echo "===== NODE $d ====="; for f in compatible name reg '#interconnect-cells' '#address-cells' '#size-cells' phandle; do show "$d/$f"; done; echo "-- DIRECT CHILDREN --"; for c in "$d"/*; do [ -d "$c" ] || continue; echo "CHILD=$(basename "$c")"; for f in compatible name reg phandle '#interconnect-cells' master-id slave-id qcom,bcm-name qcom,channels qcom,links; do show "$c/$f"; done; done; }
echo '===== G2 IDENTITY ====='; getprop ro.product.model; getprop ro.product.device
for x in 000001a2 00000189 000001a3 000001a4; do echo "===== PHANDLE $x ====="; D=$(resolve "$x"); echo "NODE=$D"; [ -n "$D" ] && dump "$D"; done
echo '===== GPIO CONTROLLER ====='; D=$(resolve 0000016c); echo "NODE=$D"; [ -n "$D" ] && { for f in compatible name reg '#gpio-cells' gpio-controller phandle; do show "$D/$f"; done; }
echo '===== SDHCI INTERCONNECT RAW ====='; for f in interconnect-names interconnects; do echo "$f="; hex "$BASE/soc/sdhci@8804000/$f"; echo; done
echo '===== SAFETY ====='; echo 'READ-ONLY Device Tree audit only.'
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
git add "$OUT" scripts/run-g2-sdhci-provider-targeted-readonly-v1.sh
git commit -m "data: save targeted G2 SDHCI provider audit" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
