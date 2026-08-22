# G2 Cliffs Provider Mapping Progress — 2026-08-22

## Scope

Continue source-level verification of the G2 SDHCI dependency graph. No G2 flashing, boot modification, partition modification, or other device write was performed.

## New source evidence

A public Qualcomm/OPPO SM8650 device-tree source mirror contains `kernel_platform/qcom/proprietary/devicetree/qcom/cliffs.dtsi` and explicitly includes:

- `dt-bindings/clock/qcom,gcc-cliffs.h`
- `dt-bindings/interconnect/qcom,cliffs.h`

The Cliffs platform DTS identifies `sdhc_2` as the SD-card slot. This confirms that Cliffs has platform-specific GCC/interconnect bindings rather than reusing another Qualcomm platform's numeric IDs.

A Cliffs board DTS (`cliffs-cdp.dtsi`) defines the SDHCI supply/pinctrl/card-detect relationship as:

- VDD: `L13B`
- VDD-IO: `L23B`
- pinctrl: `sdc2_on`, `sdc2_off`
- card detect: TLMM GPIO31, active-low

These relationships match the corresponding G2 hardware facts already recovered directly from the physical G2 DT: PMXR2230 LDO13/LDO23, `sdc2_on/off`, and GPIO31 active-low.

## pocknix comparison

The pocknix/ROCKNIX downstream SDHCI node for RP6/Odin2 uses the same SDHCI base (`0x08804000`), IRQs 207/223, SDCC2 clocks, SDCC2 reset, OPP rates 100/202 MHz, DLL-HSR support, two interconnect paths, SMMU, regulators, pinctrl and card detect. However, its provider IDs and PMIC/GPIO mappings are SM8550-specific and must not be copied to G2.

## Newly verified Cliffs provider IDs

The public Cliffs GCC binding `qcom,gcc-cliffs.h` gives the following identifiers:

- `GCC_SDCC2_AHB_CLK = 108`
- `GCC_SDCC2_APPS_CLK = 109`
- `GCC_SDCC2_APPS_CLK_SRC = 110`
- `GCC_SDCC2_BCR = 17`

The public Cliffs interconnect binding `qcom,cliffs.h` gives:

- `MASTER_SDCC_2 = 47`
- `SLAVE_SDCC_2 = 542`
- `SLAVE_EBI1 = 512`
- `MASTER_APPSS_PROC = 2`

The Cliffs interconnect driver defines the SDCC2 master as `xm_sdc2`, ID `MASTER_SDCC_2`, with one link into the Cliffs NoC. The Cliffs CNOC configuration master also contains `SLAVE_SDCC_2` among its links. These are source-verified Cliffs IDs, not SM8550/pocknix values.

## Important qualification

These IDs are now **verified as Cliffs platform binding values**, but they are not yet marked as final G2 DTS values. The target Linux kernel tree for the SteamOS/Armada-style port must contain compatible Cliffs GCC/interconnect providers before these identifiers can be used in the first compilable G2 DTS. The G2 hardware phandles must also be reconciled against that target tree.

## Current mapping status

| Dependency | Status |
|---|---|
| SDHCI base/IRQ/bus width | CONFIRMED from G2 |
| Cliffs platform identity | CONFIRMED from public Cliffs DTS |
| Cliffs GCC binding family | CONFIRMED (`gcc-cliffs.h`) |
| Cliffs SDCC2 clock IDs | SOURCE-VERIFIED: AHB 108, APPS 109 |
| Cliffs SDCC2 reset ID | SOURCE-VERIFIED: BCR 17 |
| Cliffs interconnect binding family | CONFIRMED (`qcom,cliffs.h`) |
| Cliffs SDCC2 master/slave IDs | SOURCE-VERIFIED: MASTER_SDCC_2 47, SLAVE_SDCC_2 542 |
| G2 interconnect path phandle mapping | NOT YET FINAL against target Linux tree |
| PMXR2230 LDO13/LDO23 relationship | CONFIRMED from G2 + Cliffs board DTS naming relationship |
| Exact Linux PMXR2230 regulator IDs | NOT YET VERIFIED |
| SDC2 pinctrl state names | CONFIRMED; exact Linux definitions still pending |
| SMMU stream ID | NOT YET VERIFIED against selected Linux tree |
| OPP 100/202 MHz | CONFIRMED from G2 |
| DLL-HSR values | CONFIRMED from G2; Linux driver support still kernel-dependent |

## Decision

Do not create the first compilable G2 DTS yet. The project rule requires the exact target kernel tree and compatible provider implementations before a bootable DTS is drafted.

## Next source task

Select the concrete Linux kernel lineage that will serve as the G2 SteamOS/Armada-style base, then verify that it contains compatible Cliffs GCC/interconnect/pinctrl/PMIC/SMMU support. After that, reconcile the source-verified Cliffs IDs with the G2 Android DT phandles and complete the remaining regulator, pinctrl, and SMMU mappings.
