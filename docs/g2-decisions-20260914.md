# G2 decisions — 2026-09-14

Two things settled: which boot path the project takes, and how far the "Cliffs"
identification actually holds.

## 1. Boot path — A now, B later

**Decision: pursue Path A. Revisit Path B only once A is complete.**

| | A — factory ABL + EFI | B — ROCKNIX-ABL swap |
|---|---|---|
| Internal writes | none | `abl_a` + `abl_b`, 258 KiB each, backed up and restorable |
| Mechanism | firmware runs `\EFI\BOOT\BOOTAA64.EFI` from the SD card's ESP; GRUB supplies kernel + DTB | purpose-built dual-boot bootloader with a boot-source menu |
| Precedent | pocknix RP5 (`arm-efi`) | Armada, ROCKNIX, Batocera, Knulli, Thorch, … |
| Blocker | unverified: does the G2's factory ABL run the removable-media fallback? | no Cliffs ABL exists, and `ROCKNIX/abl` publishes a README and updater, not buildable source |

Rationale for the order: A keeps the project's no-internal-writes rule intact and
is the only path this project can pursue without a third party. B depends on
someone with the ROCKNIX ABL toolchain producing a build for this SoC, so it
cannot be started unilaterally even if the rule were relaxed.

Path B is **not rejected** — it is deferred. It is how most of the handheld Linux
ecosystem actually works, its risk profile is milder than this project's rules
imply (Android survives, the change is 258 KiB and reversible from a backup), and
if A turns out to be impossible on the G2 it becomes the main route. Revisit once
A is either working or shown not to work.

## 2. Is "Cliffs" right? — yes at the level that matters, with one caveat

The identification holds where the port needs it to, and is weaker than earlier
documents implied at the marketing level. Both halves matter.

### Confirmed: the G2 runs the Cliffs platform, and Cliffs drivers fit it

The device declares it — DT compatible `qcom,cliffs-mtp`, `qcom,cliffs`,
`qcom,cliffsp-mtp`, `qcom,cliffsp`; `ro.boot.product.vendor.sku = cliffs`;
model "Qualcomm Technologies, Inc. Cliffs MTP" — and the vendor kernel loads
`gcc_cliffs`, `pinctrl_cliffs`, `qnoc_cliffs`, `camcc_cliffs`, `gpucc_cliffs`,
`debugcc_cliffs`.

More usefully, the Cliffs driver data matches the G2's own device tree across
three independent ID spaces (`docs/g2-cliffs-vendor-source-found-20260914.md` §2):
clock IDs 75 / 108 / 109 / 17, interconnect IDs 47 / 512 / 2 / 542, and the pin
map down to `gpio22 = qup0_se5_l2`.

And the G2's device tree stays inside what those drivers define:

| | Cliffs driver defines | G2 device tree uses |
|---|---|---|
| GCC IDs | 175, range 0–145 | 59 distinct, range 0–138 |
| TLMM pins | `ngpios = 179` | highest referenced `gpio177` |
| interconnect IDs | 169 defined | all four SDCC2 IDs present and matching |

Nothing the G2 references falls outside the Cliffs drivers' coverage.

### Caveat: the SoC ID is not "CLIFFS"

The G2's `qcom,msm-id` is **700** (`0x2bc`) and `/sys/devices/soc0/chip_id` reads
**`SGP_LAMMA`**. The vendor socinfo table maps:

```c
{ 614, "CLIFFS" },   { 632, "CLIFFS7" },
{ 642, "CLIFFSP" },  { 643, "CLIFFS7P" },
```

700 is not among them, and it is absent from the newest Xiaomi table reachable,
which runs to 702 (`spring-v-oss`). So the G2's part is a **newer derivative in
the Cliffs family**, not CLIFFS itself — consistent with
`ro.boot.hardware.revision = "Qualcomm G2 Gen 2"`, a gaming-handheld SKU with its
own SoC ID that reuses the Cliffs platform code.

### Retracted: the "SM7675 / Snapdragon 7+ Gen 3" mapping

`docs/g2-dump-findings-20260914.md` and the port estimate picked up a
`Cliffs = SM7675 = Snapdragon 7+ Gen 3` mapping from a web-search summary. It was
never verified against a primary source, and it does not apply here regardless:
even if SM7675 is CLIFFS, CLIFFS is SoC ID 614 and the G2 is 700. **The G2's
marketing part number is unknown** and should not be asserted. What is known is
the SoC ID (700), the chip id (`SGP_LAMMA`), the CPU complex (3× Cortex-A520,
4× Cortex-A720, 1× Cortex-X4 across three clusters) and the platform (Cliffs).

### Residual risk

A derivative can differ from its base in ways the device tree does not exercise —
extra clocks, a changed NoC node, a different pin somewhere the G2 does not use.
The range checks above bound this for everything the G2's own DT touches, which
covers the SD path and the console, but they do not prove the Cliffs drivers are
correct for the whole chip. Treat driver-level surprises during Tier 1 as
expected rather than as evidence the identification was wrong.

None of this changes the port plan: the Cliffs drivers are the right starting
point, and they are the only ones that exist.
