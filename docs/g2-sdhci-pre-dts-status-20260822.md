# G2 SDHCI pre-DTS status

Date: 2026-08-22

## Status

The physical G2 SDHCI dependency audit is sufficient to describe the hardware-facing structure, but it is not yet sufficient to emit a bootable Linux DTS.

## Confirmed G2 values

- SDHCI node: `soc/sdhci@8804000`
- compatible: `qcom,sdhci-msm-v5`
- bus width: 4
- clocks: `iface`, `core`
- reset: `core_reset`
- interconnect names: `sdhc-ddr`, `cpu-sdhc`
- OPP: 100 MHz and 202 MHz
- vdd: PMXR2230 LDO13
- vdd-io: PMXR2230 LDO23
- IOMMU: `apps-smmu@15000000`
- pinctrl: `sdc2_on`, `sdc2_off`
- card detect raw GPIO tuple: `<0x16c 0x1f 0x1>`

## Current blockers

### 1. GPIO controller

The card-detect tuple is known, but phandle `0x16c` has not yet been mapped to a Linux GPIO controller node. Do not invent a controller label or convert it to a Linux GPIO number until resolved.

### 2. Interconnect endpoints

The four provider phandles have been resolved to G2 DT nodes, but the exact master/slave endpoint IDs and Linux provider definitions still require direct inspection.

### 3. Kernel binding

The pocknix RP6 implementation demonstrates a useful downstream SDHCI path and contains a dedicated downstream driver patch, but its numeric interconnect/regulator/GPIO IDs must not be copied to G2. The exact selected kernel tree and its bindings must be fixed before DTS compilation.

## Decision

Do not create or boot a DTS yet. The next physical-G2 audit should dump the GPIO-controller node for phandle `0x16c` and the complete provider nodes for the four interconnect phandles, including `compatible`, `#interconnect-cells`, node names, and endpoint definitions. After that, compare those structures with the selected pocknix/ROCKNIX kernel bindings and generate a non-bootable first DTS draft.
