# Path A re-verification against the holodor arm-efi contract — 2026-09-29

Task 2 of the current plan: re-open `g2-path-a-closed-20260915.md` now that the
holodor deep-dive (`g2-holodor-deep-dive-20260929.md`) gives us the *exact*
arm-efi boot contract the RP5 uses in production. Does that contract differ from
what we already tested, in any way that could change the G2 factory ABL's
behavior?

## Verdict up front

**Path A remains very likely closed, but one cheap, decisive test is now
justified before committing fully to Path B.** The twice-tested 2026-09-15
negative is strong *behavioral* evidence: with a textbook ESP (fallback path
`\EFI\BOOT\BOOTAA64.EFI`, ESP type GUID, verified payload), the G2 factory ABL
went **straight to Android and never executed the EFI binary**. That is an
enumeration failure — the ABL did not run any removable-media loader at all.
The holodor contract changes exactly one dimension we had *not* tried, and the
RP5 is a production existence proof, so the residual probability is non-zero but
low. Test it once; do not stake the roadmap on it.

## What holodor's arm-efi does differently from the 2026-09-15 tests

| Dimension | 2026-09-15 (path-a-closed) | holodor arm-efi contract | New? |
|---|---|---|---|
| Partition table | GPT | GPT | no |
| Boot partition FS | FAT32 (`mkfs.vfat -F 32`) | FAT32 (`mkfs.vfat -F 32`) | no |
| **Boot partition marker** | **`esp` type GUID** `C12A7328-…` | **`legacy_boot` flag set, NO esp flag** | **YES** |
| **Boot partition GPT name** | (single ESP, unnamed/EFI) | **name = `"system"`** | **YES** |
| Layout | one partition | **two partitions** (FAT p1 + ext4 p2) | YES |
| Loader path | `\EFI\BOOT\BOOTAA64.EFI` | `\EFI\BOOT\bootaa64.efi` (same fallback) | no |
| Root resolution | (n/a) | kernel `root=PARTUUID=` (fixed GUID) | post-handoff |

So the genuinely untested variable is: **the FAT partition marked `legacy_boot`
and named `system`, alongside a second partition — not carrying the ESP type
GUID.** ROCKNIX/pocknix deliberately use `legacy_boot`, *not* `esp`
(`build-sd-image.sh: parted set 1 legacy_boot on`).

## Mechanistic assessment — will that flip it?

**Argument it won't (stronger):** The 2026-09-15 failure was that the ABL never
ran *any* EFI binary — it did not enumerate the removable device's fallback
loader. Partition *flags* and *names* affect which partition a bootloader treats
as the boot volume *after* it has decided to run its Boot Device Selection pass;
they don't normally cause an ABL that skips removable-media BDS entirely to start
performing it. Qualcomm's ABL on a shipping Android device is built to locate and
launch `boot.img` from the active slot, not to run a full UEFI BDS over removable
media (consistent with `g2-abl-source-findings.md`: this is QcomModulePkg, but
the surviving code paths are the Android boot/recovery flow). An ESP with the
canonical type GUID is the *most* likely thing to trigger BDS; if that was
ignored, a `legacy_boot`-flagged FAT named `system` is not obviously more likely
to be picked up.

**Argument it might (why we still test):** The RP5 (sm8250) runs arm-efi **in
production with its factory ABL** — an existence proof that a Qualcomm handheld
factory ABL *can* chainload `bootaa64.efi` from an SD FAT marked exactly this way
(`legacy_boot`, name `system`, no esp). pocknix/ROCKNIX chose `legacy_boot` over
`esp` for a reason; it's plausible some Qualcomm ABLs key their SD-boot probe on
`legacy_boot` or the partition name rather than the ESP type GUID. If the G2's
ABL build shares the RP5's SD-probe logic, the 2026-09-15 ESP-typed card could
have been rejected precisely *because* it wasn't in the `legacy_boot`/`system`
shape the probe expects. Low probability, but this is the one stone left unturned.

## The single decisive test (staged, read-only to internal)

Reproduce the RP5 arm-efi contract **exactly**, changing only the one untested
variable, and see if the factory ABL hands off. Fully EDL-recoverable; writes
nothing to internal storage.

1. **SD GPT**, two partitions:
   - p1 FAT32, `parted mkpart system fat32 1MiB <end>`, then `parted set 1
     legacy_boot on` (do **not** set esp / do **not** use the ESP type GUID).
   - p2 ext4, `parted mkpart POCKNIX_ROOT ext4 <end> 100%`.
   - Stamp the fixed PARTUUIDs with sgdisk (p1
     `706f636b-6e69-7830-626f-6f7400000001`, p2 `…0002`) for full parity.
2. **p1 contents:** `\EFI\BOOT\bootaa64.efi` = a GRUB `arm64-efi` image built with
   `grub-mkimage -O arm64-efi -p /boot/grub …`, plus `\boot\grub\grub.cfg`.
   - **Stage 0 (decisive, no kernel needed):** grub.cfg that just drops to the
     GRUB console or shows a one-line menu with `timeout=-1`. If the **GRUB
     console/menu appears at all**, the ABL→EFI handoff works → **Path A is
     reopened.** This isolates the ABL question from every kernel question.
   - **Stage 1 (only if Stage 0 passes):** add `/KERNEL` (a known-good aarch64
     `Image`) + a dtb and the real `linux /KERNEL … ; devicetree …` entry.
3. Boot with the SD inserted. Observe: GRUB console/menu (pass) vs. straight to
   Android (fail — Path A definitively closed).

> Fastest way to generate a byte-correct card is holodor's own
> `scripts/build-sd-image.sh` (Linux + root + losetup): set `BOOTLOADER=arm-efi`,
> point it at a stub kernel, and it produces exactly this layout. For Stage 0 a
> hand-made card per the steps above is enough and needs no build.

## Secondary check: `fastboot boot` — already closed

> **Correction 2026-09-29 (same day).** This section originally called
> `ENABLE_BOOT_CMD` unconfirmed and proposed checking it. That was wrong: it was
> tested on 2026-09-15 and failed — `Booting FAILED (remote: 'unknown command')`
> after a successful 41 MB download (`g2-fastboot-boot-unsupported-20260915.md`).
> `fastboot boot` is not available. The remaining routes are Path A Stage 0
> (this doc), Path C (EDL-write our image into the active `boot_b`) and Path B;
> see `g2-boot-test-20260929.md`.

## Recommendation

1. **Run Stage 0** of the test above once. It's an afternoon and it settles Path
   A definitively for the *G2's specific ABL build*, against the correct
   (RP5-parity) contract rather than the ESP-typed card we tried before.
2. ~~Check `fastboot boot`~~ — already known unavailable (see correction above).
3. **Regardless of the outcome, start task 1 (the sm8635/Cliffs ROCKNIX
   kernel).** It is required for *every* boot path — arm-efi, qcom-abl, or
   `fastboot boot` — so it is never wasted work and it is the long pole. Do not
   gate the kernel on the Path A result.
4. If Stage 0 fails, mark Path A **definitively** closed (this time against the
   production contract) and make Path B (qcom-abl / a Cliffs ABL, per
   `g2-boot-strategy-rocknix-abl-20260928.md`) the sole persistent-boot route.

## Sources
- `g2-path-a-closed-20260915.md` (the twice-tested negative), `g2-holodor-deep-dive-20260929.md`
  (the arm-efi contract), `g2-abl-source-findings.md` (QcomModulePkg, secure:no,
  ENABLE_BOOT_CMD gating), `g2-boot-strategy-rocknix-abl-20260928.md`,
  holodor `scripts/build-sd-image.sh` + `packages/pocknix-bootloader-sm8250/`.
