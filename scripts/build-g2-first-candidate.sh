#!/usr/bin/env bash
# Reproducible build for the first Retroid Pocket G2 kernel/DTS candidate.
#
# Build-side only. Nothing is flashed or written to any device, and no SD
# card image is prepared. Linux revision and all inputs are pinned in
# docs/g2-first-kernel-build-20260827.md.
set -euo pipefail

REV="73e3f0710014fe6d4ed98cfc02292f6121db7558"
WORK="${1:-/tmp/opencode/g2-first-kernel}"
JOBS="${JOBS:-4}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Cloning Linux at ${REV}"
rm -rf "${WORK}/linux"
git clone --filter=blob:none --no-checkout https://github.com/torvalds/linux.git "${WORK}/linux"
git -C "${WORK}/linux" fetch --depth 1 origin "${REV}"
git -C "${WORK}/linux" checkout "${REV}"
git -C "${WORK}/linux" rev-parse HEAD

echo "==> Installing build dependencies"
sudo apt-get update -qq
sudo apt-get install -y -qq bc bison flex libssl-dev libelf-dev device-tree-compiler llvm lld
python3 -m pip install --user --quiet dtschema || true

echo "==> Copying G2 board DTS into the tree"
tee "${WORK}/linux/arch/arm64/boot/dts/qcom/milos-retroid-g2.dts" < "${ROOT}/dts/g2/milos-retroid-g2.dts" > /dev/null

echo "==> Registering G2 DTB target"
sed -i '62a dtb-$(CONFIG_ARCH_QCOM)\t+= milos-retroid-g2.dtb' "${WORK}/linux/arch/arm64/boot/dts/qcom/Makefile"

echo "==> Registering G2 board in the arm/qcom binding"
sed -i 's/              - fairphone,fp6/              - fairphone,fp6\n              - retroid,g2/' "${WORK}/linux/Documentation/devicetree/bindings/arm/qcom.yaml"

echo "==> Configuring (defconfig)"
make -C "${WORK}/linux" ARCH=arm64 LLVM=1 defconfig

echo "==> Building kernel Image"
make -C "${WORK}/linux" ARCH=arm64 LLVM=1 -j"${JOBS}" Image

echo "==> Building baseline and G2 DTBs"
make -C "${WORK}/linux" ARCH=arm64 LLVM=1 -j"${JOBS}" qcom/milos-fairphone-fp6.dtb
make -C "${WORK}/linux" ARCH=arm64 LLVM=1 -j"${JOBS}" qcom/milos-retroid-g2.dtb

echo "==> Artifacts"
sha256sum "${WORK}/linux/arch/arm64/boot/Image" \
          "${WORK}/linux/arch/arm64/boot/dts/qcom/milos-retroid-g2.dtb" \
          "${WORK}/linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb"
