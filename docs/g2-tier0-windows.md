# Tier 0 on Windows — download and copy to the SD card

The short version: download one zip, extract it onto a FAT32 microSD card,
put the card in the G2, power on.

Nothing is written to the G2's internal storage. Remove the card and Android
boots exactly as before.

## 1. Download

Open the repository on GitHub, branch `claude/content-analysis-04z778`, and go to
`release/tier0/`. Click **`g2-tier0-sd-files.zip`**, then the **Download raw
file** button (the ⬇ icon at the top right of the file view).

It is about 15 MB.

### Check it arrived intact (optional)

In Command Prompt or PowerShell, in your Downloads folder:

```
certutil -hashfile g2-tier0-sd-files.zip SHA256
```

It should print:

```
6df8f77f0ab8948fd704d2cc78d8d02b5b959114879d0ef04a4589b06fb65245
```

`certutil` ships with Windows; nothing to install.

## 2. Prepare the card

### The card must be FAT32

This is the one thing that commonly goes wrong. UEFI can read FAT32 and cannot
read exFAT or NTFS.

- **32 GB and under** — usually FAT32 already. Right-click the drive →
  **Properties** and look at "File system".
- **64 GB and over** — almost always exFAT. Windows' own Format dialog will not
  offer FAT32 at that size. Either use a smaller card (simplest), or format it
  with a tool that can, such as [Rufus](https://rufus.ie) (choose the drive,
  File system **FAT32 (Large)**, Start).

To format a ≤32 GB card in Windows: right-click the drive → **Format** → File
system **FAT32** → Start. This erases the card.

> A freshly bought card usually works as-is. Try it before reformatting
> anything.

### Extract the zip onto the card

1. Right-click `g2-tier0-sd-files.zip` → **Extract All…**
2. For the destination, browse to the card's **drive letter itself** — for
   example `E:\`, not a folder inside it.
3. Extract.

When it finishes the card should look exactly like this:

```
E:\
├── EFI\
│   └── BOOT\
│       └── BOOTAA64.EFI
├── boot\
│   └── grub\
│       └── grub.cfg
├── cliffs-g2.dtb
└── KERNEL
```

Check `EFI\BOOT\BOOTAA64.EFI` really is at that path and not nested inside an
extra `g2-tier0-sd-files\` folder — Extract All sometimes adds one. If it did,
move the four items up to the root of the drive.

Anything already on the card is left alone; this only adds files.

4. Eject the card properly: click the tray icon → **Eject**, then remove it.
   Pulling it out without ejecting can leave the files half-written.

## 3. Run the test

1. Power the G2 **fully off** — hold power, choose Power off. Sleep is not
   enough.
2. Insert the microSD card.
3. Power on normally.
4. Watch the screen from the first second, with a camera ready.

Within a few seconds you should see a **GRUB menu** with three entries and a
5-second countdown. Let the first entry run, or select it and press A.

## 4. What you should see

A wall of kernel text ending in something like:

```
VFS: Unable to mount root fs on unknown-block(0,0)
Kernel panic - not syncing: No working init found.
```

**That panic is the goal.** There is deliberately no root filesystem yet.
Reaching it proves the bootloader handed off, the device tree was accepted, the
CPUs and timer started, and the console works. It stays on screen for a minute.

A photo of the last screenful is a perfectly good result to send back.

| What you see | What it means |
|---|---|
| GRUB menu appears | **the big unknown is answered** — the stock bootloader boots from the card |
| Kernel text, then the root-filesystem panic | **Tier 0 complete** |
| GRUB menu, then black on every entry | kernel not starting; say which entries you tried |
| No menu, Android boots normally | the firmware did not take the card — try §5 |

If the first menu entry shows nothing, try the third ("framebuffer console
only"). If that one shows text and the first does not, that is useful
information rather than a failure — it means the debug UART is not physically
reachable and the display is the console.

## 5. If no GRUB menu appears

In order:

1. **Check the paths on the card** — especially `EFI\BOOT\BOOTAA64.EFI` in
   capitals, and that nothing is nested in an extra folder.
2. **Confirm the card is FAT32**, not exFAT.
3. **Try a smaller card**, 32 GB or under, freshly formatted FAT32.
4. **Write the full disk image instead.** Some firmware only boots a partition
   explicitly typed as an EFI System Partition, which the image provides and a
   plain formatted card does not:
   - download `release/tier0/g2-tier0-sd.img.xz` (about 11 MB)
   - write it with [balenaEtcher](https://etcher.balena.io) or
     [Raspberry Pi Imager](https://www.raspberrypi.com/software/) — both read
     `.xz` directly, so there is nothing to unpack. In Pi Imager choose
     **Use custom image**.
   - this **erases the card**

If Android keeps booting normally with the card in after all of that, the
finding is that the G2's stock bootloader does not run the removable-media
fallback. That is a real result: it closes out Path A and leaves Path B, the
bootloader swap, as the remaining route
(`docs/g2-decisions-20260914.md` §1). Worth reporting either way.

## 6. Safety

- Nothing is written to the G2's internal storage, and no bootloader is flashed.
- The device tree has no regulator nodes, so no power rail can be driven to a
  wrong voltage — the one way a bad device tree can damage hardware.
- If the kernel hangs, hold power until the device restarts.
- Remove the card and the G2 is exactly as it was.

The only step that can destroy data is formatting the card or writing the disk
image, and only on the card.
