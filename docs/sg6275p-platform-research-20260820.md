# Snapdragon G2 Gen 2 / SG6275P Platform Research

Date: 2026-08-20

## Purpose

Establish the G2 platform identity and identify the safest next research path for a microSD-only Linux/SteamOS port.

## Confirmed G2 identity

The G2 Android device reports:

- Model: Retroid Pocket G2
- Device codename: `pineapple`
- Android: 15
- Build fingerprint: `qti/pineapple/pineapple:15/AQ3A.250226.002/eng.RPG2.20260123.180002:user/dev-keys`
- Kernel: `6.1.115-android14-11-maybe-dirty`

The platform is Snapdragon G2 Gen 2 / Qualcomm SG6275P, with Adreno A22.

This means G2 must be treated as its own Qualcomm platform. RP6/SM8550 boot images, DTBs, kernels, or ABLs must not be assumed compatible.

## Storage / boot evidence already collected

Current Android boot uses the internal UFS controller:

`/sys/devices/platform/soc/1d84000.ufshc`

The external microSD is independently detected by the SDHCI controller:

`/sys/firmware/devicetree/base/soc/sdhci@8804000`

The Android kernel exposes:

`mmc1 -> mmcblk1 -> mmcblk1p1`

The installed 1-TB microSD was observed as an SD device and mounted through Android's storage stack as exFAT.

The G2 also exposes internal A/B boot-chain partitions including:

- xbl_a / xbl_b
- abl_a / abl_b
- uefi_a / uefi_b
- uefisecapp_a / uefisecapp_b
- boot_a / boot_b
- init_boot_a / init_boot_b
- vendor_boot_a / vendor_boot_b
- dtbo_a / dtbo_b
- vbmeta_a / vbmeta_b
- recovery_a / recovery_b

These observations are read-only evidence and do not prove that factory firmware can boot Linux from SD.

## External research

The public Retroid GitHub organization currently exposes Linux-related repositories, including a Linux kernel tree, Batocera Linux, U-Boot for the SM8250 family, and build infrastructure. These are useful references, but the SM8250-specific U-Boot repository must not be treated as a G2 bootloader source without platform compatibility evidence.

Public Pocknix documentation provides an important RP5 precedent where stock ABL can select a microSD Linux boot path. RP6/SM8550 uses a different bootloader approach. Neither precedent proves the equivalent behavior on SG6275P.

## Current hypothesis

The investigation should determine whether SG6275P factory XBL/ABL/UEFI has an existing removable-media boot path.

Preferred architecture:

```text
microSD inserted
    -> factory early boot selects SD Linux payload
    -> Linux/SteamOS runs entirely from microSD

microSD removed
    -> factory internal-UFS Android boot path remains unchanged
    -> Android remains usable exactly as before
```

## Safety boundary

No internal storage or boot partition should be modified during the investigation.

Do not write to:

- XBL
- ABL
- UEFI
- boot
- init_boot
- vendor_boot
- DTBO
- VBMETA
- GPT
- internal UFS

Any future bootloader experiment requires a verified stock recovery package and a reversible recovery procedure first.

## Next research targets

1. Find SG6275P/pineapple kernel and device-tree sources.
2. Identify the Qualcomm platform identifier used by the factory boot firmware.
3. Determine whether G2 UEFI partitions are actually used in the Android boot path and what role they perform.
4. Search Armada/Pocknix and other Qualcomm handheld projects for SG6275P or closely related platform support.
5. Determine the expected SD boot payload format without writing anything to the G2.
6. Only after the above is established, design an SD-only boot test.
