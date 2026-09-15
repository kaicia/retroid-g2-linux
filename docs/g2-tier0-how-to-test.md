# Tier 0 — how to run the test on the device

Step by step. The whole test is: put four files on a microSD card, insert it,
power on, look at the screen.

**Nothing is written to the G2's internal storage.** No bootloader is flashed,
no partition is touched. If anything goes wrong the fix is to remove the card —
Android boots exactly as before.

## 1. Get the files

**They are already built and committed** — `release/tier0/`. Nothing to compile
and no CI run needed.

If you already have the repository cloned (for example in Termux), this is the
whole step:

```sh
cd ~/retroid-g2-linux
git pull
ls release/tier0/sd-files
```

Otherwise download them from the repository's web view, or clone it.

| Path | Size | For |
|---|---|---|
| `release/tier0/sd-files/` | 43 MB | Route B — the four files, already in the card's layout |
| `release/tier0/g2-tier0-sd.img.xz` | 10.8 MB | Route A — the full card image, compressed |

Check they arrived intact:

```sh
cd release/tier0 && sha256sum -c SHA256SUMS
```

`release/tier0/README.md` records exactly what was built and from which
revisions. Rebuilding is still possible — `scripts/build-g2-tier0-sd-image.sh`,
or the manual `g2-tier0-image` workflow — but it is no longer necessary.

## 2. Prepare the card

Either route produces the same result. Route B needs no PC.

### Route B — copy files onto a FAT32 card (easiest)

Works with any microSD card that is **formatted FAT32**.

> Cards of 32 GB and under are usually FAT32 from the factory. 64 GB and larger
> are usually **exFAT**, which UEFI cannot read — those must be reformatted to
> FAT32 first. Windows will not offer FAT32 above 32 GB; use a tool that does,
> or a smaller card. It is worth starting with a small card for this reason.

Copy the contents of `release/tier0/sd-files/` to the **root** of the card,
keeping the directory structure exactly:

```
<card root>/
├── EFI/
│   └── BOOT/
│       └── BOOTAA64.EFI
├── boot/
│   └── grub/
│       └── grub.cfg
├── cliffs-g2.dtb
└── KERNEL
```

Case matters on some firmware. `EFI/BOOT/BOOTAA64.EFI` in capitals is the
safest spelling.

You can do the copy any way you like — a card reader on a PC, the card in your
phone, or straight onto the card while it sits in the G2:

```sh
# from Termux, with the G2 connected and the card mounted in it
cd ~/retroid-g2-linux/release/tier0/sd-files
CARD=/storage/XXXX-XXXX          # <- your card, from `termux-adb shell ls /storage`

termux-adb shell "mkdir -p $CARD/EFI/BOOT $CARD/boot/grub"
termux-adb push EFI/BOOT/BOOTAA64.EFI "$CARD/EFI/BOOT/BOOTAA64.EFI"
termux-adb push boot/grub/grub.cfg    "$CARD/boot/grub/grub.cfg"
termux-adb push cliffs-g2.dtb         "$CARD/cliffs-g2.dtb"
termux-adb push KERNEL                "$CARD/KERNEL"
```

Beware: on Android `/sdcard` is usually **internal** storage, not the card. The
external card is normally under `/storage/XXXX-XXXX`. Check with
`termux-adb shell ls /storage` and use the path that is not `emulated` or
`self`. Getting this wrong only wastes 42 MB of internal space — it breaks
nothing — but the test will not work until the files are on the card.

Existing files on the card are untouched; this only adds.

### Route A — write the full image (most faithful)

Use this if Route B produces no GRUB menu, or if you would rather have the exact
partition layout that was tested. **It erases the whole card.**

On a Linux PC:

```sh
unxz -k release/tier0/g2-tier0-sd.img.xz
lsblk                      # find the card — check the SIZE column carefully
sudo dd if=release/tier0/g2-tier0-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

`dd` overwrites whatever device you name, without asking. Confirm `/dev/sdX` is
the card and not your system disk. On Windows or macOS, Raspberry Pi Imager
("Use custom image") or balenaEtcher will write the same `.img` safely.

The difference from Route B: the image carries a GPT with the partition marked
as an EFI System Partition. Some firmware only looks at properly typed ESPs.

## 3. Run the test

1. Power the G2 **fully off** — hold power, choose Power off. Not just sleep.
2. Insert the microSD card.
3. Power on normally.
4. Watch the screen from the first second.

Expected within a few seconds: a **GRUB menu** with three entries and a 5-second
countdown. If it appears, the most important question in this project is already
answered. Let the first entry run, or select it with the d-pad and press A or
Start.

Have a camera ready. Text may only be on screen briefly, and a photo of a kernel
log is a perfectly good result to send back.

## 4. Reading the result

| What you see | What it means | What to send back |
|---|---|---|
| GRUB menu appears | **The factory bootloader boots from the card.** Path A works | a photo, then pick entry 1 |
| Then a wall of kernel text ending in a panic about the root filesystem | **Tier 0 complete** — the kernel ran on the G2 | a photo of the last screenful |
| GRUB menu, then a black screen on every entry | the kernel is not starting, or dies before any console | say which entries you tried |
| No GRUB menu, Android boots normally | the firmware did not take the card | try Route A if you used B; otherwise this is a real finding |
| No GRUB menu and the device does not boot at all | remove the card and power on again | tell me — I do not expect this |

The panic text looks roughly like:

```
VFS: Unable to mount root fs on unknown-block(0,0)
Kernel panic - not syncing: No working init found.
```

**That panic is success.** There is no root filesystem on the card yet, on
purpose. Reaching the panic proves the firmware handed off, the device tree was
accepted, the CPUs and timer came up, and the console works. `panic=60` holds it
on screen for a minute before rebooting.

### The three menu entries

They exist so that even a blank screen narrows things down.

| Entry | Purpose |
|---|---|
| 1 — earlycon via stdout-path + framebuffer | the normal one; log goes to both the debug UART and the screen |
| 2 — earlycon at an explicit address | same, but names the UART directly in case the device-tree lookup fails |
| 3 — framebuffer only | separates "the kernel never started" from "the kernel started but the UART is unreachable" |

If entry 1 shows nothing, try 3. If 3 shows kernel text and 1 does not, that is
useful information, not a failure.

## 5. If nothing happens

Try in this order:

1. **Try the other entries** — the menu stays up until you choose.
2. **Route A instead of Route B** — some firmware only boots properly typed ESPs.
3. **A different card** — preferably 32 GB or smaller, freshly FAT32.
4. **Check the file paths** on the card, especially `EFI/BOOT/BOOTAA64.EFI` in
   capitals and `boot/grub/grub.cfg`.

If Android boots normally every time with the card in, the finding is that the
G2's factory bootloader does not run the removable-media fallback. That closes
out Path A and makes Path B — the ROCKNIX-style bootloader swap — the remaining
route (`docs/g2-decisions-20260914.md` §1). That is a real result and worth
recording either way.

## 6. Safety

- The G2's internal storage is never written to. No `dd` to internal partitions,
  no `fastboot flash`, no bootloader change.
- The device tree contains **no regulator nodes**, so nothing can drive a power
  rail to a wrong voltage — the one way a bad DTS can damage hardware.
- A kernel that hangs is recovered by holding power until the device restarts.
- Remove the card and the G2 is exactly as it was.

The only genuinely dangerous command in this whole procedure is the `dd` in
Route A, and only because of the device name you give it.
