# Tier 1 port notes — GCC clock driver (gcc-cliffs → gcc-sm8635) — 2026-09-29

First Tier 1 driver ported: the **GCC (global clock controller)**, the single
largest and most fundamental Cliffs driver — nothing that needs a clock probes
without it. Ported from Xiaomi's downstream msm-6.1 source to the mainline qcom
clk framework.

## Source → output
| | |
|---|---|
| Source | `MiCode/Xiaomi_Kernel_OpenSource` `drivers/clk/qcom/gcc-cliffs.c` |
| Pinned commit | `062233df735dd3db2e20aea2f7d3f87c0b1ffde2` (branch `peridot-u-oss`) |
| Source sha256 | `7d19636bc7e89f4837f5e044436d1bbae854f7ac927289f729867c0290e3e544` |
| Source lines | 3207 |
| Output | `kernel/sm8635/patches/20-sm8635/drivers/clk/qcom/gcc-sm8635.c` (2839 lines) |
| Header (unmodified) | `.../include/dt-bindings/clock/qcom,gcc-cliffs.h` (GPL-2.0, 188 lines, sha256 `34f8d0c0…`) |
| Transform script | `.../port_gcc.py` (reproducible, deterministic) |

The pristine downstream `.c` is **not** committed (it is public at the commit
above); we keep only our derivative + the exact script that produces it.

## What the port removes (downstream-only machinery)

Downstream Qualcomm clk drivers carry a per-clock **voltage-scaling (VDD)** layer
and a couple of vendor `clk_rcg2`/init flags that mainline does not have. All of
it stripped, nothing else touched:

| Removed | Count | Why |
|---|---|---|
| `#include "vdd-level.h"` | 1 | header does not exist in mainline |
| `DEFINE_VDD_REGULATORS(vdd_cx/vdd_mx)` + `gcc_cliffs_regulators[]` | 3 defs | downstream VDD class machinery |
| `.vdd_data = { … }` / `.clkr.vdd_data = { … }` blocks | 36 | per-clock `rate_max`/`vdd_class` tables (brace-matched removal) |
| `.enable_safe_config = true` | 31 | not a field of mainline `struct clk_rcg2` |
| `.flags = HW_CLK_CTRL_MODE` (rcg struct flag) | 31 | not a field of mainline `struct clk_rcg2` |
| `.flags = CLK_DONT_HOLD_STATE` (init flag) | 2 | not a mainline `clk_init_data` flag |
| `.clk_regulators` / `.num_clk_regulators` in `qcom_cc_desc` | 2 | mainline `qcom_cc_desc` has no such members |

Also modernized the include block to the mainline gcc-sm8650.c set
(`mod_devicetable.h` + `platform_device.h`, dropped the deprecated
`of_device.h`), and renamed the compatible to mainline convention
`qcom,cliffs-gcc` → **`qcom,gcc-sm8635`**.

**Kept intact:** every PLL, RCG, branch, mux, divider, freq table, parent map,
the reset map, the DFS table, the always-on register writes in probe, and the 53
legitimate `.flags = CLK_SET_RATE_PARENT` init flags.

## Verification performed (offline)
- **Structural:** brace balance 0, paren balance 0.
- **Counts preserved:** 5 alpha PLLs, 31 RCGs, 91 branches, 136 `clocks[]`
  entries, 28 reset-map entries, 16 DFS entries — identical to source.
- **No residual downstream tokens:** `vdd_data`, `vdd_class`, `vdd-level.h`,
  `DEFINE_VDD_REGULATORS`, `enable_safe_config`, `HW_CLK_CTRL_MODE`,
  `CLK_DONT_HOLD_STATE`, `VDD_NUM`, `clk_regulators`, `qcom,cliffs-gcc` all → 0.
- **All referenced ops/types are mainline symbols:**
  `clk_alpha_pll_fixed_lucid_ole_ops`, `clk_alpha_pll_postdiv_lucid_ole_ops`
  (LUCID_OLE PLLs, present since sm8550), `clk_branch2_ops`,
  `clk_branch2_aon_ops`, `clk_branch2_hw_ctl_ops`, `clk_rcg2_ops`,
  `clk_rcg2_floor_ops`, `clk_regmap_div_ro_ops`, `clk_regmap_mux_closest_ops`;
  halt checks `BRANCH_HALT{,_DELAY,_SKIP,_VOTED}`.
- **No dangling table references:** every `gcc_parent_map_*`,
  `gcc_parent_data_*`, `ftbl_*` used is defined in the file.
- **Header coverage:** every real `GCC_*` clock/reset ID the driver uses is
  defined in `qcom,gcc-cliffs.h`.

**Not yet done (needs a real kernel tree):** compile against mainline 7.1.2. The
port targets that framework but has not been built; that is the next validation
step (below). Also unverified: exact register offsets against Cliffs silicon —
these are trusted from the vendor source, which was cross-checked against the
G2's own device tree three ways (`g2-cliffs-vendor-source-found-20260914.md`).

## Integration TODO (at holodor `make kernel` time)

1. **Kconfig** — add to `drivers/clk/qcom/Kconfig`:
   ```
   config SM_GCC_8635
   	tristate "SM8635 Global Clock Controller"
   	depends on ARM64 || COMPILE_TEST
   	select QCOM_GDSC
   	help
   	  Support for the global clock controller on SM8635 (Cliffs) devices.
   	  Say Y if you want to use peripheral devices such as UART, SPI, I2C,
   	  USB, UFS, SD/eMMC, PCIe, etc.
   ```
2. **Makefile** — add to `drivers/clk/qcom/Makefile`:
   ```
   obj-$(CONFIG_SM_GCC_8635) += gcc-sm8635.o
   ```
3. **defconfig** — set `CONFIG_SM_GCC_8635=y` in `kernel/sm8635/config/linux.aarch64.conf`.
4. **DTS gcc node** (Tier 1 DTS growth in `dts/cliffs.dtsi`):
   ```
   gcc: clock-controller@100000 {
       compatible = "qcom,gcc-sm8635";
       reg = <0x0 0x00100000 0x0 0x1f4200>;   /* max_register 0x1f41f0 + slack */
       #clock-cells = <1>;
       #reset-cells = <1>;
       #power-domain-cells = <1>;
       clocks = <&rpmhcc RPMH_CXO_CLK>, <&sleep_clk>, /* + pcie/ufs/usb phy clks */ ;
       clock-names = "bi_tcxo", "sleep_clk", /* … match the driver's .fw_name refs */ ;
   };
   ```
   The driver's parents by `.fw_name`: `bi_tcxo`, `sleep_clk`, and the PHY-derived
   `pcie_0_pipe_clk`, `ufs_phy_rx_symbol_0/1_clk`, `ufs_phy_tx_symbol_0_clk`,
   `usb3_phy_wrapper_gcc_usb30_pipe_clk` (the last group only matters once
   PCIe/UFS/USB PHYs are added — Tier 2/3; for Tier 1 bring-up bi_tcxo + sleep_clk
   suffice and unused-parent clocks simply won't rate-set).
5. **Turn into a formal patch** once applied to a checked-out 7.1.2 tree
   (`git add drivers/... include/...; git format-patch`) and drop the `.patch`
   into `patches/20-sm8635/`, replacing the staged source-tree copy. It is staged
   as a source tree now because generating a clean apply-patch needs the target
   kernel's exact Kconfig/Makefile context lines, which we get at integration.

## Reproduce
```
curl -fsSL https://raw.githubusercontent.com/MiCode/Xiaomi_Kernel_OpenSource/\
062233df735dd3db2e20aea2f7d3f87c0b1ffde2/drivers/clk/qcom/gcc-cliffs.c -o gcc-cliffs.c
python3 kernel/sm8635/patches/20-sm8635/port_gcc.py     # -> gcc-sm8635.c
```

## Next Tier 1 item
`pinctrl-cliffs.c` (2305 lines) → `pinctrl-sm8635.c`. Same shape of port (strip
downstream extras, keep the pin/function tables). Then the SDCC2 + regulator work
for Tier 2 storage.
