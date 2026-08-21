# G2 SDHCI Linux driver property audit — 2026-08-22

## Source data
G2 read-only DT dump: `dumps/g2/g2-sdhci-node-complete-20260822-004035.txt`.

The G2 SDHCI node is `qcom,sdhci-msm-v5` and contains `qcom,dll-hsr-list`, `qcom,vdd-current-level`, `qcom,vdd-io-current-level`, `qcom,vdd-voltage-level`, `qcom,vdd-io-voltage-level`, and `qcom,restore-after-cx-collapse`.

## Linux driver comparison

The current upstream Linux `drivers/mmc/host/sdhci-msm.c` contains explicit state and handling for DLL configuration (`dll_config`, `restore_dll_config`, `uses_tassadar_dll`, etc.), voltage/current state, and runtime/power restoration. This establishes that Qualcomm-specific power/DLL behavior is represented in the Linux driver, but it does **not** by itself prove that every Android/vendor DT property above is accepted by upstream Linux DTS.

The G2 dump also shows `qcom,dll-config` is absent while `qcom,dll-hsr-list` is present. Therefore the HSR list must be investigated against the exact Linux version/branch selected for the port before copying it into a Linux DTS.

The upstream driver source is the authoritative source for whether a property is actually parsed. The G2 Android/vendor property names must not be assumed to be upstream bindings merely because the driver has similarly named internal state.

## Preliminary classification

### Directly relevant to Linux SDHCI
- `compatible = qcom,sdhci-msm-v5`
- `clocks` / `clock-names`
- `resets` / `reset-names`
- `interconnects` / `interconnect-names`
- `operating-points-v2`
- `pinctrl-0`, `pinctrl-1`
- `iommus`
- `bus-width`
- regulator supplies, if supported by the selected Linux binding/driver

### Requires exact-driver verification before inclusion
- `qcom,dll-hsr-list`
- `qcom,vdd-current-level`
- `qcom,vdd-io-current-level`
- `qcom,vdd-voltage-level`
- `qcom,vdd-io-voltage-level`
- `qcom,restore-after-cx-collapse`

### Observed absent on G2 SDHCI node
- `qcom,dll-config`
- `qcom,ice`
- `qcom,ice-instance`
- `qcom,core_3_0`
- `qcom,ddr-config`
- `vmmc-supply`
- `vqmmc-supply`
- `max-frequency`
- `non-removable`
- explicit HS200/HS400 capability properties

## Important conclusion

Do not copy Android/vendor-only properties into the first Linux DTS merely because they exist in the G2 DT. The next required step is to identify the exact Linux branch/driver version to be used and search that source tree for each property name and the corresponding binding YAML. Only properties demonstrably consumed by that Linux driver/binding should enter the initial DTS.

## Safety / scope
Read-only source analysis and previously captured G2 Device Tree data only. No storage write, flash, erase, repartition, slot, AVB, or firmware operation was performed.
