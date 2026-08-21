# G2 SDHCI dependency gap audit

Date: 2026-08-22

## Purpose

Record the remaining physical-G2 evidence needed before drafting a Linux SDHCI DTS. This audit deliberately does not invent values from RP6/QCS8550.

## Confirmed from physical G2 DT

- SDHCI compatible: `qcom,sdhci-msm-v5`
- Base: `0x08804000`
- Bus width: 4
- Interrupts: 207 and 223
- Clock names: `iface`, `core`
- Reset: `core_reset`
- Interconnect names: `sdhc-ddr`, `cpu-sdhc`
- OPP phandle present
- `vdd-supply` and `vdd-io-supply` present
- Apps SMMU phandle present
- `pinctrl-0` and `pinctrl-1` present
- `qcom,dll-hsr-list` present
- `qcom,restore-after-cx-collapse` present

## Remaining gaps

1. Decode `cd-gpios` from the physical G2 DT and identify its GPIO controller and polarity.
2. Dump `qos0` and `qos1` child-node properties completely and determine whether they are consumed by the Linux SDHCI driver or are vendor-only DT data.
3. Locate all SDHCI-related bus bandwidth properties in the G2 DT, including any `qcom,msm-bus-*` properties in the node or related nodes.
4. Resolve the four interconnect phandles to their exact G2 provider nodes and endpoint IDs.
5. Resolve the OPP table and record the raw frequency/voltage values.
6. Resolve the two pinctrl states and their GPIO/pad configuration.
7. Resolve the two regulator phandles to the exact PMXR2230 regulator nodes.
8. Resolve the SMMU phandle and record the required Linux-compatible properties.

## Comparison rule

RP6/pocknix is a reference implementation, not a source of numeric IDs for G2. Only structural similarities may be reused until the corresponding G2 provider/consumer mapping is independently established.

## Exit condition

Do not create a bootable G2 DTS until the remaining gaps are either resolved or explicitly marked as optional/vendor-only by the selected Linux kernel driver and binding.
