# Cliffs is SM8635 — and that gives us a real target

## The identification

Qualcomm's internal naming for the **Snapdragon 8s Gen 3 / SM8635**:

| Layer | Name |
|---|---|
| MSM codename | `palawan` |
| **HLOS / platform name** | **`cliffs`** |
| **Family** | **`pineapple`** |

The device's own dump has carried the confirmation the whole time:

```
[ro.product.device]: [pineapple]
[ro.product.name]:   [pineapple]
```

We read `pineapple` as a meaningless vendor string. It is Qualcomm's family
name, and `cliffs` — the platform name we took from the vendor socinfo header
and used to name `dts/cliffs.dtsi` — is the HLOS name of **SM8635**.

The postmarketOS page covering this silicon covers **SM8635 and SM7675
together**, which also explains an oddity noted earlier: the G2's published core
layout (1x X4 @2.8, 4x A720 @2.57, 3x A520 @1.9) matches SM7675, the Snapdragon
7+ Gen 3. Both parts are the same platform.

So the Snapdragon G2 Gen 2 is a **Cliffs-family derivative**, sibling to SM8635
and SM7675. SoC ID 700 is its own die ID — it is not literally SM8635 — but it
is the same platform, the same generation, and the same family.

## Why this matters

The firehose search has been looking for the wrong thing. "A programmer for the
Snapdragon G2 Gen 2" does not exist and never will — one device uses that chip.
**"A programmer for a Cliffs-platform device"** is an entirely different
question, because SM8635 shipped in mass-market phones in 2024:

- Xiaomi POCO F6 / Redmi Turbo 3 (`peridot`)
- Honor 200
- realme GT Neo6
- iQOO Z9 Turbo

Firehose programmers for these are in circulation.

## And the signature problem does not apply to us

`FastbootCmds.c` publishes `secure` from `IsSecureBootEnabled()`, and this
device answers `no`. **The PBL does not verify the programmer's signature.** A
programmer signed by Xiaomi, Honor or anyone else loads here regardless of whose
key signed it.

That is the whole reason this is worth trying rather than a fantasy.

## One trap, and how to avoid it

Xiaomi's loaders carry an **auth handshake inside the firehose itself** — a
software check, separate from the PBL's signature check. A Xiaomi loader would
load on our device and then refuse commands. Xiaomi patched the older bypasses
from Snapdragon 8 Gen 1 onward, so a "no-auth" `peridot` loader is the hard
version of this search.

**Prefer a non-Xiaomi SM8635 loader.** Honor, realme and iQOO do not carry
Xiaomi's auth layer. A loader from a Honor 200 or realme GT Neo6 is both easier
to find and more likely to simply work.

## What to search for

Target: **any `prog_firehose_ddr.elf` (or similarly named `.elf`) for a
Snapdragon 8s Gen 3 / SM8635 device, UFS storage, non-Xiaomi.**

Useful phrasings:

- `Honor 200 firehose elf EDL`
- `realme GT Neo6 firehose prog_firehose_ddr.elf`
- `iQOO Z9 Turbo 9008 firehose`
- `SM8635 firehose loader`
- `peridot no auth firehose` — the Xiaomi route, harder

Also worth checking, both indexed by identifiers rather than device names, so
the PK hash read makes them searchable:

- `hoplik/Firehose-Finder` `fh_collection/` (archived, keyed by hash)
- the XDA thread "Xiaomi No Auth Firehose Files for Qualcomm based phones"

## The procedure, with a read-only gate

1. Bootloader menu → **Emergency mode**. PC shows `QUSB_BULK_CID:045B`.
2. **Zadig** → List All Devices → that entry → **WinUSB** → Replace Driver.
   (`bkerler/edl` speaks libusb, not the QDLoader serial driver QFIL wants.)
3. ```
   git clone https://github.com/bkerler/edl && cd edl
   pip install -r requirements.txt
   ```
4. **Read-only test — this writes nothing:**
   ```
   python edl --loader=<candidate.elf> printgpt --memory=ufs
   ```
   - A correct partition table, with `boot_a`, `boot_b`, `super`, `userdata` at
     the sizes `fastboot getvar all` reported → **the loader runs on this
     silicon.** Go on.
   - Garbage, a hang, or an error → stop. Nothing was written. Try the next
     candidate.
5. **The fix, once a loader is verified:**
   ```
   python edl --loader=<verified.elf> setactiveslot b
   ```
   That rewrites the GPT attribute bits — the single thing that is wrong.
6. Power-cycle. Slot b's Android is intact and boots, and recovery clears the
   stale BCB on the way.

## Honest odds

SoC ID 700 is a Cliffs derivative, not SM8635 itself. A firehose initialises the
DDR and UFS controllers of the chip it was built for, and a derivative can differ
in exactly those blocks. This is not guaranteed to work.

What it is: the same platform, the same family, the same generation, with no
signature barrier and a read-only step that proves compatibility before anything
is written. That is a far better proposition than anything else left, and the
cost of a failed candidate is a hang and a power-cycle.
