# G2 SDHCI Linux provider mapping

Date: 2026-08-27

## Scope

This document records the provider mappings established from the SM7635/Milos Linux Device Tree and driver sources, compared against the physical Retroid Pocket G2 Android DT already captured in this repository.

No G2 bootloader, internal storage, Android partition, or firmware was modified.

## 1. Platform identity

The physical G2 DT uses Qualcomm Cliffs providers. The Linux upstream work for the same platform is published under SM7635/Milos. The SM7635 Linux Device Tree defines an SDCC2 controller at `0x08804000`, an `apps_smmu` at `0x15000000`, Cliffs/SM7635 interconnect providers, and the SM7635 GCC clock/reset controller.

## 2. GCC clock/reset mapping

The SM7635 GCC binding defines:

- `GCC_SDCC2_AHB_CLK` = clock ID 121
- `GCC_SDCC2_APPS_CLK` = clock ID 122
- `GCC_SDCC2_APPS_CLK_SRC` = clock ID 123
- `GCC_SDCC2_BCR` = reset ID 20

The corresponding SM7635 GCC driver registers the SDCC2 clocks and reset. The SDCC2 applications-clock source explicitly supports 100 MHz and 202 MHz rates, matching the two G2 hardware-derived OPP frequencies already stored in this repository.

Therefore the source-supported Linux representation for the G2 SDHCI clock/reset pair is:

```dts
clocks = <&gcc GCC_SDCC2_AHB_CLK>,
         <&gcc GCC_SDCC2_APPS_CLK>;
clock-names = "iface", "core";
resets = <&gcc GCC_SDCC2_BCR>;
reset-names = "core_reset";
```

The downstream pocknix driver remains a separate compatibility decision; these labels belong to the SM7635 GCC provider and are not copied from SM8550.

## 3. Interconnect mapping

The SM7635 interconnect driver exposes these providers:

- `qcom,sm7635-aggre1-noc`
- `qcom,sm7635-aggre2-noc`
- `qcom,sm7635-mc-virt`
- `qcom,sm7635-gem-noc`
- `qcom,sm7635-cnoc-cfg`

The provider phandles already resolved from the physical G2 DT map as follows:

| G2 physical phandle | Physical provider | Linux provider label | G2 SD path role |
|---|---|---|---|
| `0x1a2` | `qcom,cliffs-aggre1_noc` | `&aggre1_noc` | not used by the captured SDCC2 master path |
| `0x189` | `qcom,cliffs-mc_virt` | `&mc_virt` | SDCC2 destination memory side |
| `0x1a3` | `qcom,cliffs-gem_noc` | `&gem_noc` | CPU/system side source |
| `0x1a4` | `qcom,cliffs-cnoc_cfg` | `&cnoc_cfg` | SDCC2 configuration slave |

The SM7635 interconnect binding/ID definitions establish:

- `MASTER_SDCC_2` = 8 in the aggre2 NoC provider
- `SLAVE_EBI1` = 1 in the `mc-virt` provider
- `MASTER_APPSS_PROC` = 2 in the gem NoC provider
- `SLAVE_SDCC_2` = 20 in the cnoc-cfg provider

This gives the source-supported mainline-style mapping for the two SDCC2 interconnect paths:

```dts
interconnects = <&aggre2_noc MASTER_SDCC_2 QCOM_ICC_TAG_ALWAYS
                 &mc_virt SLAVE_EBI1 QCOM_ICC_TAG_ALWAYS>,
                <&gem_noc MASTER_APPSS_PROC QCOM_ICC_TAG_ACTIVE_ONLY
                 &cnoc_cfg SLAVE_SDCC_2 QCOM_ICC_TAG_ACTIVE_ONLY>;
interconnect-names = "sdhc-ddr", "cpu-sdhc";
```

For the pocknix downstream SDHCI binding, the same topology is represented with the endpoint IDs and zero tags used by that downstream DTS style.

## 4. SMMU mapping

The SM7635 Linux Device Tree defines an `apps_smmu` at `0x15000000` with two IOMMU cells, and the upstream SDCC2 node uses:

```dts
iommus = <&apps_smmu 0x540 0>;
```

The physical G2 audit already identified `apps-smmu@15000000`, so the Linux provider label and the two-cell stream mapping are source-supported.

## 5. PMXR2230 / PM7550 regulator mapping

Linux upstream work first documented the PMXR2230 device and the Milos/SM7635 device tree exposes the corresponding regulator definitions. The SM7635/Fairphone SD card node uses:

```dts
vmmc-supply = <&vreg_l13b>;
vqmmc-supply = <&vreg_l23b>;
```

These correspond to the physical G2 audit's PMXR2230 LDO13 and LDO23 rails.

The downstream driver may use the legacy `vdd-supply` / `vdd-io-supply` property names instead. The electrical provider mapping is the important part and must match the selected driver binding.

## 6. Cliffs/SM7635 pinctrl mapping

The SM7635 Linux device tree exposes the SDCC2 pin states through the top-level `&tlmm` controller and uses labels such as `sdc2_default` and `sdc2_sleep`.

The physical G2 DT identifies its separate card-detect GPIO as GPIO 31 on the Cliffs pinctrl controller. The raw GPIO tuple is `<0x16c 0x1f 0x1>`; under the standard Linux GPIO flag encoding, the final cell `0x1` represents `GPIO_ACTIVE_LOW`.

Therefore the final G2 DTS must preserve GPIO 31 and its active-low polarity. The Fairphone card-detect GPIO number must not be copied because it is board-specific.

## 7. OPP and DLL compatibility

The upstream SM7635/Milos SDCC2 node defines 100 MHz and 202 MHz operating points and uses:

```dts
qcom,dll-config = <0x0007442c>;
qcom,ddr-config = <0x80040868>;
```

The physical G2 audit captured a vendor DLL HSR list containing the same key values. The pocknix downstream driver expects a `qcom,dll-hsr-list` representation instead of the mainline `dll-config`/`ddr-config` pair, so conversion must follow the actual downstream driver source rather than textual substitution.

## 8. Current provider status

Confirmed source-supported mappings:

1. GCC SDCC2 AHB clock -> `GCC_SDCC2_AHB_CLK` (121)
2. GCC SDCC2 apps/core clock -> `GCC_SDCC2_APPS_CLK` (122)
3. GCC SDCC2 reset -> `GCC_SDCC2_BCR` (20)
4. SDCC2 interconnect topology -> aggre2/mc_virt and gem_noc/cnoc_cfg
5. Interconnect endpoint IDs -> SDCC2 8, EBI1 1, APPSS_PROC 2, SDCC2 slave 20
6. SMMU provider -> `&apps_smmu`, stream tuple `<0x540 0>`
7. SD VDD provider -> `&vreg_l13b`
8. SD VDD-IO provider -> `&vreg_l23b`
9. SM7635 pinctrl provider -> `&tlmm`
10. G2 card-detect GPIO -> GPIO 31, active-low

Still unresolved for a bootable G2 DTS:

- Whether the selected G2 kernel should use the pocknix downstream SDHCI driver or the upstream SM7635/Milos SDHCI driver.
- Exact G2 Linux pinctrl state/label for the card-detect GPIO 31.
- Exact downstream-driver voltage/current property compatibility for the PM7550/PMXR2230 rails.
- Whether the G2 downstream kernel contains the full SM7635 GCC/ICC/pinctrl/SMMU support or needs those drivers imported/backported.
- Final downstream QoS representation. The physical G2 masks are `0xf8` and `0x07`, while the pocknix SM8550 reference uses `0xf0` and `0x0f`; G2 values must remain hardware-derived.

## Next action

Do not mark `dts/g2-sdhci-wip.dtsi` bootable yet. The provider map is sufficiently complete to create source-backed compile candidates, but the exact selected kernel tree must first be assembled/verified with the SM7635 providers and the downstream SDHCI driver. After that, generate non-bootable compile candidates and run `dtc` plus relevant schema checks.

## Source references

- SM7635/Milos GCC, interconnect, SMMU, pinctrl and SDHCI definitions from the Linux kernel.
- PMXR2230/PM7550 regulator definitions and Milos/Fairphone DT.
- Pocknix downstream SDHCI reference: `shuuri-labs/pocknix-os` revision `3592553f79d737b9c9e4781dbeb5bce97b7be893`.
