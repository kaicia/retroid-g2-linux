#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-sdhci-interconnect-opp-resolution-${STAMP}.txt"
G2SCRIPT="/data/local/tmp/g2-sdhci-interconnect-opp-${STAMP}.sh"
REMOTE="$G2SCRIPT.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB_ENV="ANDROID_NO_USE_FWMARK_CLIENT=1"
run_adb(){ env $ADB_ENV fakeroot termux-adb "$@"; }
if ! run_adb devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2-sdhci-interconnect-opp-${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"
resolve(){ target="$1"; find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do v=$(od -An -tx1 "$p" 2>/dev/null | tr -d ' \n'); [ "$v" = "$target" ] && echo "$(dirname "$p")"; done; }
readprop(){ p="$NODE/$1"; echo "--- $1 ---"; [ -f "$p" ] && od -An -tx1 "$p" || echo MISSING; }
nodeprop(){ d="$1"; echo "NODE=$d"; for f in name compatible reg clock-output-names # power-domains
 do [ -f "$d/$f" ] && { echo -n "$f: "; tr '\000' ' ' < "$d/$f" 2>/dev/null; echo; }; done; }
echo '===== IDENTITY ====='; getprop ro.product.model; getprop ro.product.device; getprop ro.boot.slot_suffix
echo; echo '===== SDHCI INTERCONNECT/OPP PROPERTIES ====='; readprop interconnects; readprop operating-points-v2
echo; echo '===== RESOLVE INTERCONNECT PHANDLES ====='; for x in 000001a2 00000189 000001a3 000001a4; do echo "PHANDLE=$x"; resolve "$x"; done
echo; echo '===== RESOLVE OPP PHANDLE ====='; resolve 000001a5
echo; echo '===== RESOLVED NODE DETAILS ====='; for x in 000001a2 00000189 000001a3 000001a4 000001a5; do find "$BASE" -type f -name phandle 2>/dev/null | while read p; do v=$(od -An -tx1 "$p" 2>/dev/null | tr -d ' \n'); if [ "$v" = "$x" ]; then d=$(dirname "$p"); nodeprop "$d"; fi; done; done
echo; echo '===== ALL OPP TABLES ====='; find "$BASE" -type d -iname '*opp*' 2>/dev/null | head -n 300 | while read d; do echo "--- $d ---"; for f in compatible opp-hz opp-microvolt opp-level; do [ -f "$d/$f" ] && { echo -n "$f: "; od -An -tx1 "$d/$f" 2>/dev/null; }; done; done
echo; echo '===== ALL RELEVANT INTERCONNECT NODES ====='; find "$BASE/soc" -type d -name 'interconnect@*' 2>/dev/null | while read d; do echo "--- $d ---"; [ -f "$d/compatible" ] && { echo -n 'compatible: '; tr '\000' ' ' < "$d/compatible"; echo; }; done
echo; echo '===== SAFETY ====='; echo 'READ-ONLY Device Tree audit only. No UFS/SD block access, flash, erase, format, repartition, slot, AVB or firmware operation.'
EOF
chmod 700 "$TMP"
run_adb push "$TMP" "$G2SCRIPT" || exit 1
run_adb shell sh -n "$G2SCRIPT" || exit 1
run_adb shell sh "$G2SCRIPT" "$REMOTE" || exit 1
mkdir -p "$REPO/dumps/g2"
run_adb pull "$REMOTE" "$OUT" || exit 1
[ -s "$OUT" ] || { echo "ERROR: empty result"; exit 1; }
run_adb shell rm -f "$G2SCRIPT" "$REMOTE" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-sdhci-interconnect-opp-resolution-readonly-v1.sh
git commit -m "data: save G2 SDHCI interconnect OPP audit" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
