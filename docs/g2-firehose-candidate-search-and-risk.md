# Candidate search: what I found, and an honest risk assessment

## The identification chain is now complete and verified

| Step | Value | Source |
|---|---|---|
| Device family | `pineapple` | `ro.product.device` in our own dump |
| Platform / HLOS name | `cliffs` | vendor socinfo header; names `dts/cliffs.dtsi` |
| MSM codename | `palawan` | Qualcomm naming for SM8635 |
| **Sahara HWID** | **`002750E1` = `SM_PALAWAN`** | loader-identification databases |
| Retail part | SM8635, Snapdragon 8s Gen 3 | — |

Every link independently corroborated. The G2's Snapdragon G2 Gen 2 is a
Cliffs/palawan-family derivative with its own die ID (SoC ID 700, `SGP_LAMMA`).

**`002750E1` is the search key** for any loader collection, and it is worth more
than a device name because these databases are indexed by it.

## I could not obtain a file

The largest public index is `hoplik/Firehose-Finder`. I downloaded and parsed it
rather than reading its description:

```
ForFilter.xml   1416 device records
  HWID 002750E1 (Snapdragon 8s Gen 3):  6 records
  ...of which carry a loader file URL:  0

ForFound.xml     396 loader-file records
  with HW_FH 002750E1:                  0
```

The six devices it knows about:

| Vendor | Model | Also known as |
|---|---|---|
| realme | RMX3851 | GT 6 |
| realme | RMX3852 | GT Neo 6 |
| Xiaomi | 24069PC21G | Poco F6, Redmi Turbo 3, **peridot** |
| motorola | XT2401-2 | Moto X50 Ultra |
| motorola | XT2451 | Razr 50 Ultra |
| OnePlus | CPH2709 | Nord 5, lexus |

So the collection **catalogues this silicon and holds no programmer for it.**
It was archived 2026-03-27, which is part of the explanation.

`temblast.com`, the other large index, is blocked by this environment's egress
policy and could not be read from here. Searches against the six model numbers
turned up no downloadable file either.

**A candidate file was not obtained.** Anyone continuing this should search on
`002750E1` and on those six model numbers, and should prefer the realme,
motorola or OnePlus entries — Xiaomi's loaders carry an auth handshake *inside*
the firehose, separate from the PBL's signature check, which Xiaomi closed from
Snapdragon 8 Gen 1 onward.

## Is it safe? Taken seriously, four separate risks

### 1. Loading the ELF — negligible

Sahara copies the ELF's segments to the addresses in its program headers, into
on-chip SRAM, and jumps. Secure boot is off (`IsSecureBootEnabled()` returns
false), so it loads regardless of who signed it. If the addresses do not match
this die's SRAM layout, the PBL errors out and nothing runs.

### 2. Wrong register writes — low, and self-limiting

The loader configures clocks, DDR and UFS by writing hardware registers. On a
same-platform derivative these maps are close but not guaranteed identical. A
write to an address that means something else, or nothing, produces a bus fault
and the chip resets — back to exactly the state the device is in now.

### 3. Storage — effectively nil, *if the gate is respected*

A firehose does not touch storage while initialising; it waits for XML commands,
and we choose them. `printgpt` reads. Nothing is written unless `setactiveslot`
is issued, and that only happens after the partition table has come back
correct.

**This is the whole reason for the read-only step.** Skipping it removes the
only real protection.

### 4. The PMIC — small, but real, and irreversible

This is the honest one. A loader configures power rails over SPMI. If the target
device's PMIC differs from this one's, a rail could be driven to a wrong voltage,
and that damage is permanent.

Weighing against it, from our own dump — this device carries:

```
pm8550ve   pm8550vs   pm7550ba   pm8008
```

These are the standard pineapple-family PMICs, the same parts SM8635 phones use.
A palawan loader would be addressing the PMICs it expects. That lowers this risk
substantially. It does not eliminate it.

## The verdict, plainly

**Not risk-free.** Risk 4 is small but real and cannot be undone. Risks 1 and 2
cost a reset. Risk 3 is controlled by the read-only gate, provided the gate is
actually used.

Against that: the device currently reaches nothing but fastboot and EDL, ABL has
no write path at all (established from its source, not guessed), and no other
self-service route exists.

That trade is the owner's to make, not ours to make for them. What this document
is for is making sure it is made with the real numbers.
