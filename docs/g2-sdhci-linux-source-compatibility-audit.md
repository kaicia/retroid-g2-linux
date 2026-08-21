# Retroid Pocket G2 SDHCI Linux Source Compatibility Audit

Date: 2026-08-22

## Scope

This document compares the SDHCI hardware dependencies captured from the physical Retroid Pocket G2 with the current Linux Qualcomm SDHCI driver architecture. No G2 flashing or boot modification is part of this audit.

## G2 facts captured from the device

The G2 Android device-tree audit established:

- SDHCI controller compatible: `qcom,sdhci-msm-v5`
- SDHCI node: `soc/sdhci@8804000`
- Clock/reset provider phandle resolves to `clock-controller@100000`
- VDD resolves to `regulator-pmxr2230-l13`
- VDD-IO resolves to `regulator-pmxr2230-l23`
- IOMMU resolves to `apps-smmu@15000000`, compatible `qcom,qsmmu-v500`
- pinctrl states resolve to `sdc2_on` and `sdc2_off`
- Interconnects resolve to:
  - `interconnect@16E0000` / `qcom,cliffs-aggre1_noc`
  - `interconnect@1` / `qcom,cliffs-mc_virt`
  - `interconnect@24100000` / `qcom,cliffs-gem_noc`
  - `interconnect@1600000` / `qcom,cliffs-cnoc_cfg`
- OPP table resolves to `soc/sdhc2-opp-table`
- OPP entries captured: `opp-100000000` and `opp-202000000`

Source: `dumps/g2/g2-sdhci-interconnect-opp-resolution-20260821-061758.txt` and the earlier SDHCI/phandle audit files in this repository.

## Linux driver evidence

The current upstream Linux `drivers/mmc/host/sdhci-msm.c` includes the regulator, interconnect, OPP, pinctrl, and reset APIs. The driver has an `sdhci_msm_host` structure containing clocks and uses `dev_pm_opp_set_rate()` when changing the SDHCI clock rate. It also contains Qualcomm SDHCI v5-specific register handling and DLL configuration logic.

Therefore the G2 OPP table is directly relevant to the upstream driver's clock-rate path, rather than being merely descriptive hardware data.

Upstream source:
- https://github.com/torvalds/linux/blob/master/drivers/mmc/host/sdhci-msm.c

## Important limitation

The presence of G2 `qcom,cliffs-*` interconnect nodes and `qcom,qsmmu-v500` in the Android DT does NOT by itself prove that the current upstream Linux tree can boot the G2 unchanged.

Before writing a bootable G2 DTS, the following must be verified in the exact Linux tree/branch selected for the port:

1. A matching Cliffs GCC clock/reset provider and clock IDs.
2. Matching Cliffs interconnect provider drivers and binding IDs for `aggre1_noc`, `mc_virt`, `gem_noc`, and `cnoc_cfg`.
3. A matching PMXR2230 regulator driver/binding and the LDO definitions used by the SDHCI node.
4. Matching Qualcomm SMMU support for the G2 `qsmmu-v500` instance.
5. Matching pinctrl definitions for `sdc2_on` / `sdc2_off`.
6. Correct Linux OPP syntax and required regulator/clock relationships for `sdhc2-opp-table`.
7. Any G2-specific SDHCI DLL properties such as `qcom,dll-hsr-list` and restore-after-collapse behavior.

## Current conclusion

The G2 SDHCI hardware description is sufficiently characterized to begin a Linux DTS compatibility audit, but it is NOT yet sufficient to claim a bootable SD-card Linux configuration.

The next step is source-level verification of the seven dependency groups above, followed by construction of a non-booting DTS draft for static validation. Only after that should a separate test SD card be prepared.
