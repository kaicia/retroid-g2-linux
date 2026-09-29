# DTS growth — wiring the gcc/tlmm/icc providers — 2026-09-29

Grew `dts/cliffs.dtsi` from the Tier 0 base (CPUs/GIC/timer/reserved-memory) to
carry the Tier 1/2 provider nodes that bind the three Cliffs drivers ported this
session (`gcc-sm8635.c`, `pinctrl-sm8635.c`, `icc-sm8635.c`). All values are read
from the archived G2 device tree (`dumps/g2/g2-devicetree-20260914-222623.tar.gz`,
a live `/proc/device-tree` dump) — nothing guessed.

## Nodes added

| Node | compatible | key values (from G2 DT) |
|---|---|---|
| `xo_board` (root) | `fixed-clock` | 19.2 MHz — bi_tcxo source for GCC |
| `sleep_clk` (root) | `fixed-clock` | 32 kHz |
| `apps_rsc` (soc) | `qcom,rpmh-rsc` | reg 0x17a00000/…10000/…20000; irq SPI 3/4/5; drv-id 2; tcs-offset 0xd00; tcs-config ACTIVE 3 / SLEEP 2 / WAKE 2 / CONTROL 0 |
| `apps_bcm_voter` (in apps_rsc) | `qcom,bcm-voter` | the single voter all NoCs use |
| `gcc` (soc) | `qcom,gcc-sm8635` | reg 0x100000 + 0x1f4200; clocks bi_tcxo, sleep_clk |
| `tlmm` (soc) | `qcom,sm8635-tlmm` | reg 0xf000000 + 0x1000000; irq SPI 208; gpio-ranges 0..179 |
| 12 physical NoCs (soc) | `qcom,sm8635-<noc>` | aggre1/aggre2/cnoc-cfg/cnoc-main/gem/lpass-ag/lpass-lpiaon/lpass-lpicx/mmss/nsp/pcie-anoc/system, each with its NoC base reg |
| 2 virtual NoCs (root) | `qcom,sm8635-clk-virt`, `qcom,sm8635-mc-virt` | register-less; kept off the soc simple-bus |

Every NoC provider votes through `<&apps_bcm_voter>` and uses
`#interconnect-cells = <1>` (matching the ported icc driver's one-cell node ids;
the downstream multi-voter list was dropped with the stripped QoS layer).

## Wiring decisions (bring-up-minimal, mainline-idiomatic)

- **GCC parents:** the ported driver names 7 parents (bi_tcxo, sleep_clk, and the
  pcie/ufs/usb PHY pipe/symbol clocks). Only `bi_tcxo` (from `xo_board`) and
  `sleep_clk` are wired now; the PHY-derived parents are added with their PHYs
  (Tier 3). GCC still probes — the affected few clocks just don't rate-set. Once
  the rpmh clock driver (`qcom,cliffs-rpmh-clk`) is ported, switch bi_tcxo to
  `<&rpmhcc RPMH_CXO_CLK>` (mainline form).
- **GCC has no `#power-domain-cells`:** the ported driver exposes no GDSCs.
- **TLMM `wakeup-parent` omitted:** the PDC node (0xb220000) isn't added yet;
  GPIO + pin mux work without it, only GPIO-as-wakeup is deferred.
- **apps_rsc:** the generic mainline `qcom,rpmh-rsc` driver (no Cliffs port
  needed). The downstream 5th TCS type (`<4 1>`) is dropped — mainline has only
  ACTIVE/SLEEP/WAKE/CONTROL.
- **Virtual providers at root:** `clk_virt`/`mc_virt` have no MMIO, so placing
  them under the `simple-bus` soc node triggers a dtc `simple_bus_reg` warning;
  moved to root to keep the build warning-clean.

## Verification
- `cpp` + `dtc` compile of `dts/cliffs-g2.dts`: **zero errors, zero warnings**.
- dtb 6.5 KB (Tier 0) → **9.4 KB** with the providers.
- Decompiled and confirmed: all 14 interconnect providers present; every
  `qcom,bcm-voters` resolves to the `apps_bcm_voter` phandle; `tcs-config`,
  gcc `reg`/`clocks`, tlmm `reg`/irq all resolved (no dangling `&` refs).

## Not yet wired (next DTS steps)
- **PMXR2230 regulators** (rpmh-regulator) — needed before consumers can power on.
- **SDCC2 node** — already characterised (IRQs, stream id, pins, OPP, DLL/DDR);
  wire its `clocks = <&gcc GCC_SDCC2_*>`, `pinctrl-0 = <&sdc2_*>`,
  `interconnects = <&aggre2_noc MASTER_SDCC_2 … &mc_virt SLAVE_EBI1 …>`,
  `vmmc/vqmmc-supply` → then SD storage can probe (the Tier 2 goal).
- **QUP/UART** (enable uart5 off `&gcc` + geniqup wrapper), **USB**, **UFS**.
- **PDC** (`interrupt-controller@b220000`) for tlmm/GPIO wakeup, and **rpmhcc**.

## Source of values
`dumps/g2/g2-devicetree-20260914-222623.tar.gz` — nodes `clock-controller@100000`,
`pinctrl@f000000`, `rsc@17a00000` (+ `drv@2`), `interconnect@*`.
