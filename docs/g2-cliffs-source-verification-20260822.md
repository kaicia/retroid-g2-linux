# G2 Cliffs Source Verification — 2026-08-22

## Scope

Continue source-level verification before creating a bootable DTS. No G2 flashing or boot modification was performed.

## Evidence found

A public Qualcomm Android kernel/device-tree source mirror documents a `cliffs.dtsi` alongside other Qualcomm platform DTSI files. The same source family shows the Cliffs platform as a peer platform to Kalama/Holi/Blair. The indexed platform documentation identifies Cliffs-specific infrastructure and shows that Qualcomm's DTS architecture defines platform-specific GCC and interconnect compatibles rather than reusing another SoC's IDs.

The indexed Kalama example is useful only as structural evidence: it shows `mc_virt`, `cnoc_cfg`, and `gem_noc` as distinct interconnect providers and a GCC controller at the conventional `0x100000` base. It must NOT be treated as proof of G2 clock/interconnect IDs because G2 is Cliffs/pineapple.

## G2 facts already captured directly from the physical device

- SDHCI node: `soc/sdhci@8804000`
- compatible: `qcom,sdhci-msm-v5`
- clock/reset provider: `clock-controller@100000`
- VDD: `regulator-pmxr2230-l13`
- VDD-IO: `regulator-pmxr2230-l23`
- IOMMU: `apps-smmu@15000000`, `qcom,qsmmu-v500`
- pinctrl: `sdc2_on`, `sdc2_off`
- interconnects:
  - `interconnect@16E0000` / `qcom,cliffs-aggre1_noc`
  - `interconnect@1` / `qcom,cliffs-mc_virt`
  - `interconnect@24100000` / `qcom,cliffs-gem_noc`
  - `interconnect@1600000` / `qcom,cliffs-cnoc_cfg`
- OPP table: `soc/sdhc2-opp-table`
- OPP rates: `100000000` and `202000000`

## Current status by dependency

| Dependency | Status | Notes |
|---|---|---|
| SDHCI MSM v5 | confirmed | G2 DT compatible captured directly |
| GCC provider | hardware node confirmed; Linux ID mapping pending | Do not invent IDs |
| Cliffs interconnect providers | hardware compatibles confirmed; Linux ID mapping pending | Do not substitute Kalama IDs |
| PMXR2230 LDO13/LDO23 | hardware rails confirmed; Linux regulator IDs pending | Need exact binding/driver source |
| QSMMU v500 | hardware compatible confirmed; exact Linux instance mapping pending | Need exact DT/driver evidence |
| SDC2 pinctrl | Android states confirmed; Linux pinctrl definitions pending | Need exact source |
| SDHC2 OPP | rates confirmed | Need Linux-required voltage/clock relationships |
| SDHCI DLL properties | requires exact G2 DT extraction and Linux-driver comparison | Still pending |

## Important conclusion

The source search confirms that Cliffs has its own platform DTSI and that Qualcomm's DT architecture uses platform-specific provider IDs. This strengthens the decision to derive the G2 Linux DTS from the Cliffs source rather than copying another Qualcomm platform.

It does NOT yet provide enough evidence to claim exact Linux clock/reset/interconnect/regulator IDs for G2. The next task is to obtain the actual Cliffs source files and extract those IDs and the corresponding SDHCI node/property definitions. Only then should a static G2 DTS draft be generated.

## External source used

Indexed public source mirror: OPPO SM8650 kernel/device-tree source documentation, which identifies `kernel_platform/qcom/proprietary/devicetree/qcom/cliffs.dtsi` and documents the Cliffs platform as a distinct Qualcomm platform. This is structural/source-location evidence, not G2-specific ID evidence.
