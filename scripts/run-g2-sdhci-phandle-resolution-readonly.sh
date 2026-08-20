#!/data/data/com.termux/files/usr/bin/bash
set -u
REPO="$HOME/retroid-g2-linux"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPO/dumps/g2/g2-sdhci-phandle-resolution-${STAMP}.txt"
REMOTE="/sdcard/g2-sdhci-phandle-resolution-${STAMP}.txt"
ADB_CMD=(env ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb)
cd "$REPO" || exit 1
git pull --ff-only || exit 1

if ! "${ADB_CMD[@]}" devices | awk 'NR>1 && $2=="device" {n++} END{exit !(n==1)}'; then
    echo 'ERROR: exactly one ADB device must be connected.'
    exit 1
fi

TMP="$REPO/.g2_phandle_${STAMP}.sh"
cat > "$TMP" <<'EOF'
#!/system/bin/sh
OUT="$1"
exec >"$OUT" 2>&1
BASE=/sys/firmware/devicetree/base
NODE="$BASE/soc/sdhci@8804000"

sec() { echo; echo "===== $1 ====="; }
prop() {
    p="$1"
    echo "--- $p ---"
    if [ -f "$p" ]; then
        wc -c "$p"
        od -An -tx1 "$p"
        echo -n "strings: "
        tr '\000' ' ' < "$p" 2>/dev/null
        echo
    else
        echo MISSING
    fi
}
resolve_phandle() {
    target="$1"
    echo "TARGET=$target"
    find "$BASE" -type f -name phandle 2>/dev/null | while read -r p; do
        v=$(od -An -tx1 "$p" 2>/dev/null | tr -d ' \n')
        if [ "$v" = "$target" ]; then
            echo "NODE=$(dirname "$p")"
        fi
    done
}

sec "IDENTITY"
getprop ro.product.model
getprop ro.product.device
getprop ro.build.fingerprint
getprop ro.boot.slot_suffix

sec "SDHCI PHANDLE PROPERTIES"
for f in clocks resets vdd-supply vdd-io-supply iommus interconnects operating-points-v2 pinctrl-0 pinctrl-1; do
    prop "$NODE/$f"
done

sec "RESOLVE CLOCK/RESET CONTROLLER PHANDLE 0x0000016f"
resolve_phandle 0000016f

sec "RESOLVE VDD PHANDLE 0x00000352"
resolve_phandle 00000352

sec "RESOLVE VDD-IO PHANDLE 0x00000359"
resolve_phandle 00000359

sec "RESOLVE IOMMU PHANDLE 0x0000012a"
resolve_phandle 0000012a

sec "RESOLVE INTERCONNECT PHANDLES"
for x in 000001a2 00000189 000001a3 000001a4; do
    resolve_phandle "$x"
done

sec "RESOLVE OPP PHANDLE 0x000001a5"
resolve_phandle 000001a5

sec "RESOLVE PINCTRL PHANDLES"
resolve_phandle 000003ac
resolve_phandle 000003ad

sec "RELATED CONTROLLER NODES"
find "$BASE" -type d \( \
    -name '*rpmh-regulator*' -o \
    -name '*gcc*' -o \
    -name '*clock*' -o \
    -name '*interconnect*' -o \
    -name '*smmu*' -o \
    -name '*pinctrl*' \
    \) 2>/dev/null | head -n 200 | while read -r d; do
        echo "--- $d ---"
        for f in name compatible regulator-name clock-output-names; do
            if [ -f "$d/$f" ]; then
                echo -n "$f: "
                tr '\000' ' ' < "$d/$f" 2>/dev/null
                echo
            fi
        done
done

sec "SAFETY"
echo "READ-ONLY Device Tree phandle resolution only"
echo "No block contents, flash, erase, format, repartition, slot, AVB, or firmware operation performed."
EOF

chmod 700 "$TMP"

echo "===== LOCAL SCRIPT SYNTAX CHECK ====="
bash -n "$TMP"

if ! "${ADB_CMD[@]}" push "$TMP" /data/local/tmp/g2-phandle-resolution.sh; then
    echo "ERROR: adb push failed"
    rm -f "$TMP"
    exit 1
fi

if ! "${ADB_CMD[@]}" shell sh /data/local/tmp/g2-phandle-resolution.sh "$REMOTE"; then
    echo "ERROR: G2 read-only audit failed"
    "${ADB_CMD[@]}" shell rm -f /data/local/tmp/g2-phandle-resolution.sh "$REMOTE" || true
    rm -f "$TMP"
    exit 1
fi

mkdir -p "$REPO/dumps/g2"
if ! "${ADB_CMD[@]}" pull "$REMOTE" "$OUT"; then
    echo "ERROR: adb pull failed"
    "${ADB_CMD[@]}" shell rm -f /data/local/tmp/g2-phandle-resolution.sh "$REMOTE" || true
    rm -f "$TMP"
    exit 1
fi

"${ADB_CMD[@]}" shell rm -f /data/local/tmp/g2-phandle-resolution.sh "$REMOTE" || true
rm -f "$TMP"

git add "$OUT" scripts/run-g2-sdhci-phandle-resolution-readonly.sh
git commit -m "data: save G2 SDHCI phandle resolution" || exit 1
git push origin main || exit 1

echo "DONE: $OUT"
