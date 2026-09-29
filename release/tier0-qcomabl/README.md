# Tier 0 — ROCKNIX-ABL SD boot test for the Retroid Pocket G2

Procedure and background: `docs/g2-sd-boot-rocknix-abl-20260929.md`.

| File | What |
|---|---|
| `g2-qcomabl-sd.img.xz` | microSD image, qcom-abl contract: p1 FAT32 `system` (legacy_boot) with `KERNEL` + `KERNEL.md5`, p2 ext4 `POCKNIX_ROOT` (empty) |
| `KERNEL` | The same boot payload on its own: Android boot image header v0, gzip(Image 7.1) + `cliffs-g2.dtb` appended, empty cpio, cmdline `console=tty0 loglevel=8 ignore_loglevel` |
| `cliffs-g2.dtb` | the DTB inside `KERNEL` (rev 2) |
| `SHA256SUMS` | checksums |

Built by `scripts/build-g2-qcomabl-sd-image.sh` from the same kernel Image as
`release/tier0-pathc/`.

**Rev 2 (2026-09-29):** `cliffs-g2.dtb` (included here) is the pathc DTB with
exactly one change: the splash reservation node is renamed `splash@e3940000` →
`splash_region@e3940000`. ROCKNIX-ABL looks up `/reserved-memory/splash_region`
and powers the display off when the node is missing, which caused the black
screen seen with rev 1. The decompiled DTS differs from rev 1 in that line only.

To update an existing card, copy `KERNEL` over the one on its FAT partition. The
partition is visible in Windows. Also delete or replace `KERNEL.md5`; the new md5
is in the image.

Not included (download it yourself): the ABL, `abl_signed-SM8650.elf` from
ROCKNIX/abl release v1.1.9, sha256
`5ac42e28789ee61f278cc1de6fa95b90f04e2e4d4569f091a65bbf750dc100db`.
`scripts/check-abl-compat.py` passed against the G2's factory `abl_b` on
2026-09-29 (same ELF32 entry and LOAD address 0x9fa00000, MBN v7, fits 1 MiB).
