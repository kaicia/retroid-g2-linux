# Obtainable firehose candidates — concrete sources

The programmer does not have to be leaked. It ships **inside** every stock ROM
for an SM8635 device, in the `images/` folder, as `prog_firehose_ddr.elf`. Get
any SM8635 stock ROM, extract that one file.

## Prefer non-Xiaomi — this is the decisive point

Xiaomi's firehose carries an **auth handshake inside the loader itself**,
separate from the PBL signature check that our `secure:no` already defeats. A
POCO F6 (`peridot`) loader would load on our device and then refuse commands.

Motorola, realme and OnePlus SM8635 loaders do **not** carry that layer. Their
firmware is also freely downloadable, where Xiaomi's increasingly is not.

## The candidates, best first

| Device | Model | SoC codename | Firmware | Xiaomi-style auth |
|---|---|---|---|---|
| **Moto G75 5G** | XT2437 (`paros`) | SM8635 / palawan | freely mirrored | **no** |
| Moto Razr 50 Ultra | XT2451 | SM8635 | freely mirrored | no |
| realme GT Neo 6 | RMX3852 | SM8635 | freely mirrored (OPLUS EDL pkg) | no |
| OnePlus Nord 5 | CPH2709 | SM8635 | mirrored | no |
| POCO F6 / Turbo 3 | peridot | SM8635 | available | **yes — avoid** |

**Motorola first.** Moto firmware is a plain archive, the `.elf` sits in
`images/`, and there is no account gate.

## Getting the file from a Motorola package

1. Download a Moto G75 (XT2437 / `paros`) stock firmware from a mirror —
   romprovider, motostockrom, firmwaredrive and similar all carry it. It is a
   large `.zip` / `.xml.zip`.
2. Extract it. Inside is a flat folder of `.img` files plus an XML.
3. The programmer is **`prog_firehose_ddr.elf`** (Moto sometimes ships it as
   `programmer.elf` or with a `_ddr` suffix). That one file is all we need —
   not the `.img` files, not the XML.

realme/OPLUS packages carry it too, usually named `prog_firehose_ddr.elf`
alongside `rawprogram*.xml`.

## Before trusting any candidate — verify it locally, no device involved

Once a `.elf` is in hand, it can be checked on a PC before it ever touches the
G2. Send it here and this session can inspect it:

- **It is a real AArch64 ELF.** `readelf -h` → `Class ELF64`,
  `Machine AArch64`, `Type EXEC`.
- **It is a Qualcomm firehose.** Strings contain `QCOM Sahara`,
  `Firehose`, and XML tags like `<data>` / `configure`.
- **It targets this platform.** Strings should mention `palawan`, `cliffs`,
  `SM8635`, or the DDR/UFS init for that platform — not some other chip name.
- **Load addresses look like on-chip SRAM** for this family (program headers in
  the `0x1480xxxx` / low-SRAM range Qualcomm uses), not random.

A candidate that fails these never gets loaded. This is a second gate, on the PC,
before the on-device read-only gate (`printgpt` / `getactiveslot`).

## Then the sequence already established

`g2-verified-recovery-sequence.md` — `printgpt` → `getactiveslot` (both
read-only) → `setactiveslot b` → confirm → conditional `setbootablestoragedrive 2`.

## Honest status

This is the first genuinely obtainable candidate in the whole search: a real
file, from a free source, for the right platform, without the auth layer.

What remains uncertain is unchanged and real — the G2's die is a G2-Gen-2
derivative (SoC ID 700), not literally SM8635 (`002750E1`), so a palawan loader
may still mismatch on DDR or UFS init. The two read-only gates exist precisely
to catch that before anything is written. The cost of a wrong candidate is a
hang and a power-cycle; the PMIC risk assessed in
`g2-firehose-candidate-search-and-risk.md` still applies and is the one
irreversible sliver.
