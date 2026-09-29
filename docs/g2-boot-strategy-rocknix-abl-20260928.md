# Boot strategy decision: target ROCKNIX-ABL (Path B) — 2026-09-28

## Decision

The G2 Linux/SteamOS port will target the **ROCKNIX-ABL boot path** (Path B in
`g2-reference-projects-review-20260914.md`), not the factory-ABL + EFI path
(Path A). This is the mechanism the entire Qualcomm handheld-Linux ecosystem
uses, including the two reference projects.

## Why (evidence)

- ROCKNIX's Qualcomm support boots every device through its custom **abl**
  (`github.com/ROCKNIX/abl`) — a Qualcomm ABL replacement that makes Linux the
  default boot target while keeping Android bootable and selectable. It needs no
  GRUB/U-Boot. Used by ROCKNIX, Batocera, Knulli, Armada, Thorch, MaSi-OS,
  NovaDeck.
- **Armada** installs by `dd`-ing `abl_signed-<device>.elf` into `abl_a` + `abl_b`
  (258 KiB each), nothing else on internal storage touched; OS runs from SD.
- **pocknix** is ROCKNIX-kernel based and rides the same Qualcomm ABL path. (The
  earlier "pocknix = arm-efi / factory ABL" note in
  `g2-reference-projects-review-20260914.md` was about the RP5 kernel recipe, not
  the bootloader lineage — reconciled: ROCKNIX-ABL is the mainstream route.)

## The gap: no Cliffs build exists

> **Update 2026-09-29:** ROCKNIX ABL builds are per SoC family and nearly
> SoC-agnostic (SM8550/SM8650/SM8750 differ only in a display-power callback).
> The G2 is `ro.board.platform=pineapple`, so the existing SM8650 build is the
> first candidate; no Cliffs build may be needed. See
> `g2-sd-boot-rocknix-abl-20260929.md`.

`github.com/ROCKNIX/abl` is buildable source (edk2 / QcomModulePkg, GitHub
Actions build workflows), but its supported SoCs today are:

| SoC | Snapdragon | Example devices |
|---|---|---|
| SM8250 | 865 | Retroid Pocket 5, RP Mini |
| SM8550 | 8 Gen 2 | AYN Odin2, AYANEO Pocket, Retroid Pocket 6 |
| SM8650 | 8 Gen 3 | AYANEO Pocket S2, KONKR Pocket FIT |

**SM8635 (Cliffs / Snapdragon G2 Gen 2 = the G2) is not supported.** So the task
is concretely: **produce a ROCKNIX-ABL build for SM8635/Cliffs.**

## Why this is now tractable and safe

1. **Cliffs is a pineapple-family cousin of SM8650.** ROCKNIX already ships an
   SM8650 (8 Gen 3 / pineapple) ABL; derive the Cliffs target from it rather than
   from scratch. (Our dumps: `ro.product.device=pineapple`, Cliffs = SM8635,
   MSM codename palawan.)
2. **Flashing a custom ABL is now reversible.** We have a verified full backup
   incl. `abl_a`/`abl_b` (factory backup, 2026-09-28), EDL 9008 recovery is
   proven end-to-end, and **secure boot is OFF** (`IsSecureBootEnabled()=false`)
   so the PBL/loader accept unsigned code. The old "no ABL modification" rule was
   written before these safety nets existed; it no longer needs to block Path B.
3. **Some G2-specific inputs already in hand**: simple-framebuffer at
   `0xe3940000`, 1080x1920 a8r8g8b8 (see `dts/cliffs-g2.dts`); DRAM map; UFS.

## Open questions / next investigation

1. **ROCKNIX/abl repo structure** — how is a device/SoC *target* defined? Which
   files are SoC-specific vs device-specific? (Find the per-target config; the
   README lists no SoCs, so read the tree + build workflow YAML.)
2. **Cliffs QcomModulePkg / ABL source** — ROCKNIX-ABL is patches on top of
   Qualcomm's ABL for a given target. Do we have, or can we obtain, the
   Cliffs/palawan `QcomModulePkg` (edk2) target from CLO? We already read this
   device's ABL source for `g2-abl-source-findings.md` — locate that tree and
   whether it is buildable.
3. **Toolchain** — reproduce ROCKNIX-ABL's edk2 aarch64 build (their GH Actions
   is the reference); confirm it can target a new SoC.
4. **Delta SM8650 → SM8635** — memory map, UART, display init, UFS boot LUN,
   panel. Enumerate what differs for Cliffs.
5. **Flash/test plan** — flash the built ABL to **one slot only** first (keep the
   other slot's stock ABL as an in-device fallback), test the ROCKNIX-ABL menu,
   boot ROCKNIX/Linux from SD. EDL + backup cover total failure.

## Status

- Boot path: **DECIDED — Path B (ROCKNIX-ABL).**
- Blocking dependency: a Cliffs/SM8635 ROCKNIX-ABL build (does not exist; must be
  produced). This is the next work item, superseding the Path A / EFI line of
  investigation as the primary route.

## Sources
- github.com/ROCKNIX/abl (buildable ABL source, GH Actions build)
- ROCKNIX supported hardware (SM8250 / SM8550 / SM8650) — rocknix.org, DeepWiki ROCKNIX/distribution
- github.com/shuuri-labs/pocknix-os (SM8250 & SM8550, ROCKNIX-based kernel)
- Armada (`armada-os/armada`) abl install = dd to abl_a/abl_b
- Prior repo docs: g2-reference-projects-review-20260914.md, g2-abl-source-findings.md,
  g2-EDL-recovery-runbook.md (recovery + backup safety nets)
