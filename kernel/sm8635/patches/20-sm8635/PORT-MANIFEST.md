# SM8635 / Cliffs driver port manifest (patches/20-sm8635/)

The SoC-specific patch stack for `kernel/sm8635/`. Each entry is ported from the
Xiaomi Cliffs GPL source onto the target mainline kernel (see `../../kernel.conf`
for the base version). This is table-translation work — large, mechanical, and it
has to be exactly right — not original driver design.

## Source (GPL-2.0)
| | |
|---|---|
| Repository | `MiCode/Xiaomi_Kernel_OpenSource` |
| Branch | `peridot-u-oss` |
| Pinned commit | `062233df735dd3db2e20aea2f7d3f87c0b1ffde2` |
| Vendor base | Android Common Kernel `6.1.115-android14-11` (msm-6.1) |

The vendor drivers are 6.1-based; porting adapts their **data tables** (clock
trees, pin maps, NoC topology) onto the target mainline driver frameworks. The
G2's own device tree (`dumps/g2/g2-devicetree-20260914-*.tar.gz`) supplies the
board wiring and was cross-checked against these headers three ways
(`docs/g2-cliffs-vendor-source-found-20260914.md`).

## Per-driver status (tiers from g2-cliffs-port-estimate-20260914.md)

| Driver | Source path | Lines | Tier | Status |
|---|---|---|---|---|
| GCC clock | `drivers/clk/qcom/gcc-cliffs.c` | 3207 | 1 | **PORTED** → `drivers/clk/qcom/gcc-sm8635.c` (2833 ln); offline-verified + COMPILE-VERIFIED vs linux 7.1. See `docs/g2-gcc-cliffs-port-notes-20260929.md` |
| TLMM pinctrl | `drivers/pinctrl/qcom/pinctrl-cliffs.c` | 2305 | 1 | **PORTED** → `drivers/pinctrl/qcom/pinctrl-sm8635.c` (2256 ln); offline-verified + COMPILE-VERIFIED vs linux 7.1. See `docs/g2-pinctrl-cliffs-port-notes-20260929.md` |
| Interconnect (NoC) | `drivers/interconnect/qcom/cliffs.c` | 3054 | 2 | **PORTED** → `drivers/interconnect/qcom/icc-sm8635.c` (2363 ln); QoS/multi-voter layer stripped to mainline icc-rpmh, topology kept; offline-verified + COMPILE-VERIFIED vs linux 7.1. See `docs/g2-icc-cliffs-port-notes-20260929.md` |
| PMXR2230 regulators | mainline `drivers/regulator/qcom-rpmh-regulator.c` (add) | +33 | 2 | **ADDED** → `drivers/regulator/qcom-rpmh-regulator-add-pmxr2230.patch` (pmxr2230_vreg_data + of_device_id); `git apply --check` clean + COMPILE-VERIFIED vs linux 7.1. Needed for SDCC2 vmmc/vqmmc. See `docs/g2-pmxr2230-regulator-port-notes-20260929.md` |
| DISP clock | `drivers/clk/qcom/dispcc-cliffs.c` | ~970 | 3 | not started |
| GPU clock | `drivers/clk/qcom/gpucc-cliffs.c` | ~560 | 3 | not started |
| CAM clock | `drivers/clk/qcom/camcc-cliffs.c` | ~2167 | 4 | out of scope (Tier 4) |

### dt-bindings headers (needed by the DTS + the drivers above)
- `include/dt-bindings/clock/qcom,gcc-cliffs.h` (188 lines)
- `include/dt-bindings/interconnect/qcom,cliffs.h`
- `include/dt-bindings/clock/qcom,dispcc-cliffs.h`
- `include/dt-bindings/clock/qcom,gpucc-cliffs.h`

## Tier ordering
- **Tier 0 (DTS only, no driver):** DONE — see `../../dts/README.md`. First
  kernel log; needs none of the drivers above (earlycon writes UART MMIO directly).
- **Tier 1 (kernel stays alive):** GCC + pinctrl (+ PDC/RPMh/cpufreq glue, which
  are upstream drivers needing Cliffs data). ~4500–5000 lines. Start here.
- **Tier 2 (SD works):** interconnect + `arm,mmu-500` (generic) + the SDHCI node
  (already characterised and compiling) + PMXR2230 regulators. ~+2000 lines.
- **Tier 3 (usable):** dispcc + `g1548` DSI panel, gpucc + Adreno + Mesa, USB,
  input, audio, Wi-Fi/BT, thermal.

## Ground rules
- Pin every ported file to the commit above; record upstream mainline diffs.
- Keep patches split by driver so each can be validated independently.
- Do not fetch device trees from the Xiaomi repo (it has none for the G2); the
  archived G2 DT is authoritative for board wiring.
