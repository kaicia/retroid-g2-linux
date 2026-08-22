# Retroid Pocket G2 ADB Evidence Audit — 2026-08-22

## Purpose
Audit the previous G2 Linux/SteamOS porting work against the actual ADB-derived evidence already stored under `dumps/g2/`.

## Authoritative G2 identity evidence
The device dumps identify:
- Product: Retroid Pocket G2
- DT model: Qualcomm Technologies, Inc. Cliffs MTP
- DT compatible: `qcom,cliffs-mtp`, `qcom,cliffs`, `qcom,cliffsp-mtp`, `qcom,cliffsp`, `qcom,mtp`
- `ro.boot.hardware.revision`: `Qualcomm G2 Gen 2`
- `ro.boot.product.vendor.sku`: `cliffs`
- Android kernel: `6.1.115-android14-11`
- Device boot storage: `soc/1d84000.ufshc`

## Confirmed G2 SDHCI evidence
Actual DT node:
- `/soc/sdhci@8804000`
- compatible: `qcom,sdhci-msm-v5`
- actual Linux device: `8804000.sdhci`
- actual MMC device: `mmc1:0001`
- actual block device: `mmcblk1`
- address: `0x08804000`
- interrupts: 207 / 223
- clock names: iface/core
- interconnect names: `sdhc-ddr`, `cpu-sdhc`
- OPP table: `sdhc2-opp-table`
- regulators: PMXR2230 L13 and L23
- SMMU: `apps-smmu@15000000`
- pinctrl: `sdc2_on` / `sdc2_off`

## Confirmed G2 pinctrl evidence
`sdc2_on`:
- CLK GPIO62, function `sdc2_clk`, drive strength 16
- CMD GPIO51, function `sdc2_cmd`, pull-up, drive strength 10
- DATA GPIO38/39/48/49, function `sdc2_data`, pull-up, drive strength 10
- SD-CD GPIO31, pull-up, drive strength 2

`sdc2_off` uses GPIO functions and the same physical GPIO set with low drive strength.

## Confirmed G2 power evidence
- `vdd-supply` resolves to `regulator-pmxr2230-l13`
- `vdd-io-supply` resolves to `regulator-pmxr2230-l23`

Do not substitute PM8550/other Qualcomm PMIC regulator IDs without source evidence.

## Confirmed G2 interconnect evidence
The SDHCI interconnect raw tuples are:
`0x1a2 0x2f 0x189 0x200 0x1a3 0x2 0x1a4 0x21e`

Provider nodes resolve to G2 Cliffs interconnect controllers including:
- `cliffs-aggre1_noc`
- `cliffs-mc_virt`
- `cliffs-gem_noc`
- `cliffs-cnoc_cfg`

These G2 values are authoritative for G2. Numeric IDs from RP6/SM8550/SM8650 must not be copied into G2.

## Confirmed G2 OPP evidence
`sdhc2-opp-table` contains at least:
- 100 MHz
- 202 MHz
with corresponding bandwidth values captured in the ADB dump.

## Confirmed G2 SMMU evidence
SDHCI `iommus` points to `apps-smmu@15000000`, identified as the G2 SMMU node. The Linux representation and stream-ID mapping remain to be established from actual compatible Cliffs/Linux source evidence.

## Boot/Android preservation evidence
The device boots Android from internal UFS (`soc/1d84000.ufshc`) and has an A/B boot layout including XBL, ABL, UEFI, boot, init_boot, vendor_boot, dtbo and vbmeta slots. The project requirement remains: do not erase or overwrite internal Android; Linux/SteamOS must be developed for microSD boot.

## Corrections to previous analysis
The following previous reasoning is explicitly invalidated:
1. Treating G2 as SM8550 based on RP6/Odin2 similarity.
2. Treating G2 as SM8650 based on unrelated SM8650 Linux DTS similarity.
3. Using SM8550/SM8650 provider numeric IDs as G2 values.
4. Selecting an Armada SM8650 DTS as the direct G2 base.

The correct workflow is:
G2 ADB evidence -> Cliffs/pineapple source lineage -> actual Linux source support -> provider/driver mapping -> G2 DTS.

## Current status
The G2 ADB evidence extraction itself is considered reliable. The kernel-source mapping phase must be re-audited from the actual Cliffs evidence before any bootable DTS is produced.

## Next required work
1. Identify the actual Cliffs/pineapple source lineage from the stored G2 DT/source audit.
2. Locate matching Cliffs Linux kernel/provider source, prioritizing exact compatible strings and register blocks over commercial Snapdragon names.
3. Compare the exact Cliffs GCC, interconnect, pinctrl, PMXR2230 and SMMU implementations with the G2 DT.
4. Determine the minimum Linux changes required for SDCC2.
5. Only then update the WIP DTS.

No device write/flash operation is authorized by this audit.
