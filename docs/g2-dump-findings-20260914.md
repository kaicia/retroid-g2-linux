# G2 consolidated dump — findings, 2026-09-14

Analysis of `dumps/g2/g2-consolidated-hardware-20260914-222623.txt` and
`dumps/g2/g2-devicetree-20260914-222623.tar.gz` (4015 nodes, 22697 properties),
collected read-only from the device.

Headline: **Cliffs is not the same silicon as upstream `milos`.** Section 1 is
the evidence, and it changes the port's shape.

> **Confirmed and named, later the same day.** Qualcomm's Cliffs source was
> located (GPL, on GitHub) and every value derived below matches it exactly —
> see `docs/g2-cliffs-vendor-source-found-20260914.md`. That document also
> corrects this repository's long-standing SoC label: **SM7635 is Milos**, the
> Fairphone 6 part, not the G2's. The G2 is Cliffs.

## 1. Cliffs ≠ Milos — now settled by hardware values

`docs/g2-provider-domain-decision-20260912.md` §3 argued from matching register
addresses that the two were the same part, with a later correction to "closely
related". The dump settles it the other way.

The distinction that matters: some ID spaces are **software convention** (a
driver picks its own indices) and some are **fixed silicon**. Only the second
kind is evidence.

### The CPU complex settles it outright

ARM part numbers from `/proc/cpuinfo` (implementer 0x41): the G2 has
3× Cortex-A520 (`0xd80`), 4× Cortex-A720 (`0xd81`) and 1× **Cortex-X4**
(`0xd82`) across three clusters. Upstream milos has 4× A520 + 4× A720 in two
clusters and no X4 at all. Core composition cannot vary within one die.

### Other fixed-silicon values that differ

| | G2 / Cliffs | upstream milos |
|---|---|---|
| SDCC2 `hc_irq` | GIC_SPI **207** | 204 |
| SDCC2 `pwr_irq` | GIC_SPI **223** | 125 |
| debug UART IRQ | GIC_SPI **358** | 525 |
| SDCC2 clk / cmd / data pins | gpio62 / **51** / **38,39,48,49** | gpio62 / 61 / 58,57,35,34 |
| UART TX / RX pins | **gpio22 / gpio23** | gpio25 / gpio26 |
| SDCC2 SMMU stream | **0x140** | 0x540 |

The interrupt numbers are confirmed by the running vendor kernel, not just by
the DT. Linux prints SPI hwirq as SPI + 32:

```
147:  GICv3 255 Level   8804000.sdhci          -> SPI 223
146:  GICv3 239 Level   mmc1                   -> SPI 207
144:  GICv3 390 Level   qcom_geni_serial_uart0 -> SPI 358
148:  msmgpio  31 Edge  8804000.sdhci cd       -> GPIO 31
```

GIC SPI allocation, TLMM pin muxing and SMMU stream IDs are all fixed at tape-out.
Five independent hardware values disagreeing is not a variant of one part.

### A difference that is NOT evidence

The G2's UART reads `clocks = <&gcc 75>` where upstream milos defines
`GCC_QUPV3_WRAP0_S5_CLK = 90`; SDCC2 similarly reads 108/109 against upstream's
121/122. These are **driver index spaces**, not hardware — the same physical
clock with a different software number. Listed here only so it is not
double-counted as evidence later.

### What still matches

Every IP block sits at the same address (SDCC2 `0x8804000`, UART `0xa94000`,
apps_smmu `0x15000000`, UFS `0x1d84000`, all eleven NoC providers), the SDCC2
DLL/DDR tuning words are identical, the OPP pair is identical, and the UFS SMMU
stream is `0x60` on both. Same family and IP lineup; different die.

### Consequence for the port

`milos.dtsi` cannot serve as the G2's SoC base. Every interrupt, every pin state
and at least one stream ID would need overriding — at which point it is not a
board file on top of a SoC file, it is a new SoC description. Upstream carries
**no Cliffs support of any kind**: no pinctrl, interconnect, clock or DTS file,
and no dt-binding matches "cliffs" anywhere in the tree.

`dts/g2-sdhci-compile-test.dts` still compiles and its overrides are still the
right values; it is just further from bootable than the "port onto milos"
framing suggested.

## 2. SoC identity

```
chip_id       = SGP_LAMMA        chip_family = 0x94        feature_code = AB
qcom,msm-id   = 0x000002bc 0x00010000     -> SoC ID 700, rev 1.0
qcom,board-id = 0x00000008 0x00000000     -> board 8, subtype 0
model         = Qualcomm Technologies, Inc. Cliffs MTP
```

Firmware CRM strings name **LANAI** (boot, TZ, DSP) and **PALAWAN**
(`Variant: SocPalawanLAA`, WLAN `QCALAMSLPALAWANQ`).

> **Correction 2026-09-14.** SoC ID 700 is *not* "CLIFFS" in Qualcomm's own
> socinfo table — that is 614, with CLIFFSP 642 — and 700 is absent even from the
> newest vendor table reachable (to 702). The G2 is a newer derivative in the
> Cliffs family running Cliffs platform code, and its marketing part number is
> unknown. Any `SM7675` / `Snapdragon 7+ Gen 3` mapping mentioned elsewhere in
> this repository is **retracted**: it came from a search summary and does not
> apply to SoC ID 700. See `docs/g2-decisions-20260914.md` §2.

`qcom,msm-id` and `qcom,board-id` are what the bootloader matches a DTB against,
so these are the values a G2 DTB must carry to be accepted.

SoC ID 700 is **not** in upstream's `include/dt-bindings/arm/qcom,ids.h` (which
runs to 781). That is not evidence either way about Cliffs vs Milos: upstream has
no socinfo entry for `milos` either.

## 3. SMMU stream ID 0x140 confirmed working

`/sys/class/iommu/smmu.0x0000000015000000/` lists `8804000.sdhci` among its
devices, so the vendor kernel attached SDCC2 to apps_smmu using the DT's
`0x140` — and the card enumerates (`mmc1`, `mmcblk1`, 58587 interrupts taken).

`0x140` is therefore a value proven to work on this silicon. Decision-doc §4.1
closes in favour of the G2 dump; the candidate DTS and validator already use it.

## 4. Console channels — re-ranked

### UART: better than expected

The debug UART node is `status = "ok"` in the vendor DT — enabled, not disabled.

```
compatible   = qcom,geni-debug-uart        (identical to upstream)
reg          = 0x00a94000 size 0x4000      (identical to upstream)
serial engine = SE5                        (upstream uart5 / S5)
interrupts   = GIC_SPI 358
TX = gpio22, function qup0_se5_l2, drive-strength 2, bias-disable
RX = gpio23, function qup0_se5_l3, drive-strength 2, bias-disable
```

Upstream's milos pinctrl offers `qup0_se5` on gpio23/24/25/26 — gpio23 (RX)
overlaps, but gpio22 is `qup0_se4` there, so the G2's TX pin is not muxable to
SE5 under the milos driver. As noted in the console doc, `earlycon` writes MMIO
directly and the firmware has already muxed these pins for its own log, so early
output should not depend on Linux pinctrl.

The vendor kernel's own UART interrupt count is 0, consistent with a console
that is wired and initialised but never written to during a normal Android boot
(`bootargs` has no `console=` and sets `printk.console_no_auto_verbose=1`).

Physical accessibility of gpio22/23 remains the one open question, unanswerable
from software.

### ramoops: weaker than expected

```
compatible   = "ramoops"          (upstream-compatible)
size         = 0x200000  (2 MB)
pmsg-size    = 0x200000  (2 MB)
mem-type     = 2
alloc-ranges = 0x0 .. 0xffffffffffffffff
```

There is **no fixed `reg`** — the region is dynamically allocated, so its address
differs per boot. That breaks the "boot our kernel, let it fail, reboot into
Android and read `/sys/fs/pstore`" plan: Android's pstore would map its own
region, not ours. Recovering a log would need both kernels pinned to the same
fixed address plus a way to read raw memory from Android, which a production
build does not give us.

Demote this from "the safety net" to "possible, with work". The console doc
overstated it.

### simple-framebuffer: now concrete

```
splash_region   label = cont_splash_region
                reg   = 0xE3940000, size 0x02B00000  (45 MB)

panel  qcom,mdss_dsi_g1548_fhd_plus_60_video
       name   = "g1548 lcd video mode dsi"
       1080 x 1920, 24 bpp, DSI video mode, 60 Hz
       h porch 12/12, pulse 4 ; v porch 12/12, pulse 4
```

Note the panel is **1080x1920**, not FHD+ 1080x2400 — the node name is
misleading. A 32-bpp 1080x1920 buffer is 8.3 MB and fits the 45 MB region many
times over.

That is enough to draft a `chosen { framebuffer@e3940000 { compatible =
"simple-framebuffer"; ... } }` node. Stride and pixel format still need
confirming, and it only works if the firmware leaves the panel lit when it hands
off.

Revised ranking: **UART first** (if the lines are reachable), **framebuffer
second**, ramoops third.

## 5. Collector defect found and fixed

Section C2's UART `pinctrl-0` did not resolve. `pinctrl-0` holds two phandles and
the collector passed their concatenated hex (`000001da000001db`) to a resolver
that matches one 4-byte cell, so it found nothing. The active TX/RX pin states
above came from the device-tree archive instead — which is exactly why archiving
the whole tree was worth doing.

Fixed by splitting phandle-list properties into cells (`cells()` / `resolve_all()`);
dump schema bumped to 3. `pinctrl-1` was unaffected (single phandle), as was the
SDHCI node.

## 6. Open items after this dump

1. Physical access to gpio22/23 — inspection, not software.
2. Pixel format and stride of the splash buffer.
3. Whether to write a Cliffs SoC DTSI and pinctrl driver, or to keep overriding
   milos. §1 argues the first is now the honest path. Sized in
   `docs/g2-cliffs-port-estimate-20260914.md`: roughly 7000–9000 lines of
   Cliffs-specific driver data to reach SD boot, contingent on Qualcomm's vendor
   source being published — which is the one thing that still needs checking.
4. PMXR2230 LDO13/LDO23 rail description, still needed before the card can be
   powered.
