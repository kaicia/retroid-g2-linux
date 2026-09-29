# Tier 1 port notes — TLMM pinctrl driver (pinctrl-cliffs → pinctrl-sm8635) — 2026-09-29

Second Tier 1 driver: the **TLMM pinctrl/GPIO controller** (pin mux + GPIO). With
GCC (clocks) and this (pins), the SoC's peripherals can be muxed and clocked —
the base for UART, SD, USB, etc.

## Source → output
| | |
|---|---|
| Source | `MiCode/Xiaomi_Kernel_OpenSource` `drivers/pinctrl/qcom/pinctrl-cliffs.c` |
| Pinned commit | `062233df735dd3db2e20aea2f7d3f87c0b1ffde2` (branch `peridot-u-oss`) |
| Source sha256 | `65fdbcfa79d7f29c10b40823656c80baa6c18b1d3497073d2a3c118be51481ea` |
| Source lines | 2305 |
| Output | `kernel/sm8635/patches/20-sm8635/drivers/pinctrl/qcom/pinctrl-sm8635.c` (2268 lines) |
| Transform script | `.../port_pinctrl.py` (deterministic, reproducible) |

This driver is already very close to mainline (standard `msm_pinctrl_soc_data` /
`PINGROUP` / `FUNCTION` structure), so the port is small.

## What the port removes (downstream-only)

| Removed | Why |
|---|---|
| `QUP_I3C()` macro + 5 `QUP_*_MODE_OFFSET` defines + `cliffs_qup_regs[]` (`struct pinctrl_qup`) + `.qup_regs`/`.nqup_regs` soc_data fields | mainline `struct msm_pinctrl_soc_data` has no I3C-QUP register support; these are a downstream addition |
| `cliffs_vm_pinctrl` soc_data + its `qcom,cliffs-vm-pinctrl` of_match entry + `MODULE_SOFTDEP("pre: qcom_tlmm_vm_irqchip")` | the virtual-machine-guest pinctrl variant; not needed for bare-metal G2 and it pulls a downstream-only irqchip module |
| MIUI `.pm = &noirq_msm_pinctrl_dev_pm_ops` | replaced with the mainline `msm_pinctrl_dev_pm_ops` (pinctrl-msm exports this) |

Compatible renamed to mainline convention **`qcom,cliffs-pinctrl` →
`qcom,sm8635-tlmm`** (matches `qcom,sm8550-tlmm` / `qcom,sm8650-tlmm`).

**Kept intact:** all 179 pin descriptors, 180 PINGROUPs (incl. the UFS_RESET
special pin), 252 pin functions, the full `msm_mux_*` enum, egpio support
(`.egpio_func = 11`), and the `cliffs_pdc_map` PDC wakeirq map. Includes left as
the source had them (all mainline-valid: module/of/of_device/platform_device/
pinctrl + pinctrl-msm.h).

## Verification performed (offline)
- Brace balance 0, paren balance 0.
- Counts preserved: 180 PINGROUP, 253 FUNCTION (1 macro def + 252 uses), 179
  PINCTRL_PIN — identical to source.
- Zero residual downstream tokens (`QUP_I3C`, `_MODE_OFFSET`, `pinctrl_qup`,
  `qup_regs`, `cliffs_vm_pinctrl`, `vm-pinctrl`, `qcom_tlmm_vm_irqchip`,
  `noirq_msm_pinctrl_dev_pm_ops`, `MIUI`, `qcom,cliffs-pinctrl` all → 0).
- All framework symbols used are mainline: `msm_pinctrl_probe`,
  `msm_pinctrl_remove`, `msm_pinctrl_dev_pm_ops`, `of_device_get_match_data`.
- No dangling references to the removed `cliffs_qup_regs` / `cliffs_vm_pinctrl`.

**Not yet done:** compile against mainline 7.1.2 (next validation step). Register
offsets trusted from vendor source (cross-checked against the G2 DT, see
`g2-cliffs-vendor-source-found-20260914.md`).

## Integration TODO (at holodor `make kernel` time)
1. `drivers/pinctrl/qcom/Kconfig`:
   ```
   config PINCTRL_SM8635
   	tristate "Qualcomm Technologies Inc SM8635 pin controller driver"
   	depends on ARM64 || COMPILE_TEST
   	depends on PINCTRL_MSM
   	help
   	  This is the pinctrl, pinmux, pinconf and gpiolib driver for the
   	  Qualcomm TLMM block on the SM8635 (Cliffs) platform.
   ```
2. `drivers/pinctrl/qcom/Makefile`: `obj-$(CONFIG_PINCTRL_SM8635) += pinctrl-sm8635.o`
3. defconfig: `CONFIG_PINCTRL_SM8635=y` (and `CONFIG_PINCTRL_MSM=y`).
4. DTS `tlmm` node in `dts/cliffs.dtsi` (Tier 1 growth):
   ```
   tlmm: pinctrl@f100000 {
       compatible = "qcom,sm8635-tlmm";
       reg = <0x0 0x0f100000 0x0 0x300000>;
       interrupts = <GIC_SPI 208 IRQ_TYPE_LEVEL_HIGH>;
       gpio-controller; #gpio-cells = <2>;
       interrupt-controller; #interrupt-cells = <2>;
       gpio-ranges = <&tlmm 0 0 179>;
       wakeup-parent = <&pdc>;   /* for the cliffs_pdc_map wakeirqs */
   };
   ```
   (reg base 0xf100000 = the driver's `REG_BASE 0x100000` at the SoC north tile;
   confirm the tile base + IRQ against the G2 DT before first boot.)
5. Turn into a formal `.patch` once applied to a checked-out 7.1.2 tree.

## Tier 1 status after this
- GCC clock: ported ✓
- TLMM pinctrl: ported ✓
- Remaining Tier 1 glue: PDC/RPMh/cpufreq are upstream drivers needing only
  Cliffs DT data (no C port). Next major item is **Tier 2**: interconnect
  (`cliffs.c` → `icc-sm8635`), then the SDCC2 node + PMXR2230 regulators for
  working SD storage.
