# Tier 0, attempt 1 — no GRUB menu, Android booted normally

**Date:** 2026-09-15
**Method:** `g2-tier0-sd-files.zip` extracted onto a Windows-formatted FAT32
microSD card, card inserted, device powered on.
**Result:** Android booted as normal. No GRUB menu, no change in behaviour.

This is the "No GRUB menu, Android boots normally" row of the observation
table in `g2-tier0-boot-plan-20260915.md`. The device is unaffected, as
predicted — nothing was written to internal storage.

## What this does and does not tell us

It tells us the stock boot chain did not run `\EFI\BOOT\BOOTAA64.EFI` off the
card. It does **not** yet tell us *why*, because two independent variables were
changed at once by using the file-copy route.

### Variable 1 — the card is not an EFI System Partition

Windows formats a microSD card as MBR with a FAT32 partition of type `0x0C`.
It has no GPT and no EFI System Partition type GUID
(`C12A7328-F81F-11D2-BA4B-00A0C93EC93B`).

Many UEFI implementations enumerate removable media for the fallback path only
on partitions carrying that ESP type GUID. If the G2's firmware is one of them,
a correctly-populated but wrongly-typed card is invisible to it.

`release/tier0/g2-tier0-sd.img.xz` was built specifically to remove this
variable: it is a full disk image with GPT and `sgdisk --typecode=1:ef00`
(see `scripts/build-g2-tier0-sd-image.sh:79`). Writing it to the card, rather
than copying files onto an existing filesystem, isolates variable 2.

### Variable 2 — whether stock ABL performs a removable-media boot at all

This is the fundamental unknown of Path A and it was always the risk.

Qualcomm's Android bootloader (`abl`) is a UEFI-derived application, but on a
shipping Android device its job is to locate and launch `boot.img` from the
active slot. A full UEFI Boot Device Selection pass that enumerates removable
media and looks for `\EFI\BOOT\BOOTAA64.EFI` is not something Android's ABL is
required to do, and on most devices it does not.

This is exactly why ROCKNIX and Armada replace `abl` with their own
EFI-capable build (our Path B). If variable 1 is eliminated and the card is
still ignored, Path A is closed on this device and the deferral of Path B in
`g2-decisions-20260914.md` has to be revisited.

## What is *not* the cause

The bootloader is already unlocked, so a signature refusal is not the
explanation. From the device dump:

```
[ro.boot.flash.locked]: [0]
[ro.boot.vbmeta.device_state]: [unlocked]
[ro.boot.verifiedbootstate]: [orange]
[ro.oem_unlock_supported]: [1]
```

An unsigned `BOOTAA64.EFI` being rejected by verified boot would be a plausible
story on a locked device. It is not the story here.

## Next steps, in order

1. **Write `g2-tier0-sd.img.xz` to the card** (image write, not file copy) and
   retry. Eliminates variable 1. Cheap, reversible, no device writes.
2. If still nothing: Path A is closed as designed. Two routes remain, and the
   next one to try is **not** Path B.
3. **`fastboot boot`** — the bootloader is unlocked, and `fastboot boot` loads
   a boot image into RAM and executes it **without writing any partition**.
   That satisfies our never-write-internal-storage rule as strictly as the SD
   card does, and it bypasses the EFI question entirely. It may be disabled in
   this ABL, in which case fastboot simply returns an error and nothing
   happens. Worth testing before committing to Path B.

   The device is on Android 15 with `init_boot_a`/`init_boot_b` present, so it
   is a GKI layout with boot header v4: the boot image carries the kernel
   alone, the ramdisk lives in `init_boot`, and the DTB lives in
   `vendor_boot`. A `fastboot boot` image for Tier 0 therefore has to be
   assembled deliberately rather than by dropping `Image` into a v2 header.
4. **Path B (ABL replacement)** stays the eventual route for a real
   SD-card distro, and stays blocked on the absence of a Cliffs ABL.
