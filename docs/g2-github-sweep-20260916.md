# GitHub sweep for a G2 programmer

**Date:** 2026-09-16
**Result:** no firehose programmer for this SoC exists publicly.

Searched through web search and direct page reads; GitHub's global code search is
outside this session's repository scope and was not used.

| Repository | What it is | Bearing on this |
|---|---|---|
| `RetroidPocket` (the vendor's own org) | 6 repos: a `u-boot` tree, a `linux` fork, a `batocera.linux` fork, an Armbian `build` fork, `alsa-ucm-conf`, dual-screen support | **All SM8250** — Pocket 5 / Mini era. Nothing for the G2 |
| `armada-os/armada` issue #238 | "Retroid Pocket G2 Support", opened 2026-08-10 | A live thread for this exact device. Contains no technical content at all — SoC name and nothing else |
| `hoplik/Firehose-Finder` | Matches loaders by **PK hash** or file MD5, ships an `fh_collection` | **Archived 2026-03-27.** Predates this silicon |
| `Alephgsm/SAMSUNG-EDL-Loaders` | Generic Snapdragon programmers | Newest is Snapdragon 855-era. Nothing from 2024 on; the maintainer sells newer ones privately |
| `bkerler/edl`, `gavz/edl_qualcomm`, `danielkutik/qdl`, `LonelyFool/fh_loader`, `alephsecurity/firehorse` | Tooling, not programmers | Useful once a programmer exists; none of them supply one |

Combined with the earlier English, Chinese and wiki searches, the conclusion is
firm rather than provisional: **there is no public programmer for the Snapdragon
G2 Gen 2**, because the Retroid Pocket G2 is the only device that uses it and
nobody has published one.

## Two things the sweep did turn up

### Retroid publishes bootloader source — for their other devices

`RetroidPocket/u-boot` is described as the "Retroid Pocket SM8250 'Das U-Boot'
Source Tree", alongside a kernel fork and a Batocera fork. So this vendor does
publish boot-chain source for devices it supports on Linux, and maintains the
`linux_support@goretroid.com` address.

That matters twice over. For the immediate problem, it means the programmer is
the kind of thing they hand out rather than guard. For **Path B** — which
`g2-decisions-20260914.md` deferred and `g2-path-a-closed-20260915.md` left as
the only long-term route — it means the blocker ("no Cliffs ABL exists to
build") may be a matter of the G2 not being supported *yet* rather than a
policy.

### There is already a public thread for this device

`armada-os/armada#238` asks for G2 support and contains nothing but the SoC
name. Everything in `dumps/g2/` and `docs/` goes well beyond it: the SoC
identification, the full partition table, the boot-chain findings, a compiling
device tree, and now a complete map of what this bootloader will and will not
do.

Posting that there is worth doing on its own terms, and it reaches the people
most likely to have or to want the missing file.

## What the PK hash would unlock

`Firehose-Finder` indexes by **PK hash** — the OEM public-key hash the PBL
reports during the Sahara handshake, before any programmer is loaded. That is
the field these collections are keyed on, and it is exactly what
`g2-edl-staged-recovery-plan.md` describes reading, with no programmer and no
writes.

Even against an archived collection it is the right identifier to search with,
and it is the one piece of identifying information about this device that has
not yet been read.
