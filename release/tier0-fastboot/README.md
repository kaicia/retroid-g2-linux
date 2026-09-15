# Tier 0 boot image for `fastboot boot`

Replaces the SD-card artifacts in `../tier0/`, which are kept for the record but
no longer lead anywhere: the stock bootloader does not do removable-media EFI
boot (`docs/g2-path-a-closed-20260915.md`).

**Instructions:** `docs/g2-tier0-fastboot-windows.md`
**What it is and why:** `docs/g2-tier0-fastboot-plan-20260915.md`

Verify with `sha256sum -c SHA256SUMS`.

| File | Size | What |
|---|---|---|
| `g2-tier0-fastboot.zip` | 15 MB | contains `g2-tier0-fastboot.img`, 42,131,456 B |
| `cliffs-g2.dtb` | 6,501 B | the device tree inside that image, loose, for inspection |

## The image

Android boot image, **header version 2** — the last version that carries the
device tree inside the boot image rather than in `vendor_boot`.

| Section | Size | Load address |
|---|---|---|
| kernel | 42,113,536 | `0xa7008000` |
| ramdisk | 48 (empty initramfs) | `0xa8000000` |
| dtb | 6,501 | `0xa9000000` |

```
console=tty0 loglevel=8 ignore_loglevel panic=60
```

## Build provenance

| | |
|---|---|
| Kernel | unchanged from `../tier0/sd-files/KERNEL` — Linux `5225b8eec4c9` (7.3.0-rc2), `ARCH=arm64 LLVM=1 defconfig`, target `Image` |
| Device tree | `dts/cliffs.dtsi` + `dts/cliffs-g2.dts`, now with `/memory` and a `simple-framebuffer` |
| Packer | `scripts/mkbootimg-g2.py` |

The DTB here was compiled with `dtc` directly rather than inside a kernel tree,
using stub headers for the two macro families `cliffs.dtsi` includes
(`GIC_SPI`/`GIC_PPI` and `IRQ_TYPE_*`), with the same values the kernel's own
headers define. The `g2-sdhci-linux-dtc` workflow builds it in-tree and is the
authoritative check.

Reproduce:

```sh
python3 scripts/mkbootimg-g2.py \
    --kernel  ../tier0/sd-files/KERNEL \
    --dtb     cliffs-g2.dtb \
    --cmdline "console=tty0 loglevel=8 ignore_loglevel panic=60" \
    -o        g2-tier0-fastboot.img
```

## Safety

`fastboot boot` loads into RAM and jumps. No partition is written, the slot is
unchanged, the bootloader is unchanged. Power-cycle and Android returns.

The device tree contains no regulator nodes, so nothing can drive a power rail
to a wrong voltage.
