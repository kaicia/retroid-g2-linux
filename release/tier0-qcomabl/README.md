# Tier 0 — ROCKNIX-ABL SD boot test for the Retroid Pocket G2

Procedure and background: `docs/g2-sd-boot-rocknix-abl-20260929.md`.

| File | What |
|---|---|
| `g2-qcomabl-sd.img.xz` | microSD image, qcom-abl contract: p1 FAT32 `system` (legacy_boot) with `KERNEL` + `KERNEL.md5`, p2 ext4 `POCKNIX_ROOT` (empty) |
| `KERNEL` | The same boot payload on its own: Android boot image header v0, gzip(Image 7.1) + `cliffs-g2.dtb` appended, empty cpio, cmdline `console=tty0 loglevel=8 ignore_loglevel` |
| `SHA256SUMS` | checksums |

Built by `scripts/build-g2-qcomabl-sd-image.sh` from the same kernel Image and
`cliffs-g2.dtb` (sha256 `a791c957…`) as `release/tier0-pathc/`.

Not included (download it yourself): the ABL, `abl_signed-SM8650.elf` from
ROCKNIX/abl release v1.1.9, sha256
`5ac42e28789ee61f278cc1de6fa95b90f04e2e4d4569f091a65bbf750dc100db`.
`scripts/check-abl-compat.py` passed against the G2's factory `abl_b` on
2026-09-29 (same ELF32 entry and LOAD address 0x9fa00000, MBN v7, fits 1 MiB).
