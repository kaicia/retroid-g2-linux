# SD boot, re-investigated: how Armada does it, and the ROCKNIX SM8650 ABL — 2026-09-29

Question from the user after Path A closed: Armada runs SteamOS from the SD card
and leaves Android on internal storage. Isn't that done by swapping the
bootloader, with a menu to pick SD or internal?

Yes. That is exactly the mechanism, and re-reading it with the actual binaries in
hand changes our Path B assessment: **we may not need to build a Cliffs ABL at
all.**

## How Armada (and ROCKNIX, Batocera, Knulli, holodor…) boot from SD

Read from `armada-os/armada` (`abl/`) and `ROCKNIX/abl` (release v1.1.9):

1. The SD image carries `rocknix_abl/<SoC>/abl_signed-<SoC>.elf` plus three
   scripts: `backup_abl.sh`, `flash_abl.sh`, `restore_backup_abl.sh`.
2. From Android, as root, `backup_abl.sh` dumps `abl_a`/`abl_b`, then
   `flash_abl.sh` does `dd` of the ROCKNIX ABL into **`abl_a` and `abl_b`**.
   Nothing else on internal storage is written. Android (boot, vendor_boot,
   super, userdata) stays as it is.
3. Reboot holding **VOL-** → the ROCKNIX-ABL menu (VOL-/+ to move, POWER to
   select): set the device model, set the boot mode (Linux / Android), Start.
4. From then on the ABL boots Linux from SD (or internal, or USB) by default, and
   Android when chosen or when no Linux is present.

So the "choose SD or internal" behaviour is the replaced ABL. The factory ABL
never looks at the SD card, which is what our three Path A attempts showed.

### What the ROCKNIX ABL loads from the SD card
Strings from the decompressed LinuxLoader (`abl_signed-SM8650.elf`, LZMA FV at
0x2078):
- It scans FAT partitions for `\KERNEL`, `\boot.img`, `\kernel.img`,
  `\boot\Image` (also `cmdline.txt`, `cmdline-append.txt`).
- The payload is an Android boot image. pocknix/holodor `qcom-abl` builds it as
  `mkbootimg --header_version 0` of `gzip(Image)` with the DTBs appended, plus
  an empty cpio (`scripts/build-kernel.sh: assemble_bootimg`).
- It lists the `model` property of every appended DTB in a "Select your device
  model" menu (`ParseModelsFromDtb`, `ModelImageCb`). Linux will not boot until
  a model is set ("DEVICE MODEL NOT SET"). Our DTB has
  `model = "Retroid Pocket G2"`.
- It keeps the full Android path: boot_a/b, init_boot, vendor_boot, dtbo, AVB.
  It also has an "UNINSTALL CFW" option.
- The SD card layout is the one holodor already writes for `qcom-abl`:
  - GPT p1 FAT32, named `system`, holding `KERNEL`.
  - GPT p2 root.

## The key finding: the ABL builds are almost SoC-agnostic

ROCKNIX ships **one ABL per SoC family** (`abl_signed-SM4450/SM6115/SM8250/
SM8550/SM8650/SM8750.elf`), not per device. We decompressed each and diffed the
strings.

**SM8550 vs SM8650:** the only functional difference is a display-power
ExitBootServices callback and `androidboot.client_id`. Everything else is
identical, including:
- the menus and the SD / USB / FAT logic;
- the Android boot path;
- DTB selection by msm-id.

**SM8750 vs SM8550:** the strings are identical.

The ABL is an EFI application running on top of the device's own XBL/UEFI. All
hardware access goes through UEFI protocols that the device's firmware provides:
ChipInfo, PlatformInfo, display, block IO and USB.

This is why one SM8650 build serves two different vendors today: the AYANEO
Pocket S2 and the KONKR Pocket FIT (G3 Gen 3). The G3 Gen 3 is another
Snapdragon G-series gaming chip on the pineapple platform.

**The G2 is a pineapple-platform device.** The dump says
`ro.board.platform = pineapple` (`dumps/g2/g2-consolidated-hardware-*.txt`), and
Cliffs/SM8635 is the pineapple family's cut-down sibling. The natural candidate
is therefore the **existing `abl_signed-SM8650.elf`**, not a new build.

Container format of every ROCKNIX ABL:
- ELF32/ARM, entry and LOAD at `0x9fa00000`, 244 KiB.
- MBN hash-segment header **v7** (SM8250 is v6).
- Signed with **qtestsign "NOT SECURE"** test keys. That is fine here: the G2
  reports `secure:no`, and we have been running the unsigned-loader chain in
  EDL already.
- 258,048 bytes, which fits the G2's 1 MiB `abl` partition.

## What is still unknown, and how to settle each without risk

| Unknown | How it gets settled | Risk |
|---|---|---|
| Does the factory G2 ABL use the same load address (0x9fa00000) and MBN v7? | `scripts/check-abl-compat.py <factory abl_b.bin> abl_signed-SM8650.elf` on the PC, against the 2026-09-28 factory backup | none (reads files) |
| Does XBL accept and start the ROCKNIX ABL? | Flash `abl_b` only, via EDL. The ROCKNIX menu appears when holding VOL- | recoverable (EDL restore of `abl_b`) |
| Does Android still boot through it? | Choose Android in the menu | same |
| Does it boot our kernel from SD? | Card with `KERNEL` = header-v0 boot image with `cliffs-g2.dtb` appended | same |

Recovery is the same EDL write that restored the device on 2026-09-20, applied
to one 1 MiB partition:
```
python edl.py w abl_b <factory-backup>\lunN\abl_b.bin --loader=xbl_s_devprg_ns.melf --memory=UFS
```
Only the active slot's `abl_b` is written, never `abl_a`, and there is no slot
switching. Never run `fastboot set_active`. Armada writes both slots from Android
as root; we have no root, and EDL does the same job for one partition.

## Consequences for the plan

- **Path B changes from "build a Cliffs ABL from private source" to "try the
  public SM8650 ROCKNIX ABL".** This is the Armada route itself. If it runs, the
  whole ecosystem's boot contract applies to the G2 unchanged:
  - holodor's `qcom-abl` mode;
  - an SD card with `KERNEL` in a FAT partition named `system`;
  - Android kept intact.
- **Path C** (overwrite `boot_b`) becomes second choice. It would be a one-off
  test that leaves Android unbootable until restored. Path B, if it works, is the
  permanent dual-boot.
- The kernel side is unchanged. The profile moves from `BOOTLOADER=arm-efi`
  (dead) to `qcom-abl`. Only the packaging step differs: `assemble_bootimg`
  instead of the raw Image.

## Result 2026-09-29: compat check passed

The user ran `check-abl-compat.py` on the factory backup
(`backup_factory_20260928_001726\lun4\abl_b.bin`):
- factory ABL: ELF32 ARM, entry and LOAD `0x9fa00000..0x9fa39000` (228 KiB), MBN v7, 241,464 B;
- ROCKNIX SM8650: ELF32 ARM, entry and LOAD `0x9fa00000..0x9fa3d000` (244 KiB), MBN v7, 258,048 B;
- every check OK: *"all checks match the factory ABL"*.

One residual: the ROCKNIX image reaches 16 KiB further (to `0x9fa3d000`). The
same SM8650 build loads on two vendors' pineapple devices, so XBL's ABL window
is very likely at least that large. If it were not, the ABL would not start,
which is recoverable by the EDL restore below.

## Test 3 — ROCKNIX-ABL on `abl_b` (writes one 1 MiB partition)

Artifacts:
- `release/tier0-qcomabl/g2-qcomabl-sd.img.xz`, built by
  `scripts/build-g2-qcomabl-sd-image.sh`;
- `abl_signed-SM8650.elf` from ROCKNIX/abl v1.1.9.

1. Write `g2-qcomabl-sd.img.xz` to a spare microSD with Etcher, as in Test 1.
   Leave it **out** of the G2 for now.
2. Enter EDL (9008), then:
   ```
   python edl.py w abl_b abl_signed-SM8650.elf --loader=xbl_s_devprg_ns.melf --memory=UFS
   python edl.py reset --loader=xbl_s_devprg_ns.melf
   ```
   Only `abl_b`. Never touch `abl_a`, never switch slots, never run
   `fastboot set_active`.
3. **Check A (normal power-on):** does Android boot as usual? The factory Linux
   mode is off until chosen in the menu.
4. **Check B:** power off, then power on holding **VOL-**. Does the ROCKNIX-ABL
   menu appear? Navigate with VOL-/+ and select with POWER. Photograph it.
5. **Check C:** insert the card, open the menu again, and:
   - set the device model: "Retroid Pocket G2" should be listed, read from our
     DTB;
   - set the boot mode to Linux (SD);
   - select Start.

   Success is the kernel log on screen, ending at
   `VFS: Unable to mount root fs`, because there is no rootfs yet.
6. To use Android again: VOL- menu, set the boot mode to Android.

Results table:

| Seen | Meaning |
|---|---|
| Black screen or no boot at all | XBL did not start this ABL → restore below |
| Android boots, and the VOL- menu appears | **ABL works on the G2**: dual-boot mechanism in place |
| The menu shows no model / "DEVICE MODEL NOT SET" | payload/DTB parsing issue; photograph it |
| Kernel log on screen | **First kernel output. Tier 0 done** |
| Logo hang after Start, no log | kernel started without console, or early hang; photograph it |

**Restore** (EDL; the same method as the 2026-09-20 recovery):
```
python edl.py w abl_b backup_factory_20260928_001726\lun4\abl_b.bin --loader=xbl_s_devprg_ns.melf --memory=UFS
python edl.py reset --loader=xbl_s_devprg_ns.melf
```

## Next steps
1. ~~Compat check~~: passed, see above.
2. ~~Build the `qcom-abl` SD card, with KERNEL as a header-v0
   boot image of our 7.1.2 kernel and `cliffs-g2.dtb`.~~ Done:
   `release/tier0-qcomabl/`.
3. EDL-write `abl_b` only. Then:
   - Boot normally: Android should still start.
   - Reboot holding VOL-: the ROCKNIX menu should appear. Set the model to
     "Retroid Pocket G2" and boot Linux from the SD card.

## Sources
- `ROCKNIX/abl` README and `update.sh`; release `v1.1.9`
  (`rocknix-abl-v1.1.9.tar.gz`, SoC ELFs listed above).
- `armada-os/armada`: `abl/README` (install steps, SoC→device table),
  `abl/flash_abl.sh.template`, `abl/backup_abl.sh.template`, `abl/release.env`
  (ABL 1.1.8).
- pocknix-os `devices/sm8550/profile.conf` (qcom-abl SD contract),
  `scripts/build-kernel.sh` (`assemble_bootimg`).
- G2 facts: `dumps/g2/g2-consolidated-hardware-20260914-222623.txt`
  (`ro.board.platform=pineapple`), `g2-getvar-analysis-20260915.md` (abl 1 MiB,
  secure:no), `g2-EDL-recovery-runbook.md`.
