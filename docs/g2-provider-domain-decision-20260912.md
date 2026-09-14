# G2 provider-domain decision — 2026-09-12

Resolves the blocker recorded in `docs/development-workflow.md` §6.1: the
repository carried two incompatible numbering systems for the same hardware and
no rule saying which one a G2 DTS must use.

No G2 device, bootloader, partition or firmware was touched. All G2 values below
are re-derived from the existing read-only dumps in `dumps/g2/`; all upstream
values are read from the Linux source named in §5.

## 1. Decision

**Target the upstream Linux Milos platform. Use upstream symbols and upstream
provider labels exclusively. Never mix the two domains in one DTS.**

The two domains are:

| | Downstream (vendor Android) | Upstream (mainline Linux) |
|---|---|---|
| Platform name | `cliffs` | `milos` |
| Headers | `qcom,gcc-cliffs.h`, `qcom,cliffs.h` | `qcom,milos-gcc.h`, `qcom,milos-rpmh.h` |
| ICC provider driver | `qnoc_cliffs` | `drivers/interconnect/qcom/milos.c` |
| SDHCI compatible | `qcom,sdhci-msm-v5` | `qcom,milos-sdhci`, `qcom,sdhci-msm-v5` |
| Regulator props | `vdd-supply` / `vdd-io-supply` | `vmmc-supply` / `vqmmc-supply` |
| DLL/DDR props | `qcom,dll-hsr-list` (5 words) | `qcom,dll-config` + `qcom,ddr-config` |

A symbol is only meaningful together with the driver that defines it. Pasting a
downstream numeric ID into an upstream DTS silently addresses a different node.

## 2. Why the two ID sets differ (the aggre1/aggre2 question)

The G2 Android DT `interconnects` property decodes to:

```
phandle 0x1a2 id 0x02f   -> /soc/interconnect@16E0000  qcom,cliffs-aggre1_noc   id 47
phandle 0x189 id 0x200   -> /soc/interconnect@1        qcom,cliffs-mc_virt      id 512
phandle 0x1a3 id 0x002   -> /soc/interconnect@24100000 qcom,cliffs-gem_noc      id 2
phandle 0x1a4 id 0x21e   -> /soc/interconnect@1600000  qcom,cliffs-cnoc_cfg     id 542
```

Upstream places the same master in a different provider:

```c
/* drivers/interconnect/qcom/milos.c */
static struct qcom_icc_node * const aggre2_noc_nodes[] = {
        [MASTER_SDCC_2] = &xm_sdc2,          /* MASTER_SDCC_2 == 8 */
};
```

This is **not** a hardware contradiction. Each vendor's ICC driver registers the
SDCC2 master in whichever provider array it chooses, and the DTS must name the
provider that its own driver uses. Both descriptions are internally consistent.

Consequence: `&aggre2_noc MASTER_SDCC_2` is correct for an upstream-based G2 DTS,
and `&aggre1_noc 47` is correct only for the vendor Android kernel. The existing
fragments in `dts/` were already right; what was missing was the reason.

`docs/g2-sdhci-linux-provider-map-20260827.md` stated that phandle `0x1a2`
(aggre1_noc) is "not used by the captured SDCC2 master path". That statement is
wrong — `0x1a2` is exactly the master path provider downstream. It has been
corrected.

## 3. Cliffs and Milos are closely related but NOT identical

> **Superseded 2026-09-14.** The device dump settles this: they are *different
> silicon*. Five fixed-silicon values disagree (SDCC2 and UART interrupt
> numbers, SDCC2 and UART pin assignments, SDCC2 SMMU stream), and the interrupt
> numbers are confirmed by the running vendor kernel. See
> `docs/g2-dump-findings-20260914.md` §1. The address-map correspondence below
> is real but is family resemblance, not identity.

Previously asserted without evidence. Now established by address-level
correspondence between the G2 dumps and upstream `milos.dtsi`:

| Item | G2 dump | Upstream milos | |
|---|---|---|---|
| clk_virt / mc_virt | `interconnect@0` / `interconnect@1` | `interconnect-0` / `interconnect-1` | match |
| mmss_noc | `@1400000` | `@1400000` | match |
| cnoc_main | `@1500000` | `@1500000` | match |
| cnoc_cfg | `@1600000` | `@1600000` | match |
| system_noc | `@1680000` | `@1680000` | match |
| pcie_anoc | `@16C0000` | `@16c0000` | match |
| aggre1_noc | `@16E0000` | `@16e0000` | match |
| aggre2_noc | `@1700000` | `@1700000` | match |
| gem_noc | `@24100000` | `@24100000` | match |
| nsp_noc | `@320C0000` | `@320c0000` | match |
| apps_smmu | `@15000000` | `@15000000` | match |
| SDCC2 | `@8804000` | `@8804000` | match |
| UFS | `ufshc@1d84000` | `ufshc@1d84000` | match |
| **UFS SMMU stream ID** | **0x60** | **0x60** | **match** |
| SDCC2 DLL word 1 | `0x0007442c` | `qcom,dll-config = <0x0007442c>` | match |
| SDCC2 DLL word 5 | `0x80040868` | `qcom,ddr-config = <0x80040868>` | match |
| SDCC2 OPP | 100 MHz / 202 MHz | 100 MHz / 202 MHz | match |

The matching UFS stream ID is the strongest single item: SMMU stream IDs are
fixed hardware wiring, they are in the same numbering space on both sides, and
an unrelated SoC would not agree on it.

**Correction, later the same day.** An earlier revision of this section
concluded "same silicon". The pinctrl evidence below does not support that
wording. The correct claim is that Cliffs and Milos share the same SoC-internal
address map and tuning constants — almost certainly the same base design — but
they are **not pin-, IRQ- or stream-ID-identical**, so the G2 is a port onto the
milos platform, not a re-use of it. The three divergences are listed in §4.

Upstream does not use the string "SM7635" anywhere in these files. The
`SM7635` label used in earlier documents is an inference, not an upstream fact.
`milos` is the name to use.

Upstream carries **no Cliffs support of any kind** — no pinctrl, interconnect,
clock or DTS file, and no dt-binding, matches "cliffs" anywhere in the tree.
Everything the G2 gets from upstream, it gets through `milos`.

## 4. Three conflicts that survive — hardware verification required

These are the SDCC2 values where the G2 vendor DT and upstream milos
disagree. Since §3 establishes a shared base design, each is either a real
part-to-part difference or an error on one side.

### 4.1 SMMU stream ID (high risk) — RESOLVED 2026-09-14

Closed in favour of the G2 value. `/sys/class/iommu/smmu.0x0000000015000000/`
lists `8804000.sdhci`, so the vendor kernel attached SDCC2 through apps_smmu with
`0x140` and the card enumerates. `0x140` is proven on this silicon; the candidate
DTS and the validator already use it.


| Source | Value |
|---|---|
| G2 Android DT (`iommus` raw `0000012a 00000140 00000000`, phandle `0x12a` = `/soc/apps-smmu@15000000`) | **0x140** |
| upstream `milos.dtsi` `sdhc_2` | **0x540** |

The repository previously recorded `0x540` in the provider map, in both DTS
fragments and in the validator. That value was taken from upstream, not from the
G2 dump, and contradicts the project rule that G2 dumps are the source of truth.
The remote branch `opencode/g2-c-0001-smmu-stream-140` suggests this was noticed
once and never merged.

The G2 value `0x140` is now used in the candidate fragments. A wrong stream ID
does not fail to compile — it fails at runtime as an SMMU translation fault on
the first SDCC2 DMA, so this must be confirmed on hardware.

### 4.2 SDCC2 interrupts — RESOLVED 2026-09-14

Closed in favour of the G2 values. `/proc/interrupts` on the device shows
`GICv3 239` for `mmc1` and `GICv3 255` for `8804000.sdhci`; Linux prints SPI
hwirq as SPI + 32, so those are SPI 207 and SPI 223 exactly as the DT declares.


| Source | hc_irq | pwr_irq |
|---|---|---|
| G2 Android DT (raw `<0x0 0xcf 0x4>, <0x0 0xdf 0x4>`) | GIC_SPI **207** | GIC_SPI **223** |
| upstream `milos.dtsi` `sdhc_2` | GIC_SPI 204 | GIC_SPI 125 |

The G2 values are kept. The repository already required this and it is unchanged;
it is recorded here because it is the second half of the same divergence and
should be investigated together with §4.1.

### 4.3 TLMM pin map (highest risk of the three)

The G2 `sdc2_on` state decodes from `dumps/g2/g2-readonly-investigation.txt` as:

```
clk    pins="gpio62"                                drive-strength 0x10
cmd    pins="gpio51"                 bias-pull-up   drive-strength 0x0a
data   pins="gpio38","gpio39","gpio48","gpio49"
                                     bias-pull-up   drive-strength 0x0a
sd-cd  pins="gpio31"                 bias-pull-up   drive-strength 0x02
```

Upstream `milos.dtsi` `sdc2_default` uses `gpio62` (clk), `gpio61` (cmd) and
`gpio58/57/35/34` (data). Only the clock pin agrees.

This is worse than a DTS disagreement. `drivers/pinctrl/qcom/pinctrl-milos.c`
defines which function each pin can take:

```c
[34] = PINGROUP(34, sdc2_data, ...)   [51] = PINGROUP(51, qup1_se4, qdss_gpio, ddr_pxi1, ...)
[35] = PINGROUP(35, sdc2_data, ...)   [38] = PINGROUP(38, qup1_se1, qup1_se2, ...)
[57] = PINGROUP(57, sdc2_data, ...)   [39] = PINGROUP(39, qup1_se1, resout_gpio_n, ...)
[58] = PINGROUP(58, sdc2_data, ...)   [48] = PINGROUP(48, qup1_se4, ...)
[61] = PINGROUP(61, sdc2_cmd, ...)    [49] = PINGROUP(49, qup1_se4, ...)
[62] = PINGROUP(62, sdc2_clk, ...)
```

Under the upstream milos pinctrl driver, the G2's cmd and data pins are QUP
(serial) pins and cannot be muxed to `sdc2_cmd` / `sdc2_data` at all. `dtc` does
not validate pin/function pairs, so a G2 DTS carrying the real hardware values
compiles cleanly and is expected to be rejected by the pinctrl driver at probe.

Since TLMM pin maps are fixed silicon, this is the strongest single piece of
evidence that Cliffs and Milos are different parts. A Cliffs TLMM description
(a `pinctrl-cliffs.c`, or a verified statement that the milos map applies) is
now a prerequisite for a *working* G2 SD card, independent of the DTS.

All three conflicts are recorded as bring-up blockers, not resolved facts.

## 5. Verification method

Upstream files read at `torvalds/linux` `master`:

- `arch/arm64/boot/dts/qcom/milos.dtsi`
- `arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dts`
- `drivers/interconnect/qcom/milos.c`
- `include/dt-bindings/interconnect/qcom,milos-rpmh.h`
- `include/dt-bindings/clock/qcom,milos-gcc.h`

G2 files read in this repository:

- `dumps/g2/g2-sdhci-node-complete-20260822-004035.txt`
- `dumps/g2/g2-sdhci-provider-targeted-20260822-012437.txt`
- `dumps/g2/g2-sdhci-provider-resolution-20260822-011433.txt`
- `dumps/g2/g2-sdhci-interconnect-opp-resolution-20260821-061758.txt`
- `dumps/g2/g2-dt-kernel-source-audit-20260820-234223.txt`

The upstream tree is not pinned in `.github/workflows/g2-sdhci-linux-dtc.yml`,
so these upstream values can drift. Pinning that workflow remains open work.

## 6. Symbol table for the G2 upstream DTS

| Role | Upstream symbol | Value | Provider label |
|---|---|---|---|
| AHB clock | `GCC_SDCC2_AHB_CLK` | 121 | `&gcc` |
| core clock | `GCC_SDCC2_APPS_CLK` | 122 | `&gcc` |
| reset | `GCC_SDCC2_BCR` | 20 | `&gcc` |
| ICC master | `MASTER_SDCC_2` | 8 | `&aggre2_noc` |
| ICC mem slave | `SLAVE_EBI1` | 1 | `&mc_virt` |
| ICC cpu master | `MASTER_APPSS_PROC` | 2 | `&gem_noc` |
| ICC cfg slave | `SLAVE_SDCC_2` | 20 | `&cnoc_cfg` |

Downstream Cliffs equivalents (`108`, `109`, `17`, `47`, `512`, `2`, `542`) are
evidence of the vendor topology only and must not appear in an upstream DTS.

## 7. Board values that remain G2-specific

Never inherited from `milos-fairphone-fp6.dts`:

| Item | G2 | Fairphone FP6 |
|---|---|---|
| card detect | GPIO **31**, `GPIO_ACTIVE_LOW` | GPIO 65, `GPIO_ACTIVE_HIGH` |
| SDCC2 clk | GPIO 62, drive 16 | (board pinctrl) |
| SDCC2 cmd | GPIO 51, pull-up, drive 10 | (board pinctrl) |
| SDCC2 data | GPIO 38/39/48/49, pull-up, drive 10 | (board pinctrl) |
| VDD / VDD-IO | PMXR2230 L13 / L23 | `vreg_l13b` / `vreg_l23b` (pm7550) |

Whether the G2's PMXR2230 rails are the same device upstream calls `pm7550` is
not yet established and is listed in the hardware dump plan.
