# Tier 0 boot artifacts — prebuilt

Everything needed to try the first boot on the G2, already built. No toolchain,
no CI run. Verify with `sha256sum -c SHA256SUMS` from this directory.

Full instructions: `docs/g2-tier0-how-to-test.md` — or
`docs/g2-tier0-windows.md` if you are on Windows.
What this is and what success looks like: `docs/g2-tier0-boot-plan-20260915.md`.

## Contents

| File | Size | What |
|---|---|---|
| `g2-tier0-sd-files.zip` | 15 MB | the same four files as one zip — **easiest on Windows**, extracts straight onto the card |
| `sd-files/` | 43 MB | the four files loose, laid out exactly as they sit on the card |
| `g2-tier0-sd.img.xz` | 10.8 MB | the full 256 MiB card image, xz-compressed |

```
sd-files/
├── EFI/BOOT/BOOTAA64.EFI    GRUB for arm64-efi, built with grub-mkimage
├── boot/grub/grub.cfg       boot menu, three entries
├── cliffs-g2.dtb            Tier 0 device tree
└── KERNEL                   Linux 7.3.0-rc2 arm64 Image
```

## Build provenance

| | |
|---|---|
| Linux | `5225b8eec4c9bb21aecff6295fab6346a3c3738e` (7.3.0-rc2) |
| Config | `ARCH=arm64 LLVM=1 defconfig`, target `Image` |
| Device tree | `dts/cliffs.dtsi` + `dts/cliffs-g2.dts`, built in that same tree |
| GRUB | `grub-mkimage -O arm64-efi -p /boot/grub`, modules from `grub-efi-arm64-bin_2.12-5ubuntu11_arm64.deb` (sha256 `eb6ee260…`) |

Reproduce with `scripts/build-g2-dtb-compile-candidate.sh` and
`scripts/build-g2-tier0-sd-image.sh`, or re-run the `g2-tier0-image` workflow.

The kernel reports `7.3.0-rc2-g5225b8eec4c9-dirty`; the `-dirty` is only because
the build adds our DTS files to the kernel tree.

## Two ways to use these

**Copy the files** (no PC, nothing erased) — the card must be **FAT32**. Copy
everything under `sd-files/` to the card's root, keeping the structure. Cards
over 32 GB usually ship exFAT, which UEFI cannot read; reformat or use a smaller
one.

**Write the image** (erases the card, most faithful layout):

```sh
unxz -k g2-tier0-sd.img.xz
sudo dd if=g2-tier0-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```

`dd` overwrites whatever device you name. Check `/dev/sdX` against `lsblk`
first.

## Safety

Internal storage is never written to and no bootloader is flashed. The device
tree contains no regulator nodes, so nothing can drive a power rail to a wrong
voltage. Remove the card and the G2 is exactly as it was.
