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

## Verified: Mike's boot backup (received 2026-09-17)

A community member (Mike) shared a `bootbackup.zip` (27 MB) containing full dumps
of `boot_a` and `boot_b`, each 100663296 B = 0x6000000, matching the G2's boot
partition size exactly. Verified locally (the binaries were NOT committed — they
are vendor firmware, kept off the public repo):

- **Genuine G2, not RP5.** `ANDROID!` magic; kernel `Linux 6.1.115-android14-11`
  (GKI); device fingerprint `...qti/pineapple/pineapple:14/...` (pineapple =
  this device's family) and the literal string `RPG2` in the kernel. The lone
  `qcom,pcie-sm8250` string is a generic GKI driver compatible, not the device
  SoC.
- **Older firmware than this device.** Fingerprint is Android **14**
  (`UKQ1.250213.001`); this device is Android **15** (`AQ3A.250226.002`). So it
  is a valid G2 boot image but not a byte-match for the current firmware —
  flashing it would pair a 14-era boot with a 15-era super/vendor and may not
  boot cleanly or may trip AVB.
- boot_a vs boot_b differ in only 4 of 24576 4K blocks (AVB metadata); same
  firmware, essentially the same kernel.

sha256:
```
boot_a  d81705719164dd1c27aa5e2d969bf009f7c1054dd8187897e15947f5e762c1f5
boot_b  a8ae97ec590234b0583990dd4fb764ce9eb84c49f0af7796cbc1dbb98c5777dc
```

Bearing on the fix: **none needed.** This device's boot_a/boot_b are intact (the
Tier-0 image was never written — the flash was refused), so the fix is
`setactiveslot b`, not a boot reflash. This backup is a last-resort fallback
only, and its version mismatch lowers even that value. The one still-required
item remains the loader `xbl_s_devprg_ns.melf`.
