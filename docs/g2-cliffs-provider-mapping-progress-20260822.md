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

## Current mapping status

| Dependency | Status |
|---|---|
| SDHCI base/IRQ/bus width | CONFIRMED from G2 |
| Cliffs platform identity | CONFIRMED from public Cliffs DTS |
| Cliffs GCC binding family | CONFIRMED (`gcc-cliffs.h`) |
| Exact SDCC2 GCC numeric IDs | NOT YET VERIFIED |
| Cliffs interconnect binding family | CONFIRMED (`qcom,cliffs.h`) |
| Exact G2 interconnect numeric IDs | NOT YET VERIFIED |
| PMXR2230 LDO13/LDO23 relationship | CONFIRMED from G2 + Cliffs board DTS naming relationship |
| Exact Linux PMXR2230 regulator IDs | NOT YET VERIFIED |
| SDC2 pinctrl state names | CONFIRMED; exact Linux definitions still pending |
| SMMU stream ID | NOT YET VERIFIED against selected Linux tree |
| OPP 100/202 MHz | CONFIRMED from G2 |
| DLL-HSR values | CONFIRMED from G2; Linux driver support still kernel-dependent |

## Decision

Do not create the first compilable G2 DTS yet. The project rule requires exact provider IDs and the exact target kernel tree before a bootable DTS is drafted.

## Next source task

Obtain the actual Cliffs GCC/interconnect binding definitions and the matching Linux driver/DTS implementation from the selected kernel lineage. If the pocknix repository does not contain Cliffs provider sources, use the public Cliffs source only as a source location/reference and do not infer numeric IDs from SM8550/Kalama.
