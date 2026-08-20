# SG6275P / pineapple Platform and UEFI Research — 2026-08-20

## Scope

This document records additional public-source research into the G2's `pineapple` platform and Qualcomm UEFI/boot-chain sources. It intentionally separates confirmed facts from analogous-platform evidence.

## Confirmed G2 facts from the physical device

The G2 reports:

- model: Retroid Pocket G2
- device codename: `pineapple`
- hardware revision: `Qualcomm G2 Gen 2`
- Android 15
- boot slot: `_b`
- current Android boot device: `soc/1d84000.ufshc`
- AVB device state: `unlocked`
- verified boot state: `orange`
- external microSD: `mmcblk1` on `sdhci@8804000`
- SDHCI compatible: `qcom,sdhci-msm-v5`

These observations are from read-only ADB/Device Tree investigation.

## SG6275P platform identification

Public Geekbench system information identifies Retroid Pocket G2 as:

- processor: `QTI SG6275P`
- motherboard: `pineapple`

A third-party industry source describes SG6275P as based on the SM7675P/APQ family. This relationship is recorded only as a lead and is **not treated as sufficient proof that G2 can use another device's boot firmware**.

## Public pineapple kernel source

A public OnePlus Qualcomm kernel tree contains a `pineapple.bzl` build target and includes Qualcomm Pineapple-specific kernel modules such as:

- `drivers/mmc/host/sdhci-msm.ko`
- `drivers/pinctrl/qcom/pinctrl-pineapple.ko`
- `drivers/phy/qualcomm/phy-qcom-ufs-qmp-v4-pineapple.ko`
- Qualcomm Pineapple interconnect modules

This is useful evidence that `pineapple` is a Qualcomm platform family with an existing Linux kernel software base. It does **not** establish board-level compatibility with the Retroid Pocket G2.

## Public Qualcomm EDK2 / UEFI evidence

Public CodeLinaro Qualcomm EDK2 history contains Pineapple-specific firmware work and an `GetActiveSlot` change described as checking the UFS boot LUN. This is useful evidence that Qualcomm's UEFI/ABL stack contains explicit UFS/A-B boot handling.

It does **not** prove that a Retroid Pocket G2 factory UEFI exposes a microSD/Linux boot menu or searches a microSD EFI System Partition.

## Current architectural interpretation

The evidence currently supports this model:

```text
XBL / early Qualcomm firmware
        ↓
ABL / UEFI-related boot environment
        ↓
current Android boot selection
        ↓
internal UFS (confirmed)
```

Separately, the Android kernel can access:

```text
SDHCI @ 0x8804000
        ↓
MMC host mmc1
        ↓
mmcblk1
        ↓
external microSD
```

The remaining unknown is whether the early boot environment can open that SD controller and select an SD boot payload before Android is launched.

## Important negative finding

No public source found so far provides verified evidence that the **Retroid Pocket G2 factory ABL/UEFI** supports one of the following without modifying internal bootloader storage:

- SD/alternative boot menu
- SD EFI System Partition discovery
- direct Linux boot from microSD
- fallback from SD to internal UFS Android

Therefore the project must not assume the RP5 boot path works on G2 merely because `uefi_a/b` partitions exist.

## Comparison with RP5/RP6

RP5 remains the strongest precedent for the desired non-destructive architecture because its documented stock-ABL flow can select SD/alternative boot while Android remains internally installed.

RP6 is a useful example of the opposite case: a modified ROCKNIX ABL is used because the stock ABL does not provide the required SD Linux path.

Neither bootloader should be copied to G2.

## Next investigation target

The next useful evidence should be G2-specific and read-only:

1. Identify firmware/build metadata that reveals the exact platform/bootloader generation.
2. Look for G2-specific boot-chain strings or configuration files exposed by Android.
3. Determine whether the G2 image contains references to SD, EFI, alternative boot, or removable boot devices.
4. Compare the G2 `uefi_a/b` sizes and metadata with known Qualcomm UEFI layouts, without reading or writing partition contents unless separately reviewed.
5. Continue searching for G2-specific stock firmware and recovery artifacts.

## Safety decision

No conclusion from analogous Qualcomm or OnePlus sources authorizes flashing anything to the G2. The project remains microSD-first and non-destructive.