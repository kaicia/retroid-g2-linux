#!/usr/bin/env bash
#
# Standalone G2 kernel build (no holodor checkout needed): linux v7.1 from
# GitHub + kernel/sm8635/patches/20-sm8635/*.patch + our DTS + the full
# kernel/sm8635/config/linux.aarch64.conf. Produces Image and cliffs-g2.dtb.
#
#   OUT/Image, OUT/cliffs-g2.dtb, OUT/config, OUT/kernelrelease
#
# Cross-builds with aarch64-linux-gnu-. Writes files only.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${WORK:-$REPO/.build}"
SRC="${SRC:-$WORK/k71}"
OUT="${OUT:-$WORK/kernel-out}"
TAG="${TAG:-v7.1}"
JOBS="${JOBS:-$(nproc)}"
CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
P="$REPO/kernel/sm8635/patches/20-sm8635"

die(){ echo "ERROR: $*" >&2; exit 1; }
command -v "${CROSS}gcc" >/dev/null || die "need ${CROSS}gcc"

if [ ! -d "$SRC/.git" ]; then
  git init -q "$SRC"
  git -C "$SRC" remote add origin https://github.com/torvalds/linux.git
  git -C "$SRC" fetch -q --depth 1 origin tag "$TAG"
fi
G() { git -C "$SRC" -c user.name="g2 build" -c user.email="g2-build@localhost" "$@"; }
G checkout -q -f "$TAG"
for p in "$P"/0*.patch; do
  if ! G am -q "$p" 2>/dev/null; then
    G am --abort 2>/dev/null || true
    G apply "$p" && G commit -qam "$(basename "$p" .patch)"
  fi
done

Q="$SRC/arch/arm64/boot/dts/qcom"
cp "$REPO/kernel/sm8635/dts/qcom/cliffs.dtsi" "$REPO/kernel/sm8635/dts/qcom/cliffs-g2.dts" "$Q/"
grep -q "cliffs-g2.dtb" "$Q/Makefile" || echo 'dtb-$(CONFIG_ARCH_QCOM) += cliffs-g2.dtb' >> "$Q/Makefile"

sed 's/@DEVICENAME@/g2/g' "$REPO/kernel/sm8635/config/linux.aarch64.conf" > "$SRC/.config"
make -s -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig
make -s -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" -j"$JOBS" Image qcom/cliffs-g2.dtb

mkdir -p "$OUT"
cp "$SRC/arch/arm64/boot/Image" "$OUT/Image"
cp "$Q/cliffs-g2.dtb" "$OUT/cliffs-g2.dtb"
cp "$SRC/.config" "$OUT/config"
make -s -C "$SRC" ARCH=arm64 CROSS_COMPILE="$CROSS" kernelrelease > "$OUT/kernelrelease"
echo "kernel $(cat "$OUT/kernelrelease"): $OUT/Image ($(stat -c %s "$OUT/Image") B), $OUT/cliffs-g2.dtb"
