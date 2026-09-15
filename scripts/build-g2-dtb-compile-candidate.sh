#!/usr/bin/env bash
#
# Reproducibly build the G2 device trees:
#   qcom/cliffs-g2.dtb                -- Tier 0 minimal board (the boot target)
#   qcom/g2-sdhci-compile-test.dtb    -- SDCC2 candidate on the milos stack
#
# Pass a target name to build just one.
#
# Build-side only. Nothing here touches a G2 device, a microSD card, or any
# Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo partition.
set -euo pipefail

# Pinned so the result is reproducible. Bump deliberately, never silently:
# upstream `milos` values (IRQs, SMMU stream ID, pin map) are exactly what the
# G2 candidate disagrees with, so an unpinned tree changes the comparison.
LINUX_REV="${LINUX_REV:-5225b8eec4c9bb21aecff6295fab6346a3c3738e}"
LINUX_URL="${LINUX_URL:-https://github.com/torvalds/linux.git}"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO/.build}"
SRC="$WORK/linux"
JOBS="${JOBS:-$(nproc)}"

echo "==> repo      : $REPO"
echo "==> workdir   : $WORK"
echo "==> linux rev : $LINUX_REV"

for t in make gcc cpp bison flex bc; do
  command -v "$t" >/dev/null || { echo "ERROR: missing build tool: $t"; exit 1; }
done

mkdir -p "$WORK"
if [ ! -d "$SRC/.git" ]; then
  echo "==> fetching linux at the pinned revision (shallow)"
  git init -q "$SRC"
  git -C "$SRC" remote add origin "$LINUX_URL" 2>/dev/null || true
fi
git -C "$SRC" fetch --depth 1 origin "$LINUX_REV"
git -C "$SRC" checkout -q FETCH_HEAD
echo "==> linux HEAD: $(git -C "$SRC" rev-parse HEAD)"

Q="$SRC/arch/arm64/boot/dts/qcom"

echo "==> installing G2 candidate"
cp "$REPO/dts/g2-sdhci-compile-test.dts" "$Q/g2-sdhci-compile-test.dts"
grep -q 'g2-sdhci-compile-test.dtb' "$Q/Makefile" \
  || echo 'dtb-$(CONFIG_ARCH_QCOM)	+= g2-sdhci-compile-test.dtb' >> "$Q/Makefile"

echo "==> configuring"
make -C "$SRC" ARCH=arm64 defconfig >/dev/null

# Baseline first: if the untouched upstream board DTB does not build, the
# toolchain is at fault and a G2 failure would be misattributed.
echo "==> baseline: qcom/milos-fairphone-fp6.dtb"
make -C "$SRC" ARCH=arm64 -j"$JOBS" qcom/milos-fairphone-fp6.dtb

TARGETS="${1:-cliffs-g2 g2-sdhci-compile-test}"
for t in $TARGETS; do
  echo "==> building qcom/$t.dtb"
  make -C "$SRC" ARCH=arm64 -j"$JOBS" "qcom/$t.dtb"
done

echo
echo "==> results"
( cd "$Q" && for t in milos-fairphone-fp6 $TARGETS; do
    [ -f "$t.dtb" ] && sha256sum "$t.dtb"
  done )
echo
echo "A successful build proves the DTS is syntactically valid and every"
echo "referenced label resolves. It does NOT prove the G2 will boot: see the"
echo "known runtime risks in docs/g2-dtb-compile-result-20260912.md."
