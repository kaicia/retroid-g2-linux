# Path C — boot image for EDL write into `boot_b`

**Instructions and restore steps:** `docs/g2-boot-test-20260929.md` (Test 2).
**This writes internal storage.** Only use it if you have decided to, with the
factory backup (containing `boot_b`) at hand.

| File | Size | What |
|---|---|---|
| `g2-pathc-boot.zip` | 16.2 MB | contains `g2-pathc-boot.img`, 52,883,456 B, sha256 `1d9a03dfadc00f7b9fafd9305ff06afdbc9b2c18d18b7c1cf57b77197dda8cbf` |
| `cliffs-g2.dtb` | 12,554 B | the device tree inside the image, loose, for inspection |

## The image
Android boot image **header v2** (DTB inside the boot image), packed by
`scripts/mkbootimg-g2.py`:

| Section | Size | Load address |
|---|---|---|
| kernel | 52,857,344 (effective 53,673,984) | `0xa7008000` |
| ramdisk | 48 (empty initramfs) | `0xaf000000` |
| dtb | 12,554 | `0xb0000000` |

cmdline: `console=tty0 loglevel=8 ignore_loglevel`. Fits `boot_b` (96 MiB).
Same kernel and DTB as `../tier0-stage0/`.
