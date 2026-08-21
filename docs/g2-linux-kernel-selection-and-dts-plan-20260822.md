# G2 Linux kernel selection and DTS validation plan

Date: 2026-08-22

## Current G2 evidence

The Android DT audit on the physical Retroid Pocket G2 identified the SDHCI node as `qcom,sdhci-msm-v5` at `0x08804000`, with 4-bit bus width. The node uses two clocks (`iface`, `core`), one `core_reset`, two named interconnect paths (`sdhc-ddr`, `cpu-sdhc`), VDD/VDD-IO supplies, Apps SMMU, two pinctrl states, and an OPP table. The DT also contains Qualcomm/vendor-specific properties including `qcom,dll-hsr-list`, voltage/current level properties, IOMMU DMA properties, and `qcom,restore-after-cx-collapse`.

## Important constraint

Do not copy Android/vendor properties into a Linux DTS merely because they exist in the Android DT. Each property must be verified against the exact Linux kernel tree and its binding/driver. Unknown vendor properties are to be omitted from the first DTS draft unless the selected Linux driver explicitly consumes them.

## Kernel selection rule

The first DTS draft must target one concrete Linux kernel tree that is already used by the chosen SteamOS/Armada-style porting base, rather than mixing definitions from unrelated Qualcomm generations. Record the exact repository, branch/tag, and commit before writing the DTS.

## Validation order

1. Identify the exact kernel tree used as the G2 Linux base.
2. Verify `sdhci-msm` driver parsing and binding for clocks, reset, regulators, interconnects, OPP, IOMMU and pinctrl.
3. Verify the Cliffs GCC provider and the exact clock/reset IDs corresponding to the G2 phandles.
4. Verify the Cliffs interconnect provider and IDs for the four G2 paths.
5. Verify the PMXR2230 regulator provider and the G2 LDO13/LDO23 supplies.
6. Verify the SMMU compatible and required Linux DT properties.
7. Verify the SDC2 pinctrl states and GPIO configuration.
8. Verify the OPP table representation and frequency values.
9. Verify whether `qcom,dll-hsr-list` is accepted by the selected Linux driver/binding; otherwise omit it from the first draft.
10. Generate a static G2 DTS/DTSI draft only after the above mappings are supported.
11. Run `dtc` and DT schema checks against the selected kernel tree. Do not boot or flash yet.

## First DTS draft policy

The first draft should contain only properties proven to be supported by the selected Linux tree. Android-only properties are tracked separately as TODOs. No partitioning, AVB modification, bootloader modification, UFS write, or SD-card flashing is part of this stage.

## Exit criteria before SD-card test

- Kernel tree and commit recorded.
- All required SDHCI dependencies mapped.
- DTS compiles successfully.
- Relevant DT schema checks pass or every remaining warning is documented with a reason.
- A separate test microSD card is prepared only after static validation.
