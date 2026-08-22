# G2 downstream SDHCI property matrix

Date: 2026-08-22

## Source basis

The pocknix fixed kernel tree contains `qcs8550-ayn-odin2-sd.dtsi`, which explicitly selects `qcom,sdhci-msm-v5-downstream` and documents that the downstream binding uses `msm-bus` scaling and `dll-hsr-list`. The RP6 uses the same SD wiring class.

## G2 vs pocknix downstream

| Property | G2 physical DT | pocknix downstream | Decision |
|---|---|---|---|
| compatible | `qcom,sdhci-msm-v5` | `qcom,sdhci-msm-v5-downstream` | Use downstream only after driver patch is present |
| reg | `0x08804000` | `0x08804000` | Reuse G2 value |
| IRQs | 207, 223 | 207, 223 | Reuse G2 values |
| bus-width | 4 | 4 | Reuse |
| clocks | iface/core | iface/core | Reuse names; provider IDs unresolved |
| reset | core_reset | core_reset | Reuse name; provider ID unresolved |
| DLL HSR | present, same tuple | present, same tuple | Strong candidate |
| restore-after-cx-collapse | present | present | Strong candidate |
| iommus | G2 Apps SMMU phandle/stream data | apps_smmu stream data | G2 stream ID must be resolved for Linux |
| interconnects | 4 one-cell G2 tuples | 4 two-cell RPMh providers | G2 Linux provider mapping required |
| msm-bus | G2 Android DT contains vendor QoS/bus data; exact vectors need source audit | explicit `qcom,msm-bus,*` vectors | Must extract exact G2 vectors before copying pocknix values |
| OPP | 100/202 MHz | 100/202 MHz | Strong structural match; preserve G2 values |
| vdd | PMXR2230 LDO13 | PM8550 L9B | Must use G2 regulator binding |
| vdd-io | PMXR2230 LDO23 | PM8550 L8B | Must use G2 regulator binding |
| pinctrl | G2 `sdc2_on/off` | RP6/Odin2 states | Translate from G2 Cliffs pinctrl |
| cd-gpios | G2 Cliffs pinctrl GPIO31 | PM8550 GPIO12 active-low | Must use G2 GPIO31/controller |
| qos0/qos1 | mask `f8/07`, vote `2c` | mask `f0/0f`, vote `2c` | Preserve G2 values if driver consumes them |

## Important correction

The pocknix SD DTSI is not a drop-in template for G2. Its interconnect, regulator, GPIO, IOMMU and msm-bus values are board/SoC-specific. The strongest reusable elements are the downstream driver binding, the SDHCI register/IRQ structure, the DLL HSR property, OPP structure, and overall property organization.

## Next gate

Before making the WIP file compile, resolve the exact G2 Linux provider labels/IDs for GCC, interconnect, regulator, SMMU and pinctrl. Then add only properties proven to be consumed by the selected downstream driver.
