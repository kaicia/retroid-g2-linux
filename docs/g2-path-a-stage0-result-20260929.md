# Path A Stage 0 result — Android booted. Path A is closed for good — 2026-09-29

Test 1 of `g2-boot-test-20260929.md`: `release/tier0-stage0/g2-stage0-sd.img.xz`
written to a microSD, card inserted, G2 powered on normally.

**Result: Android booted as usual. No GRUB menu.**

That card reproduced the RP5's *production* arm-efi contract exactly (p1 FAT32
named `system`, `legacy_boot` attribute, basic-data type, label `ROCKNIX`,
`/EFI/BOOT/bootaa64.efi`; p2 ext4), i.e. the one untested variable left by
`g2-path-a-closed-20260915.md`. Combined with the two 2026-09-15 attempts
(MBR FAT32; GPT ESP-typed), the G2's factory ABL has now ignored removable-media
EFI in every shape that is known to work on another Qualcomm handheld.

Conclusion: **the G2's stock ABL does not chainload EFI from SD at all.** The
RP5's ABL does; Retroid did not carry that into the G2 build. `arm-efi` is not a
viable `BOOTLOADER` for sm8635.

## Remaining routes
| Route | Writes internal storage | Status |
|---|---|---|
| Path A (SD EFI) | no | **Closed** (3 attempts) |
| `fastboot boot` | no | Closed (`unknown command`, 2026-09-15) |
| **Path C** — our v2 boot image EDL-written into active `boot_b` | yes (`boot_b` only; restorable from backup) | **Next**, user's decision — `g2-boot-test-20260929.md` Test 2 |
| Path B — replace ABL | yes (`abl_b` only) | **Update same day:** try the public ROCKNIX `abl_signed-SM8650.elf` first — see `g2-sd-boot-rocknix-abl-20260929.md` |

Every route that avoids writing internal storage is now exhausted. The
`BOOTLOADER=arm-efi` placeholder in `kernel/sm8635/profile.conf` is marked
undecided until Path C reports.
