# G2 / pocknix source baseline

Date: 2026-08-22

## Purpose

Record the exact pocknix-os source baseline inspected for the current Phase 2 Linux-provider mapping work. This is research only. No G2 bootloader, internal storage, Android partition, or firmware was modified.

## Exact pocknix source baseline inspected

Repository: `shuuri-labs/pocknix-os`

Revision inspected: `3592553f79d737b9c9e4781dbeb5bce97b7be893`

Relevant files:

- `kernel/sm8550/kernel.conf`
- `kernel/sm8550/dts/qcom/qcs8550-ayn-odin2-sd.dtsi`
- `kernel/sm8550/dts/qcom/qcs8550-retroidpocket-rp6.dts`
- `kernel/sm8550/patches/20-sm8550/0210-mmc-add-qcom-downstream-sdhci-msm-driver.patch`
- `scripts/build-kernel.sh`

## Kernel baseline

pocknix SM8550 is currently pinned to Linux `7.1.5`, with the SHA256 recorded in `kernel/sm8550/kernel.conf`. The build applies the SM8550 patch stack and then builds the SoC DTS files.

The downstream SDHCI implementation is explicitly enabled by the pocknix build configuration and is separate from the normal `MMC_SDHCI_MSM` driver. The patch adds `MMC_SDHCI_MSM_DOWNSTREAM` and builds `sdhci-msm-downstream.o`.

## SDHCI downstream structure confirmed

The Odin 2 SD DTSI uses:

- compatible: `qcom,sdhci-msm-v5-downstream`
- register base: `0x08804000`
- IRQs: 207 and 223
- 4-bit bus
- clock names: `iface`, `core`
- reset: `core_reset`
- `qcom,restore-after-cx-collapse`
- `qcom,dll-hsr-list`
- IOMMU
- two interconnect paths named `sdhc-ddr` and `cpu-sdhc`
- msm-bus bandwidth vectors
- OPP table at 100 MHz and 202 MHz
- `vdd-supply` and `vdd-io-supply`
- pinctrl default/sleep states
- card-detect GPIO
- qos0/qos1 child nodes

This closely matches the physical G2 SDHCI audit already stored in this repository.

## Important G2 comparison

The structural match is strong enough to keep the downstream SDHCI driver as the primary candidate for the G2 investigation.

However, the pocknix numeric/provider values are NOT portable to G2:

- pocknix uses SM8550 GCC IDs; G2 has a different Cliffs clock provider.
- pocknix uses SM8550 interconnect providers; G2 resolves to Cliffs providers.
- pocknix uses PM8550 regulator/GPIO providers; G2 resolves to PMXR2230 regulators and Cliffs pinctrl.
- pocknix IOMMU stream IDs are board/SoC-specific and must not be copied.
- pocknix QoS masks are `0xf0`/`0x0f`; the physical G2 audit found `0xf8`/`0x07`.

## Driver implications

The downstream driver source includes dependencies for OPP, interconnect, regulators, pinctrl and reset. Therefore the G2 DTS cannot be made bootable by simply changing the SDHCI compatible and copying the RP6 node. Every provider reference must resolve in the selected kernel tree.

## Current blocker

The remaining blocker is the exact Linux provider implementation for the G2 Cliffs platform:

1. Cliffs GCC clock/reset driver and exact SDCC2 IDs
2. Cliffs interconnect providers and exact endpoint IDs
3. PMXR2230 regulator driver/binding and Linux regulator labels
4. Cliffs pinctrl Linux state labels and card-detect GPIO representation
5. G2 SMMU stream/cell mapping
6. exact downstream driver version/patch compatibility with the selected G2 kernel
7. exact Linux representation of G2 OPP and DLL properties

## Decision

Do not convert `dts/g2-sdhci-wip.dtsi` into a bootable DTS yet. First resolve the provider definitions against an actual Linux source tree. Only source-supported labels, IDs and properties may be introduced.

## Next action

Locate the closest Linux/Qualcomm kernel source containing the G2 Cliffs provider implementations, then map the physical G2 Device Tree phandles to Linux DTS labels. After the provider map is complete, update the WIP DTS and run static compilation/schema validation before any boot experiment.
