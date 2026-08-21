# G2 SDHCI DTS preflight mapping

Date: 2026-08-22

## Physical G2 evidence

From `dumps/g2/g2-sdhci-dependency-resolution-20260822-005942.txt`:

- `cd-gpios` raw: `<0x16c 0x1f 0x1>`; controller identity is not yet independently resolved.
- debounce: `1500 ms`.
- interconnect phandles: `0x1a2`, `0x189`, `0x1a3`, `0x1a4`.
- resolved providers: `interconnect@16E0000`, `interconnect@1`, `interconnect@24100000`, `interconnect@1600000`.
- OPP table: `sdhc2-opp-table`.
- OPP frequencies: 100 MHz and 202 MHz.
- `vdd-supply`: phandle `0x352` → PMXR2230 LDO13.
- `vdd-io-supply`: phandle `0x359` → PMXR2230 LDO23.
- IOMMU: phandle `0x12a` → `apps-smmu@15000000`.
- pinctrl: `sdc2_on` phandle `0x3ac`; `sdc2_off` phandle `0x3ad`.
- `sdc2_on`: clk gpio62, cmd gpio51, data gpio38/39/48/49, sd-cd gpio31.
- `sdc2_on` drive strengths: clk 16, cmd/data 10, sd-cd 2; pull-ups on cmd/data/sd-cd.
- `sdc2_off`: same pads but GPIO-function/off state, with drive strength 2 and pull-up on cmd/data/sd-cd.
- vendor QoS child nodes: `qos0` mask `0xf8`, vote `0x2c`; `qos1` mask `0x07`, vote `0x2c`.

## Preflight decision

Do not yet emit a bootable DTS. The following remain unresolved:

1. exact Linux representation and binding for the G2 Cliffs interconnect providers/endpoints;
2. exact identity of phandle `0x16c` GPIO controller;
3. whether `qos0/qos1` are consumed by the selected Linux SDHCI implementation;
4. exact Linux SMMU binding requirements for the G2 instance;
5. exact PMXR2230 regulator binding and supply names in the selected kernel tree.

## Safe candidate properties

The first DTS draft can structurally use only values already proven by G2 and only after matching them to the selected kernel binding: compatible, reg, bus-width, clocks/clock-names, reset/reset-names, OPP, supplies, IOMMU, pinctrl names/states, and card-detect GPIO.

## Reference rule

RP6/pocknix DTS is a structural reference only. Numeric Cliffs provider IDs, interconnect endpoints, regulator IDs, and GPIO-controller phandles must not be copied to G2 without independent G2 resolution.

## Next investigation

Resolve the G2 GPIO controller and the four interconnect endpoint tuples directly from the physical DT, then verify them against the exact Linux/pocknix downstream bindings before creating the first DTS file.
