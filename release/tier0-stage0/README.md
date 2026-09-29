# Path A Stage 0 — microSD image

**Instructions:** `docs/g2-boot-test-20260929.md` (Test 1). No internal storage is written.

| File | Size | What |
|---|---|---|
| `g2-stage0-sd.img.xz` | 11.5 MB | 448 MiB card image; raw sha256 `31fab0318749d95fdff6393518e8894ae886addaf11fb6b35b67e339485fc07b` |

Write with balenaEtcher (takes the `.xz` directly) or Rufus in DD mode. Verify the
download with `sha256sum -c SHA256SUMS`.

## Layout (the RP5 production arm-efi contract)
| | |
|---|---|
| p1 | FAT32, GPT name `system`, attribute `legacy_boot`, type basic-data (**not** ESP), label `ROCKNIX`, PARTUUID `706f636b-6e69-7830-626f-6f7400000001` |
| p1 files | `/EFI/BOOT/bootaa64.efi` (GRUB 2.12 arm64-efi), `/boot/grub/grub.cfg` (= `boot/grub-stage0.cfg`), `/boot/grub/cliffs-g2.dtb`, `/KERNEL` |
| p2 | ext4, name + label `POCKNIX_ROOT`, PARTUUID `…726f-6f7400000002`, empty |

GRUB menu on screen = the factory ABL chainloads SD EFI in this shape (Path A reopened).

## Build provenance
| | |
|---|---|
| Kernel | linux v7.1 + `kernel/sm8635/patches/20-sm8635/0001-0004`, config `kernel/sm8635/config/linux.aarch64.conf` (storage drivers `=y`, `FB_SIMPLE=y`), `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`, target `Image` (52,857,344 B) |
| DTB | `dts/cliffs.dtsi` + `dts/cliffs-g2.dts` built in-tree (12,554 B; includes cmd-db, gcc/tlmm/icc/SMMU/regulators/SDCC2) |
| Builder | `scripts/build-g2-stage0-sd-image.sh` |
