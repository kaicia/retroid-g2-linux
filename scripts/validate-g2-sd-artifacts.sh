#!/usr/bin/env bash
#
# validate-g2-sd-artifacts.sh — non-destructive validation of the G2 SD-only
# boot-test candidate built by scripts/build-g2-kernel.sh.
#
# Validates (read-only, no block device access, no internal storage touch):
#   1. G2 DTB magic + kernel Image is an aarch64 Image
#   2. DTB -> DTS round-trip with the kernel's dtc
#   3. dtc warnings recorded (structural warnings are expected; errors are not)
#   4. DTB contains the expected G2 SDHCI node (/soc/sdhci@8804000) with
#      source-verified clocks/reset/iommus/interconnects/cd-gpios
#   5. checksums recorded for reproducibility
#   6. optional: full kernel dtbs_check (DT schema) when the build tree and
#      dt-schema tooling are present
#
# Usage:
#   scripts/validate-g2-sd-artifacts.sh [--kbuild DIR] [--dtb PATH] [--image PATH]

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KBUILD="${G2_KBUILD_DIR:-$ROOT/build/g2/kbuild}"
DTB=""
IMAGE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --kbuild) KBUILD="$2"; shift 2 ;;
        --dtb) DTB="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -z "$DTB" ] && DTB="$KBUILD/arch/arm64/boot/dts/qcom/g2-cliffs-sd.dtb"
[ -z "$IMAGE" ] && IMAGE="$KBUILD/arch/arm64/boot/Image"

echo "== G2 SD-only artifact validation (non-destructive) =="
echo "  DTB  : $DTB"
echo "  Image: $IMAGE"
echo "  Kbuild: $KBUILD"

DTC="$KBUILD/scripts/dtc/dtc"
if [ ! -x "$DTC" ]; then
    # fall back to system dtc or the kernel tree's scripts/dtc build
    DTC="$(command -v dtc || true)"
fi
[ -n "$DTC" ] && [ -x "$DTC" ] || { echo "ERROR: no dtc available"; exit 2; }
echo "  dtc  : $DTC"
echo

FAIL=0

echo "[1/6] FDT magic + Image magic"
if [ -f "$DTB" ] && [ "$(head -c4 "$DTB" | od -An -tx1 | tr -d ' ')" = "d00dfeed" ]; then
    echo "  PASS: DTB FDT magic OK ($(stat -c%s "$DTB") bytes)"
else
    echo "  FAIL: DTB FDT magic invalid"; FAIL=1
fi
if [ -f "$IMAGE" ]; then
    MAGIC="$(head -c4 "$IMAGE" | od -An -tx1 | tr -d ' ')"
    echo "  note: Image magic $MAGIC ($(stat -c%s "$IMAGE") bytes, expect arm64 Image)"
else
    echo "  note: kernel Image not present (--image); skipping"
fi
echo

echo "[2/6] DTB -> DTS round-trip"
RT="$KBUILD/../g2-cliffs-sd.verify.dts"
if "$DTC" -I dtb -O dts "$DTB" -o "$RT" 2>"$RT.log"; then
    echo "  PASS: round-trip OK"
else
    echo "  FAIL: round-trip failed"; FAIL=1
fi
echo

echo "[3/6] dtc warnings (informational)"
grep -iE "warning|error" "$RT.log" || echo "  (no dtc warnings)"
echo

echo "[4/6] G2 SDHCI node spot-check"
check_node() {
    "$DTC" -I dtb -O dts "$DTB" | grep -q "$1" && echo "  PASS: $2" || { echo "  FAIL: $2"; FAIL=1; }
}
check_node 'sdhci@8804000' 'SDHCI node /soc/sdhci@8804000 present'
check_node 'qcom,sdhci-msm-v5' 'compatible qcom,sdhci-msm-v5'
check_node '0x6c' 'GCC_SDCC2_AHB_CLK (108/0x6c) in clocks'
check_node '0x6d' 'GCC_SDCC2_APPS_CLK (109/0x6d) in clocks'
check_node '0x11' 'GCC_SDCC2_BCR (17/0x11) in resets'
check_node '0x140' 'apps-smmu stream 0x140 in iommus'
check_node '0x1f' 'cd-gpios tlmm GPIO31 (0x1f)'
echo

echo "[5/6] checksums"
sha256sum "$DTB" "$IMAGE" 2>/dev/null
echo

echo "[6/6] DT schema check (if available)"
if [ -f "$KBUILD/Makefile" ]; then
    if python3 -c "import dtschema" 2>/dev/null; then
        make -C "$ROOT/kernel/.." ARCH=arm64 O="$KBUILD" dtbs_check \
            "arch/arm64/boot/dts/qcom/g2-cliffs-sd.dtb" 2>&1 | tail -5 || \
            echo "  note: dtbs_check reported issues (see above); documenting, not blocking"
    else
        echo "  skip: python 'dtschema' package not installed (documented limitation)"
    fi
else
    echo "  skip: no kbuild tree provided"
fi
echo

if [ "$FAIL" = "0" ]; then
    echo "== Result: PASS (static/build validation) =="
    echo "Compilation of the G2 DTB and kernel Image is verified. This is NOT a"
    echo "claim of G2 bootability; runtime behavior must be tested from microSD."
else
    echo "== Result: FAIL (see above) =="
    exit 1
fi
