# DTS wiring — PMXR2230 regulators + SDCC2 (microSD) — 2026-09-29

Second DTS-growth step: wire the external microSD path end-to-end into
`dts/cliffs.dtsi`, on top of the gcc/tlmm/icc providers added earlier. This is
the Tier 2 storage goal — a complete, resolvable SDCC2 node with every
dependency present. All values come from the archived G2 device tree +
the prior SDCC2 characterisation (`dts/g2-sdhci-upstream-candidate.dtsi`).

## Nodes added

### PMXR2230 regulators (`regulators-0`, child of `apps_rsc`)
The SD rails, RPMh-managed on SPMI PMIC id **"b"** (PMXR2230):

| vreg | LDO | min–max (from G2 DT) | use |
|---|---|---|---|
| `vreg_l13b` | ldo13 | 2.70–3.30 V | SDCC2 `vmmc` (card power) |
| `vreg_l23b` | ldo23 | 1.65–3.544 V | SDCC2 `vqmmc` (I/O, 1.8/2.96 switch) |

Only the two SD rails are described; the rest of the PMIC's ~70 LDOs get added as
their consumers are wired. **Runtime dependency:** the node uses
`compatible = "qcom,pmxr2230-rpmh-regulators"`. If the target kernel's
`drivers/regulator/qcom-rpmh-regulator.c` has no PMXR2230 entry, that is a small
addition (a `pmic5_ldo`/`pmic5_pldo` table + an `of_device_id` line) — the
hardware is a standard pmic5 VRM (`qcom,rpmh-vrm-regulator`, `pmic5-ldo` in the
downstream DT). Without it, `sdhc_2` probe defers (no vmmc/vqmmc) and SD won't
mount. This is the one non-DTS gap on the SD path.

### apps_smmu (`iommu@15000000`)
Generic mainline `arm,mmu-500` (compatible `qcom,sm8635-smmu-500`,
`qcom,smmu-500`, `arm,mmu-500`) — no driver port needed. reg
`0x15000000+0x100000`, `#iommu-cells = <2>`, `#global-interrupts = <1>`,
`dma-coherent`, 97 interrupts (1 global SPI 0x41 + 96 context, transcribed from
the G2 DT). The downstream-only `qcom,actlr` / `qcom,handoff-smrs` /
`qcom,use-3-lvl-tables` props are dropped. Needed so SDCC2 (and later USB/UFS)
DMA can translate.

### SDCC2 (`mmc@8804000`, status = "okay")
Binds the generic `sdhci-msm` driver via the `qcom,sdhci-msm-v5` fallback (no
driver port). Fully wired:

| property | value | source |
|---|---|---|
| reg | `0x8804000 + 0x1000` | G2 DT |
| interrupts | SPI 207 (hc_irq), 223 (pwr_irq) | G2 DT |
| clocks | `<&gcc GCC_SDCC2_AHB_CLK>` (iface), `<&gcc GCC_SDCC2_APPS_CLK>` (core) | gcc-sm8635 (108/109) |
| resets | `<&gcc GCC_SDCC2_BCR>` | gcc (17) |
| interconnects | `<&aggre2_noc MASTER_SDCC_2 &mc_virt SLAVE_EBI1>`, `<&gem_noc MASTER_APPSS_PROC &cnoc_cfg SLAVE_SDCC_2>` | icc-sm8635 |
| iommus | `<&apps_smmu 0x140 0x0>` | G2 DT stream 0x140 |
| dll/ddr | `0x0007442c` / `0x80040868` | G2 DT |
| vmmc / vqmmc | `<&vreg_l13b>` / `<&vreg_l23b>` | PMXR2230 |
| pinctrl-0/1 | `<&sdc2_default &sd_cd>` / `<&sdc2_sleep &sd_cd>` | tlmm (below) |
| cd-gpios | `<&tlmm 31 GPIO_ACTIVE_LOW>` | G2 DT |
| bus-width | 4 | G2 DT |

**interconnects use the 1-cell form** (`<&provider ID>`, no TAG cell) to match the
providers' `#interconnect-cells = <1>` — the prior standalone candidate used the
2-cell TAG form, which does not fit our stripped-multi-voter icc driver.

### tlmm pin states (children of `tlmm`)
`sdc2_default` / `sdc2_sleep` (clk 16/2 mA no-pull, cmd+data 10/2 mA pull-up) and
`sd_cd` (gpio31, function gpio, pull-up).

## Verification
- `cpp` + `dtc` compile of `dts/cliffs-g2.dts`: **zero errors, zero warnings**.
- dtb 9.4 KB → **12.5 KB**.
- Decompiled and confirmed **no unresolved phandles**; SDCC2's `clocks`→gcc
  (108/109), `interconnects`→ the four NoC ids (1-cell), `iommus`→apps_smmu SID
  0x140, `vmmc`/`vqmmc`→l13b/l23b, `pinctrl-0`→sdc2_default+sd_cd,
  `cd-gpios`→tlmm 31 active-low all resolve.

## Deferred (not blocking compile; affects runtime)
- ~~**PMXR2230 regulator driver entry** — the one real gap for SD to mount.~~
  **CLOSED 2026-09-29:** added as
  `kernel/sm8635/patches/20-sm8635/drivers/regulator/qcom-rpmh-regulator-add-pmxr2230.patch`
  (see `docs/g2-pmxr2230-regulator-port-notes-20260929.md`).
- **power-domains + OPP** on sdhc_2 (`<&rpmhpd RPMHPD_CX>` + opp-table): omitted
  until rpmhpd is added; sdhci-msm still probes and runs at a default rate.
- The standalone `dts/g2-sdhci-upstream-candidate.dtsi` remains as the research
  artifact; the live, integrated SDCC2 now lives in `cliffs.dtsi`.

## Source of values
`dumps/g2/g2-devicetree-20260914-222623.tar.gz` — `apps-smmu@15000000`,
`rsc@17a00000/drv@2/rpmh-regulator-ldob13|ldob23`, and the SDCC2 params carried
from `dts/g2-sdhci-upstream-candidate.dtsi`.
