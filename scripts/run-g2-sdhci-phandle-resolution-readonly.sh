#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="dumps/g2/g2-sdhci-phandle-resolution-${STAMP}.txt"
REMOTE="/sdcard/g2-sdhci-phandle-resolution-${STAMP}.txt"
cd "$REPO" || exit 1
git pull --ff-only || exit 1
ADB='ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb'
if ! eval "$ADB devices" | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then echo 'ERROR: exactly one ADB device must be connected.'; exit 1; fi
TMP="$REPO/.g2_phandle_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"; exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"
sec(){ echo; echo "===== $1 ====="; }
prop(){ p="$1"; echo "--- $p ---"; if [ -f "$p" ]; then od -An -tx4 "$p"; else echo MISSING; fi; }
resolve_phandle(){ target="$1"; echo "TARGET=$target"; find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do v=$(od -An -tx4 "$p" 2>/dev/null | tr -d ' \n'); [ "$v" = "$target" ] && echo "NODE=$(dirname "$p")"; done; }
sec "IDENTITY"; getprop ro.product.model; getprop ro.product.device; getprop ro.build.fingerprint; getprop ro.boot.slot_suffix
sec "SDHCI PHANDLE PROPERTIES"; for f in clocks resets vdd-supply vdd-io-supply iommus interconnects operating-points-v2 pinctrl-0 pinctrl-1; do prop "$NODE/$f"; done
sec "RESOLVE CLOCK CONTROLLER PHANDLE 0x0000016f"; resolve_phandle 0000016f
sec "RESOLVE RESET/CLOCK CONTROLLER PHANDLE 0x0000016f"; resolve_phandle 0000016f
sec "RESOLVE VDD 0x00000352"; resolve_phandle 00000352
sec "RESOLVE VDD-IO 0x00000359"; resolve_phandle 00000359
sec "RESOLVE IOMMU PHANDLE 0x0000012a"; resolve_phandle 0000012a
sec "RESOLVE INTERCONNECT PHANDLES"; for x in 000001a2 00000189 000001a3 000001a4; do resolve_phandle "$x"; done
sec "RESOLVE OPP PHANDLE 0x000001a5"; resolve_phandle 000001a5
sec "RESOLVE PINCTRL PHANDLES"; resolve_phandle 000003ac; resolve_phandle 000003ad
sec "RELATED NODE PROPERTIES"; for d in $(find "$BASE" -type d \( -name '*rpmh-regulator*' -o -name '*gcc*' -o -name '*clock*' -o -name '*interconnect*' -o -name '*smmu*' -o -name '*pinctrl*' \) 2>/dev/null | head -n 200); do echo "--- $d ---"; for f in name compatible regulator-name clock-output-names # invalid harmless token
; do [ -f "$d/$f" ] && { echo "$f:"; tr '\000' ' ' < "$d/$f" 2>/dev/null; echo; }; done; done
sec "SAFETY"; echo "READ-ONLY DT phandle resolution only"; echo "No block contents, flash, erase, format, repartition, slot, AVB, or firmware operation performed."
EOF
printf '===== push audit script =====\n'; eval "$ADB push "$TMP" /data/local/tmp/g2-phandle-resolution.sh" || exit 1
printf '===== run =====\n'; eval "$ADB shell sh /data/local/tmp/g2-phandle-resolution.sh "$REMOTE"" || exit 1
printf '===== pull =====\n'; mkdir -p dumps/g2; eval "$ADB pull "$REMOTE" "$OUT"" || exit 1
eval "$ADB shell rm -f /data/local/tmp/g2-phandle-resolution.sh "$REMOTE"" || true
rm -f "$TMP"
git add "$OUT" scripts/run-g2-sdhci-phandle-resolution-readonly.sh
git commit -m "data: save G2 SDHCI phandle resolution" || exit 1
git push origin main || exit 1
echo "DONE: $OUT"
