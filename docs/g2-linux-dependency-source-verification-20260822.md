# G2 Linux Dependency Source Verification

Date: 2026-08-22

## Scope

Source-level verification of the seven dependency groups identified by the physical G2 SDHCI audit. This is research only; no G2 flashing or boot modification.

## Verified

### 1. Qualcomm SDHCI / SMMU

The G2 uses `qcom,sdhci-msm-v5`. The Linux Qualcomm SDHCI architecture contains Qualcomm SDHCI v5 handling and uses OPP, regulators, interconnects, pinctrl and reset-related resources.

The `qcom,qsmmu-v500` compatible is present in Qualcomm's ARM SMMU driver in Android Qualcomm kernel sources. This establishes that the compatible has an existing Qualcomm driver implementation, but does not yet prove support in the exact upstream kernel branch selected for the G2 port.

### 2. Interconnect architecture

Current upstream Qualcomm interconnect drivers model networks such as `aggre1_noc` and `gem_noc` as explicit interconnect nodes with master/slave links. Current upstream DT bindings also use two-cell interconnect specifiers for Qualcomm RPMh interconnect providers.

However, the G2-specific compatibles:
- `qcom,cliffs-aggre1_noc`
- `qcom,cliffs-mc_virt`
- `qcom,cliffs-gem_noc`
- `qcom,cliffs-cnoc_cfg`

were not established as upstream-compatible strings by this audit. They must be matched against the exact Cliffs Linux tree used by Armada/pocknix or another suitable Qualcomm Linux port before DTS IDs are written.

### 3. Cliffs GCC

The physical G2 DT resolves the SDHCI clock/reset provider to `clock-controller@100000`. A current upstream Qualcomm DTS example uses a chip-specific GCC compatible at the same style of address, but that is not sufficient to infer the G2 GCC compatible or clock IDs. The exact Cliffs GCC driver/source must be located before constructing the SDHCI clock/reset entries.

### 4. PMXR2230 regulators

The physical G2 DT resolves SDHCI VDD and VDD-IO to PMXR2230 LDO13 and LDO23. This audit has not yet established an exact upstream Linux PMXR2230 regulator binding/driver compatible for the selected kernel tree. Do not invent regulator IDs.

### 5. Pin control

The physical G2 DT uses `sdc2_on` and `sdc2_off`. Their actual Linux pinctrl provider and state definitions still need to be copied/matched from the exact Cliffs DTS/source tree.

### 6. OPP

The physical G2 SDHCI node references `sdhc2-opp-table` with `opp-100000000` and `opp-202000000`. Linux's OPP framework is the appropriate mechanism for frequency operating points, and the Qualcomm SDHCI driver uses the OPP rate path. The exact voltage entries and required properties still need to be recovered from the G2 DT or Cliffs Linux DTS before a bootable DTS is attempted.

### 7. DLL-specific configuration

Qualcomm SDHCI v5 has DLL-related handling in the driver. G2-specific properties such as `qcom,dll-hsr-list` and collapse/restore behavior must be recovered from the physical G2 DT and compared against the exact Linux driver version selected for the port.

## Important conclusion

The investigation now separates what is proven from what remains unknown. The G2 hardware relationships are proven by direct device-tree reads. Generic Linux support for the SDHCI/OPP/interconnect concepts is also established. The remaining blocker is not the SD card itself; it is obtaining the exact Cliffs Linux provider definitions and IDs for GCC, interconnect, regulator, pinctrl, SMMU and the SDHCI DLL properties.

Therefore the next action should be a targeted source-tree comparison against the Cliffs Linux DTS/driver sources already identified in this repository and the Armada/pocknix lineage. Only after those exact definitions are found should a static G2 DTS draft be created.

## External references

- Linux Qualcomm SDHCI driver: https://github.com/torvalds/linux/blob/master/drivers/mmc/host/sdhci-msm.c
- Linux Qualcomm interconnect example: https://github.com/torvalds/linux/blob/master/drivers/interconnect/qcom/sm8750.c
- Linux Qualcomm RPMh interconnect binding: https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/interconnect/qcom,x1e80100-rpmh.yaml
- Qualcomm Android kernel SMMU source showing `qcom,qsmmu-v500`: https://android.googlesource.com/kernel/msm/+/refs/heads/android-msm-crosshatch-4.9-pie-qpr2/drivers/iommu/arm-smmu.c
