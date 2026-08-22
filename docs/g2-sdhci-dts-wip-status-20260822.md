# G2 SDHCI WIP DTS status

Date: 2026-08-22

## What was created

`dts/g2-sdhci-wip.dtsi` is a NON-BOOT hardware mapping skeleton. It records values directly established from the physical Retroid Pocket G2 Android Device Tree while leaving unresolved Linux-provider references commented out.

## Included hardware-derived values

- `qcom,sdhci-msm-v5`
- base `0x08804000`
- interrupts 207 and 223
- bus width 4
- clock names `iface`, `core`
- reset name `core_reset`
- `qcom,restore-after-cx-collapse`
- G2 DLL HSR list
- interconnect names `sdhc-ddr`, `cpu-sdhc`
- G2 raw interconnect tuples: `(0x1a2,0x2f)`, `(0x189,0x200)`, `(0x1a3,0x2)`, `(0x1a4,0x21e)`
- pinctrl state names `sdc2_on`, `sdc2_off`
- OPP frequencies 100 MHz and 202 MHz are documented in the audit but the provider reference remains unresolved in the WIP skeleton.

## Deliberately blocked fields

- exact Linux GCC clock/reset labels and IDs
- exact Linux Cliffs interconnect provider labels and endpoint IDs
- PMXR2230 regulator Linux labels
- exact Linux SMMU cells/stream IDs
- Linux pinctrl labels and CD GPIO flags
- final OPP provider representation
- downstream-vs-upstream SDHCI compatible selection for the selected kernel

## Safety status

This file is not a bootable DTS and is not claimed to compile. No bootloader, Android partition, AVB metadata, UFS storage, or SD card has been modified by creating this file.

## Next step

Select and fetch the exact ROCKNIX/pocknix kernel source/patch set, then resolve every BLOCKED provider reference against that source. Only after that should this WIP skeleton be converted into a compilable DTS/DTSI.
