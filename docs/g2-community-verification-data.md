# Verification data and corroboration from the G2 tech-support channel

Gathered from #retroid-pocket-g2-tech-support (2026-04 root/OTA threads). None
of it changes the fix for this device — that remains EDL + xbl_s_devprg_ns.melf
-> setactiveslot b — but two things are worth keeping.

## 1. Known-good factory init_boot hashes (for verification / fallback flash)

Posted by user ANG, sha256:

| Image | Version | sha256 |
|---|---|---|
| factory/init_boot_a.img | 1.0.0.164 | f1f4edbcd99ab0a8c9fe850e66cbfdf5f55b2ab55c25df08f2fbb6d527a9ba4b |
| factory/init_boot_patched_a.img | 164 (Magisk) | 72f8ffd24e6cc38c244ccb981d6c93302bc8e0af9800d0c449f27faa47a82566 |
| 176/init_boot_b.img | 1.0.0.176 | 70a93cd928e5228ea928bf51d1f0c0c2d341c997143027eed9107ece09b7e8bf |
| 176/init_boot_patched_b.img | 176 (Magisk) | 351850be7df8247e25a9adffbe7161d5a2ea163ebdb4ca87a53ea20e759f2dd8 |

This device is `ro.fota.version = 1.0.0.176`, so **the 176 hashes are the ones
that match it**. These are the reference to check any init_boot image against
before flashing, if a boot reflash ever becomes the fallback. They also confirm
that clean factory boot images for this exact version circulate in the community.

(A separate user, kamu, quoted the OTA updater's expected init_boot hash as
`E6E38F1BE35827EEF0A296E8BD328F4B3B3AB6BCDDCC16B8019725E78757872B` — that is the
hash the FOTA process wants, i.e. an unpatched init_boot. Noted for completeness;
not needed for the slot fix.)

## 2. Community corroboration of the ABL finding

User ANG: *"never seen a device come unlocked from factory but with flashing
disabled."*

That is exactly what `g2-abl-source-findings.md` established from the ABL source:
the G2 ships **unlocked but with `ENABLE_UPDATE_PARTITIONS_CMDS` not compiled**,
so `flash` / `erase` / `set_active` are absent from the bootloader's fastboot.
The community observed the symptom; the source explains the cause. It confirms,
independently, that **the bootloader's fastboot cannot fix this — only EDL can.**

## Not applicable to this device

- **o2pTweaks / The412Banner root+backup tools** run inside booted Android. This
  device does not boot Android, so they cannot be used here.
- The **`update error code=20`** threads are about OTA failing on Magisk-patched
  init_boot — a different problem from a wrong active slot.
- **Overclock files are explicitly flagged as bricking the G2** — never apply.
