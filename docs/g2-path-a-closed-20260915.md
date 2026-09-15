# Path A is closed

**Date:** 2026-09-15

Two attempts, both ending with Android booting normally and no GRUB menu:

| Attempt | Card preparation | Result |
|---|---|---|
| 1 | `g2-tier0-sd-files.zip` extracted onto a Windows-formatted FAT32 card (MBR, partition type `0x0C`) | Android booted, no menu |
| 2 | `g2-tier0-sd.img.xz` written to the card as a whole-disk image (GPT, one partition, type GUID `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`) | Android booted, no menu |

Attempt 2 removes the only benign explanation for attempt 1. The card was a
textbook EFI System Partition, with `\EFI\BOOT\BOOTAA64.EFI` present at the
exact fallback path the UEFI specification defines for removable media, and the
firmware still went straight to the boot partition.

**The stock G2 bootloader does not perform a removable-media EFI boot.** Path A
as described in `g2-decisions-20260914.md` §1 is dead. Not misconfigured, not
nearly-working: the mechanism it depends on is not present.

## This was the expected failure mode, not a surprise

Qualcomm's `abl` is UEFI-derived, which is what made Path A worth trying at all,
but on a shipping Android device its job is to locate and launch `boot.img` from
the active slot. A full Boot Device Selection pass - enumerate removable media,
look for the fallback loader, run it - is something Android's ABL is not
required to do and, on the evidence here, does not do.

This is also why every project we looked at that reached this goal replaced
`abl` rather than booting alongside it. ROCKNIX and Armada both ship their own
EFI-capable bootloader. `g2-reference-projects-review-20260914.md` recorded that
as their approach; it now reads as the only approach.

## Ruled out, so the record is unambiguous

- **Not a lock.** `ro.boot.flash.locked=0`, `ro.boot.vbmeta.device_state=unlocked`,
  `ro.boot.verifiedbootstate=orange`. The bootloader is unlocked and an unsigned
  EFI binary would not have been refused on those grounds.
- **Not the filesystem.** FAT32 in both attempts, and attempt 2's was created by
  `mkfs.vfat -F 32`.
- **Not the partition type.** Attempt 2 carried the ESP type GUID.
- **Not the payload.** `BOOTAA64.EFI`, `grub.cfg`, `KERNEL` and `cliffs-g2.dtb`
  were verified byte-identical to their sources after extraction, and the image
  was verified to decompress to the expected sha256.

## What replaces it

`fastboot boot`. The bootloader is unlocked, and `fastboot boot` loads a boot
image into RAM and jumps to it **without writing any partition**. That keeps the
never-write-internal-storage rule exactly as intact as the SD card did, and it
sidesteps the EFI question completely: ABL's Android boot path is the one thing
we know for certain this bootloader implements, because it is how the device
starts every day.

Path B (replacing `abl`) remains the eventual route to a real SD-card distro and
remains blocked on the absence of a Cliffs ABL. It is now the only *long-term*
route, which raises its priority - but it is still the wrong thing to attempt
before we have ever seen this kernel produce a single line of output.

See `g2-tier0-fastboot-plan-20260915.md`.
