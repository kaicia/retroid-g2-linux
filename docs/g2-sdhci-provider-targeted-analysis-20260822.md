# G2 SDHCI provider targeted analysis

Date: 2026-08-22

## Confirmed from physical G2

The targeted read-only audit resolved the SDHCI card-detect GPIO controller and all four interconnect provider phandles.

### Card detect GPIO

- SDHCI `cd-gpios`: phandle `0x16c`, GPIO `31`, flags `1`.
- phandle `0x16c` resolves to `/soc/pinctrl@f000000`.
- controller compatible: `qcom,cliffs-pinctrl`.
- `#gpio-cells = <2>`.
- `gpio-controller` is present.

Therefore the G2 CD GPIO is now fully identified at the physical-DT level.

### Interconnect providers

- `0x1a2` → `/soc/interconnect@16E0000`, compatible `qcom,cliffs-aggre1_noc`, `#interconnect-cells = <1>`.
- `0x189` → `/soc/interconnect@1`, compatible `qcom,cliffs-mc_virt`, `#interconnect-cells = <1>`.
- `0x1a3` → `/soc/interconnect@24100000`, compatible `qcom,cliffs-gem_noc`, `#interconnect-cells = <1>`.
- `0x1a4` → `/soc/interconnect@1600000`, compatible `qcom,cliffs-cnoc_cfg`, `#interconnect-cells = <1>`.

### SDHCI interconnect tuples

The raw SDHCI property is:

`<0x1a2 0x2f 0x189 0x200 0x1a3 0x2 0x1a4 0x21e>`

with names `sdhc-ddr` and `cpu-sdhc`.

The four provider endpoint cells are therefore physically confirmed as `0x2f`, `0x200`, `0x2`, and `0x21e`, in the DT tuple order shown above.

## What is still not proven

The audit does not by itself prove the semantic role of each endpoint cell (master vs slave) or whether the selected Linux interconnect driver uses exactly these numeric IDs. Do not translate them into Linux macros/labels until the selected kernel's Cliffs interconnect provider definitions are inspected.

## DTS readiness

The physical G2 side of the GPIO and interconnect mapping is now complete. The next step is source-level kernel binding/provider verification. After that, a first non-bootable G2 SDHCI DTS draft can be generated and compiled/schema-checked.

No SD-card write or boot test is part of this step.
