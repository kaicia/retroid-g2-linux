# G2 Boot-Chain Research — 2026-08-20

## Purpose

Continue the G2 investigation without modifying the device. This note separates public Qualcomm/Linux boot-chain information from G2-specific facts already measured on the device.

## Public Qualcomm/Linux evidence

Qualcomm's current Linux tooling documents both EFI/UKI-style boot images and DeviceTree handling. Qualcomm's `mkosi-qcom` documentation notes that UEFI may need the board DTB supplied separately when the UEFI implementation does not provide an upstream-compliant DeviceTree. Qualcomm's `kmake-image` project can package a kernel with a DTB into `efi.bin`, `dtb.bin`, or Android-style `boot.img`.

Qualcomm's public `host-signing-tool` documentation describes an EFI image containing `bootaa64.efi` and a Linux EFI kernel image, with a separate DTB image possible. This demonstrates that UEFI + EFI application + DTB is a real Qualcomm Linux boot architecture, but it does not prove that G2 uses this exact layout.

## RP5 comparison

Current Pocknix documentation explicitly states:

- RP5 is SM8250.
- Stock/factory ABL is sufficient.
- Stock ABL can boot pocknix directly via UEFI GRUB.
- The user switches ABL boot mode away from Android to SD/alternative boot.
- Android remains untouched on internal storage.

This is the closest documented precedent to the desired G2 architecture.

## RP6 comparison

Current Pocknix documentation explicitly states:

- RP6 is SM8550.
- Stock ABL cannot boot pocknix.
- ROCKNIX ABL must be installed first.
- SD boot is then selected through ABL.

This is deliberately NOT being treated as a procedure for G2. It is only a comparison point.

## G2-specific facts already established

Direct read-only investigation on the G2 established:

- Device codename: `pineapple`
- Snapdragon G2 Gen 2 platform identifier reported by the device: `SG6275P`
- Current Android boot device: `soc/1d84000.ufshc` (internal UFS)
- Current slot: `_b`
- External 1 TB microSD: `mmcblk1` / `mmcblk1p1`
- SDHCI node: `sdhci@8804000`
- SDHCI host: `mmc1`
- G2 exposes `uefi_a` / `uefi_b` and `uefisecapp_a` / `uefisecapp_b` partition nodes.

These facts establish that the G2 has an SD-capable kernel path and UEFI-named boot partitions, but they do not yet establish an SD-capable early boot path.

## Current technical hypothesis

The project should classify G2 into one of two architectures:

### A. Factory ABL SD boot

If the G2 factory ABL exposes an alternative/SD boot path, the desired architecture may be achievable without modifying internal bootloader partitions:

```text
Power on
  -> factory XBL/ABL/UEFI
  -> select SD/alternative boot
  -> microSD EFI/boot payload
  -> Linux/SteamOS
```

Android remains on internal UFS and can be selected again when SD boot is not requested.

### B. Factory ABL does not expose SD boot

If G2's factory boot chain does not support the required SD path, an internal bootloader modification might theoretically be required. This is considered high-risk and is OUTSIDE the current experimental plan.

No ABL/XBL/UEFI modification should be attempted until a verified G2 stock recovery package and a device-specific reversible recovery procedure are available.

## Important new insight

The presence of `uefi_a/b` makes an EFI-based Linux payload worth investigating, but it is not sufficient evidence that the factory firmware searches the microSD for an EFI System Partition. The exact G2 boot firmware behavior remains an open question.

Therefore the next investigation should focus on **non-invasive identification of G2 boot-chain metadata and public firmware/source artifacts**, rather than testing by flashing anything.

## Safety boundary

No changes to these areas during investigation:

- XBL
- ABL
- UEFI
- UEFISECAPP
- boot / init_boot / vendor_boot
- DTBO
- VBMETA
- GPT / partition table
- internal UFS

The target architecture remains SD-only experimentation with the original Android installation preserved.

## Next research targets

1. Find G2/SG6275P-specific kernel or DeviceTree source artifacts.
2. Determine whether G2's UEFI partition format is documented publicly.
3. Determine whether the factory ABL exposes an SD/alternative boot mode comparable to RP5.
4. Determine the expected EFI/DTB/boot image layout for the Qualcomm platform.
5. Compare the G2 SDHCI DT properties against any SG6275P Linux source that can be found.
6. Only after those questions are answered, design an SD-only boot image.
