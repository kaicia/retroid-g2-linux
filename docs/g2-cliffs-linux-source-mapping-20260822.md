# G2 Cliffs Linux Source Mapping — 2026-08-22

## Source evidence
An exact Cliffs Linux kernel source family was located in `OnePlusOSS/android_kernel_oneplus_sm8650`, commit `e39bf7032e38c547d588372a11a5dd55eb714860`.

This does **not** mean the Retroid G2 should be called a Snapdragon 8 Gen 3 device. The correct project terminology remains `Snapdragon G2 Gen 2 / Cliffs`, with `Cliffs` as the source/platform lineage observed in the G2 DT. The Linux source match is evidence about the hardware implementation family, not a commercial product-name substitution.

## Exact interconnect match
G2 physical DT SDHCI tuples:
`<0x1a2 0x2f 0x189 0x200 0x1a3 0x2 0x1a4 0x21e>`

The Cliffs Linux binding header defines:
- `MASTER_SDCC_2 = 47 (0x2f)`
- `SLAVE_EBI1 = 512 (0x200)`
- `MASTER_APPSS_PROC = 2 (0x2)`
- `SLAVE_SDCC_2 = 542 (0x21e)`

Therefore the four numeric endpoint cells in the G2 SDHCI DT exactly match the Cliffs Linux interconnect definitions. This is now source-supported, not an inference from RP6/SM8550.

## Exact SDCC2 clock/reset match
The Cliffs Linux clock binding defines:
- `GCC_SDCC2_AHB_CLK = 108`
- `GCC_SDCC2_APPS_CLK = 109`
- `GCC_SDCC2_APPS_CLK_SRC = 110`
- `GCC_SDCC2_BCR = 17`

The Cliffs Linux interconnect driver also defines `xm_sdc2` with `MASTER_SDCC_2` and an SDCC2 QoS configuration.

## Binding match
The Cliffs Linux interconnect binding explicitly supports:
- `qcom,cliffs-aggre1_noc`
- `qcom,cliffs-cnoc_cfg`
- `qcom,cliffs-gem_noc`
- `qcom,cliffs-mc_virt`
- and other Cliffs providers
with `#interconnect-cells = <1>`.

These are the same provider compatible families resolved from the physical G2 DT.

## What this proves
The G2 SDCC2 interconnect and GCC dependency data is now strongly matched to an actual Cliffs Linux implementation. This is substantially stronger evidence than comparing G2 with RP6/Odin2.

## What remains unresolved
1. Exact PMXR2230 Linux regulator driver/binding representation for G2 LDO13/LDO23.
2. Exact Cliffs pinctrl Linux DTS/binding representation for `sdc2_on`, `sdc2_off`, and CD GPIO31.
3. Exact G2 apps-SMMU stream-ID representation.
4. Which SDHCI driver path (upstream vs pocknix downstream) is the best match for G2's vendor-specific DLL/HSR/QoS behavior.
5. Whether the chosen Armada kernel already contains the required Cliffs source or needs selected Cliffs drivers/backports.

## Important correction
Previous assumptions that treated G2 as SM8550 because of RP6 similarity, or as a generic SM8650/8 Gen 3 device, are superseded. Use `Snapdragon G2 Gen 2 / Cliffs` for the project device identity and use the exact Cliffs Linux source only as an implementation/source lineage match.

## Safety
No G2 device write, flash, boot-partition modification, or internal Android modification was performed. WIP DTS remains non-bootable until all dependencies are source-verified.
