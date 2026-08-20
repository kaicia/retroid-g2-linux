# G2 vs RP5/RP6 SD Boot Chain Comparison

## Purpose

Compare the confirmed G2 observations with public RP5/RP6/Armada/Pocknix SD-boot implementations while keeping the G2 experiment non-invasive.

## 1. Confirmed G2 facts

From the Android Device Tree and read-only ADB investigation:

- SDHCI node: `/sys/firmware/devicetree/base/soc/sdhci@8804000`
- compatible: `qcom,sdhci-msm-v5`
- bus width: 4-bit
- SD pinctrl: `sdc2_on` / `sdc2_off`
- CLK: GPIO62
- CMD: GPIO51
- DATA: GPIO38, GPIO39, GPIO48, GPIO49
- card detect: GPIO31
- card-detect debounce: 1500 ms
- `vdd-supply`: RPMh LDO13
- `vdd-io-supply`: RPMh LDO23
- current Android boot device: `soc/1d84000.ufshc`
- current slot: `_b`
- A/B boot partition nodes include ABL, XBL, UEFI, boot, init_boot, vendor_boot, DTBO, VBMETA and recovery

These are direct observations. They do not yet prove that the G2 early boot firmware can boot Linux from SD.

## 2. Retroid Pocket 5 / SM8250 precedent

Public Pocknix documentation states that the SM8250 family, including Retroid Pocket 5, can boot Pocknix from microSD using the stock/factory ABL. The documented flow switches the stock ABL boot mode from Android to SD/alternative boot. Android remains on internal storage and the boot mode can be switched back.

This is the strongest precedent for the desired G2 architecture: Linux on removable SD while Android remains internally installed.

Source:
https://github.com/shuuri-labs/pocknix-os/blob/main/README.md

## 3. Retroid Pocket 6 / SM8550 precedent

Public Pocknix documentation states that the SM8550 family, including Retroid Pocket 6, differs from SM8250: the stock ABL cannot boot Pocknix, so a ROCKNIX ABL is required. Armada's current documentation likewise describes SD boot for RP6 and requires a matching ROCKNIX ABL.

This is technically useful as a precedent but is NOT a procedural template for G2. Both projects warn about the risk of incorrect bootloader changes, and our G2 plan deliberately excludes internal bootloader modification during the experimental phase.

Sources:
https://github.com/shuuri-labs/pocknix-os/blob/main/README.md
https://github.com/armada-os/armada/blob/main/README.md

## 4. The important architectural split

Existing Qualcomm handheld projects demonstrate two broad cases:

1. **Stock-ABL SD boot:** the factory ABL already exposes an SD/alternative boot path. RP5 is the documented example.
2. **Modified-ABL SD boot:** the factory ABL does not provide the required Linux SD boot path, so a ROCKNIX-derived ABL is installed. RP6/SM8550 is the documented example.

The G2 must first be classified into one of these categories.

## 5. G2 cannot be assumed to be RP6

The G2 reports hardware revision `Qualcomm G2 Gen 2` and device codename `pineapple`. Public hardware reporting identifies the G2 as using Snapdragon G2 Gen 2 with Adreno A22, rather than simply being another SM8550 RP6.

Therefore we must not copy RP6's ABL, DTB, kernel, GPIO assignments, or boot-image layout into G2 without establishing compatibility.

The exact Qualcomm platform identifier used by the G2 boot firmware still needs to be established from G2 evidence/firmware metadata.

## 6. What the current evidence means

We have now established both sides of the storage path:

```text
Current Android boot:
  boot properties -> 1d84000.ufshc -> internal UFS

External microSD:
  sdhci@8804000 -> mmc1 -> mmcblk1 -> mmcblk1p1 -> exFAT
```

Therefore the key remaining question is **not** whether the G2 can electrically/at-kernel level communicate with the SD card. It clearly can.

The key question is whether the **early boot chain** (XBL/ABL/UEFI and associated configuration) can select and load a Linux boot payload from the external SD interface while leaving the internal Android boot path untouched.

## 7. Why UEFI is particularly interesting

The G2 exposes `uefi_a` and `uefi_b` partition nodes. That is an important lead because RP5 Pocknix documentation explicitly describes SD boot through UEFI GRUB.

However, the mere existence of UEFI partitions does NOT prove that G2 uses UEFI in the same way as RP5. We need G2-specific evidence before making that connection.

## 8. Current project decision

Do **not** modify:

- XBL
- ABL
- UEFI
- boot / init_boot / vendor_boot
- DTBO
- VBMETA
- GPT / partition layout
- internal UFS

The experimental architecture remains:

```text
SD inserted
    -> early boot selects SD Linux payload
    -> Linux/SteamOS runs from SD

SD removed
    -> existing internal UFS Android path remains
    -> Android installation remains unchanged
```

## 9. Next investigation

1. Establish the exact G2 Qualcomm platform identifier.
2. Determine what the G2 factory ABL/UEFI actually supports for alternative/SD boot.
3. Inspect available G2 boot-chain metadata without modifying partitions.
4. Compare G2 boot-image and DTB requirements with Armada/ROCKNIX sources.
5. Identify a reversible SD-only test architecture.
6. Establish a verified stock recovery package before considering any future bootloader experiment.

## Sources consulted

- Armada: https://github.com/armada-os/armada
- Pocknix: https://github.com/shuuri-labs/pocknix-os
- RP5 dual-boot guide: https://github.com/amphyvi/rp5-dualboot
- RP5 postmarketOS example: https://github.com/zakusworo/retroidpocket-rp5-pmaports
