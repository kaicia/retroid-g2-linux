# G2 vs RP5/RP6 SD Boot Chain Comparison

## Purpose

This note records what can be established without connecting the Retroid Pocket G2. It separates confirmed G2 hardware observations from public documentation for other devices.

## 1. Confirmed G2 facts

From the Android Device Tree dump already collected from the G2:

- SDHCI node: `/sys/firmware/devicetree/base/soc/sdhci@8804000`
- compatible: `qcom,sdhci-msm-v5`
- bus width: 4-bit
- SD pinctrl state: `sdc2_on` / `sdc2_off`
- CLK: GPIO62
- CMD: GPIO51
- DATA: GPIO38, GPIO39, GPIO48, GPIO49
- card detect: GPIO31
- card-detect debounce: 1500 ms
- `pinctrl-0` = `sdc2_on`
- `pinctrl-1` = `sdc2_off`
- `vdd-supply` resolves to RPMh LDO13
- `vdd-io-supply` resolves to RPMh LDO23

These are direct observations and do not yet prove that the G2 bootloader can boot Linux from the SD card.

## 2. Retroid Pocket 5 / SM8250 precedent

Public Pocknix documentation states that the SM8250 family (including Retroid Pocket 5) can boot from a microSD using the stock/factory ABL. The documented flow is to enter the stock ABL menu and switch the boot mode from Android to SD/alternative boot. Android remains on internal storage and the boot mode can be switched back.

This is the strongest precedent for the project's desired model: Linux on removable SD while retaining Android internally.

Source:
https://github.com/shuuri-labs/pocknix-os/blob/main/README.md

## 3. Retroid Pocket 6 / SM8550 precedent

Public Pocknix documentation states that the SM8550 family (including Retroid Pocket 6) differs from SM8250: the stock ABL cannot boot Pocknix, so the ROCKNIX ABL is required. The SD image contains the ABL installation kit, and after the ABL is provisioned the ABL menu is used to select the device/boot mode and the system can boot from SD.

Armada's current device table lists Retroid Pocket 6 as SM8550 and tested. Armada's README likewise describes SD boot and the ROCKNIX ABL requirement.

Sources:
https://github.com/shuuri-labs/pocknix-os/blob/main/README.md
https://github.com/armada-os/armada/blob/main/README.md
https://github.com/armada-os/armada/blob/main/abl/README

## 4. What this means for G2

The existence of working RP5 and RP6 SD-boot implementations is important, but they do NOT establish the G2 boot path.

The key unknown is now the G2 boot chain, not the basic existence of an SD controller. We already know the G2 Android kernel has a functioning Qualcomm SDHCI controller and SD card pinctrl configuration. The next question is whether the G2's ABL/boot firmware can select and load a boot image from the external SD interface, and what format/path it expects.

## 5. Important distinction

Do not assume:

- G2 uses the same ABL as RP5 or RP6.
- G2 uses the same GPIO numbers.
- G2 accepts the same DTB/boot image layout.
- A Linux kernel that works on RP6 will boot on G2 without a G2-specific DTB and board support.

GPIO values are board-specific. The useful comparison is the architecture of the SDHCI node, pinctrl, regulators, kernel driver support, boot image layout, and ABL behavior.

## 6. Armada-specific finding

Armada is a Fedora bootc-based SteamOS-like ARM distribution and explicitly supports SD-card boot. Its current device configuration contains a dedicated `retroid-pocket-6.conf` identifying RP6 as SM8550.

The Armada ABL documentation is particularly relevant because it describes a ROCKNIX ABL provisioning flow and warns that the ABL must match the SoC.

## 7. Next G2 investigation when ADB is available

The next G2 session should focus on evidence that cannot be obtained from the current SDHCI DT dump alone:

1. Identify the G2 SoC and exact boot/ABL environment again.
2. Inspect boot-related partitions and available boot metadata without modifying anything.
3. Determine whether the stock ABL exposes an SD/alternative/Linux boot mode.
4. Determine whether the G2 boot chain uses the same general mechanism as RP5, RP6, or neither.
5. Only after the boot path is understood, compare the required Linux DTB/kernel pieces with Armada/ROCKNIX.

## Current conclusion

The project is technically plausible because both SM8250/RP5 and SM8550/RP6 have demonstrated removable-SD Linux boot paths. However, G2 support still requires its own boot-chain and board-specific investigation. The G2 SDHCI evidence collected so far is sufficient to begin kernel/DT comparison, but not sufficient to justify flashing or changing the G2 bootloader.
