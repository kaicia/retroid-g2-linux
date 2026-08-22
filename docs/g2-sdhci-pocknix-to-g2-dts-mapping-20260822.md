# G2 SDHCI: pocknix downstream mapping

Date: 2026-08-22

## Source baseline

The pocknix SM8550 downstream SDHCI DTSI provides a concrete structural reference for the SDCC2 node. It uses `qcom,sdhci-msm-v5-downstream`, `reg = 0x08804000`, IRQ 207/223, 4-bit bus, `iface/core` clocks, `qcom,dll-hsr-list`, IOMMU, interconnects, msm-bus bandwidth, OPPs, two supplies, pinctrl, card-detect GPIO, reset, and qos child nodes.

## G2 matches

The physical G2 audit independently confirms the same SDHCI base, IRQ pair, bus width, clock names, reset name, DLL HSR list, OPP frequencies, two supplies, pinctrl states, card-detect GPIO, interconnect names, and qos0/qos1 presence.

## G2-specific replacements required

Do not copy RP6/Odin2 numeric/provider values. G2 uses Cliffs providers and PMXR2230 regulators. The G2 interconnect tuple is:

`<0x1a2 0x2f 0x189 0x200 0x1a3 0x2 0x1a4 0x21e>`

G2 card detect is `cliffs-pinctrl` GPIO31 rather than the pocknix PM8550 GPIO. G2 supplies are PMXR2230 LDO13/LDO23 rather than the RP6/Odin2 regulators.

## Strong evidence

The pocknix downstream DTSI uses the same DLL HSR values observed on the physical G2. It also uses the same OPP frequencies (100 MHz and 202 MHz), `qcom,restore-after-cx-collapse`, the same SDHCI address/IRQ pair, and the same named interconnect paths. This makes the downstream SDHCI driver path a strong candidate for G2, but it does not prove the G2 kernel will work until Cliffs provider bindings and PMXR2230 bindings are verified.

## Not yet copied

The following pocknix values remain intentionally unported until G2-specific provider/binding evidence exists:

- RP6/Odin2 GCC clock IDs
- RP6/Odin2 interconnect endpoint macros/numbers
- RP6/Odin2 regulator phandles
- RP6/Odin2 card-detect controller
- RP6/Odin2 IOMMU stream IDs
- pocknix `qcom,msm-bus,vectors-KBps` and `qcom,bus-bw-vectors-bps`
- pocknix `qos0`/`qos1` masks, because G2 masks differ (`0xf8` and `0x07`)

## Next step

Verify the exact kernel source used by the selected ROCKNIX/pocknix build for Cliffs GCC/interconnect/pinctrl and PMXR2230 regulator bindings. Then create a non-bootable G2 SDHCI DTS draft containing only proven G2 values and supported Linux properties.
