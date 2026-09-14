# Cliffs vendor source located — 2026-09-14

The check that gated Tiers 1–3 of `docs/g2-cliffs-port-estimate-20260914.md` is
**answered: the source exists and is reachable.** It is not at CodeLinaro (which
this session cannot reach) but in an OEM's GPL publication on GitHub.

## 1. Where

| | |
|---|---|
| Repository | `MiCode/Xiaomi_Kernel_OpenSource` |
| Branch | `peridot-u-oss` |
| Pinned commit | `062233df735dd3db2e20aea2f7d3f87c0b1ffde2` |
| License | `GPL-2.0-only` on every file below |

Twelve branches in that repository carry Cliffs support:
`aurora-u-oss`, `bsp-manet-u-oss`, `bsp-zorn-v-oss`, `chenfeng-u-oss`,
`flourite-v-oss`, `goku-u-oss-test`, `muyu-v-oss`, `peridot-u-oss`,
`shennong-u-oss`, `spring-v-oss`, `uke-v-oss`, `warm-u-oss`.

Files confirmed present (HTTP 200):

| Path | Lines | Size | sha256 |
|---|---|---|---|
| `drivers/clk/qcom/gcc-cliffs.c` | 3207 | 88K | `7d19636b…` |
| `drivers/pinctrl/qcom/pinctrl-cliffs.c` | 2305 | 68K | `65fdbcfa…` |
| `drivers/interconnect/qcom/cliffs.c` | 3054 | 72K | `9e52a561…` |
| `include/dt-bindings/clock/qcom,gcc-cliffs.h` | 188 | — | `34f8d0c0…` |
| `include/dt-bindings/interconnect/qcom,cliffs.h` | — | — | `18cd161d…` |
| `include/dt-bindings/clock/qcom,dispcc-cliffs.h` | — | — | present |
| `include/dt-bindings/clock/qcom,gpucc-cliffs.h` | — | — | present |

Device trees are **not** in this repository (`arch/arm64/boot/dts/vendor/qcom/`
returns 404); Xiaomi publishes those separately. That matters less than it
sounds — we already have the G2's own device tree archived.

## 2. It is verified as the G2's SoC, three independent ways

Not assumed from the filename. Every value below was derived from
`dumps/g2/g2-devicetree-20260914-222623.tar.gz` *before* this source was found,
and each matches exactly.

### Clock IDs

| | G2 device tree | `qcom,gcc-cliffs.h` |
|---|---|---|
| debug UART | `<&gcc 75>` | `GCC_QUPV3_WRAP0_S5_CLK  75` |
| SDCC2 iface | `<&gcc 108>` | `GCC_SDCC2_AHB_CLK  108` |
| SDCC2 core | `<&gcc 109>` | `GCC_SDCC2_APPS_CLK  109` |
| SDCC2 reset | `<&gcc 17>` | `GCC_SDCC2_BCR  17` |

### Interconnect IDs

The G2's raw `interconnects` tuple decodes to 47 / 512 / 2 / 542:

| | G2 device tree | `qcom,cliffs.h` |
|---|---|---|
| `MASTER_SDCC_2` | 47 | 47 |
| `SLAVE_EBI1` | 512 | 512 |
| `MASTER_APPSS_PROC` | 2 | 2 |
| `SLAVE_SDCC_2` | 542 | 542 |

### Pin map — the one that could not be reconciled with upstream

`pinctrl-cliffs.c` carries exactly the pins the G2 uses and upstream `milos`
could not provide:

```c
[22] = PINGROUP(22, qup0_se5_l2, …)   /* G2 UART TX  */
[23] = PINGROUP(23, qup0_se5_l3, …)   /* G2 UART RX  */
[38] = PINGROUP(38, sdc2_data, …)
[39] = PINGROUP(39, sdc2_data, …)
[48] = PINGROUP(48, sdc2_data, …)
[49] = PINGROUP(49, sdc2_data, …)
[51] = PINGROUP(51, sdc2_cmd,  …)
[62] = PINGROUP(62, sdc2_clk,  …)
.ngpios = 179
```

`ngpios = 179` is consistent with the G2 device tree's highest referenced pin
(`gpio177`). Upstream milos has 168 and maps gpio22/38/39/48/49/51 to QUP
functions instead.

Every divergence recorded in `docs/g2-dump-findings-20260914.md` §1 is explained
by this source being the right one and `milos` being a different SoC.

## 3. The repository's SoC label has been wrong throughout

From the `linux-msm/mainline-status` project's own data (`_soc/milos.md`):

```yaml
name: Milos
skus: [SM7635]
fullname: Qualcomm Snapdragon 7s Gen 3
```

So **SM7635 is Milos — the Fairphone 6 SoC — not the G2's.** Documents in this
repository have labelled the G2 "SM7635/Milos" since 2026-08-27; that is a
different chip. The G2 is Cliffs: SoC ID 700, `chip_id SGP_LAMMA`, 3× A520 +
4× A720 + 1× Cortex-X4.

The same project tracks 34 SoC families and **Cliffs is not among them**, which
independently confirms that no mainline enablement exists or is in progress.

## 4. What this changes in the estimate

Real sizes replace the milos proxies:

| Driver | milos proxy | actual Cliffs |
|---|---|---|
| GCC | 3224 | **3207** |
| pinctrl | 1336 | **2305** |
| interconnect | 1919 | **3054** |
| total, three core drivers | 6479 | **8566** |

So the three drivers are about a third larger than estimated. The estimate's
7000–9000 line figure for reaching SD boot still holds roughly, but the nature
of the work changes completely:

- **Before:** possibly reverse-engineering register maps — not a realistic
  project.
- **Now:** adapting existing GPL source. Tiers 1–3 are tractable.

The remaining work is real but ordinary. This is downstream Android 6.1 vendor
code, so porting to a current mainline kernel means adapting to APIs that moved
between 6.1 and 7.x (clk, pinctrl and interconnect frameworks all changed). That
is the normal shape of mainlining a Qualcomm SoC, not a research problem.

## 5. Access notes

`git.codelinaro.org`, `android.googlesource.com`, `git.linaro.org`,
`source.codeaurora.org` and `gitee.com` are all refused by this session's egress
policy — the proxy answers `403` to `CONNECT` and records
`connect_rejected / policy denial`. Per the proxy's own documentation those are
reported, not routed around.

What is permitted and was used instead: `raw.githubusercontent.com` and
anonymous `git` reads of public GitHub repositories, both unscoped. The GitHub
REST API is scoped to this repository (`/search/*` and other owners' `/repos/*`
return 403), and GitHub's web search was rate-limited, so the twelve Cliffs
branches were found by probing all 264 branches of
`MiCode/Xiaomi_Kernel_OpenSource` for the header path directly.

## 6. Armada — verified private, not retrievable

`shuuri-labs/armada` asks for credentials on an anonymous clone while
`shuuri-labs/pocknix-os`, `qualcomm-linux/kernel`, `RetroidPocket/linux`,
`MiCode/Xiaomi_Kernel_OpenSource` and `CodeLinaro-mirror/la_kernel_msm` all clone
anonymously through the same proxy. It is a private repository, and `add_repo`
cannot attach it (cross-owner adds are refused in this session).

It is therefore not readable by any legitimate means available here. The two
Armada citations in `docs/development-roadmap-20260822.md` remain unverifiable —
and one of them was already shown wrong by pocknix's own device profiles
(`docs/g2-reference-projects-review-20260914.md` §2). pocknix covered what
Armada was being cited for.

## 7. Next

The Tier 1 blocker is cleared. Recommended order is unchanged otherwise:
Tier 0 first (minimal DTSI + EFI boot + console — still needs none of this
source), then decide on committing to the driver port with the real sizes above
in hand.
