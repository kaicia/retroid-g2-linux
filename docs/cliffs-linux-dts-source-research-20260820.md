# Cliffs / CliffsP Linux DTS Source Research

Date: 2026-08-20

## G2 evidence

The G2 Android Device Tree collected from the running device identifies the board as:

- model: `Qualcomm Technologies, Inc. Cliffs MTP`
- compatible: `qcom,cliffs-mtp`, `qcom,cliffs`, `qcom,cliffsp-mtp`, `qcom,cliffsp`, `qcom,mtp`
- SDHCI node: `sdhci@8804000`
- SDHCI compatible: `qcom,sdhci-msm-v5`

These values are direct observations from the G2 DT dumps already stored under `dumps/g2/`.

## Public Cliffs DT sources found

GitHub search found multiple public Cliffs/CliffsP device-tree repositories/files, including:

- LineageOS `android_kernel_qcom_sm8650-devicetrees`: `qcom/cliffs-mtp-peach.dtsi`, `qcom/cliffs-mtp-overlay.dts`, and PM8550B variants.
- OnePlusOSS `android_kernel_modules_and_devicetree_oneplus_sm7675`: `kernel_platform/qcom/proprietary/devicetree/qcom/cliffs-mtp-overlay.dts` and PM8550B overlay.
- TsubakiDev `device_oneplus_pineapple`: Cliffs MTP overlay files.
- Nubia SM8650 device-tree repositories: Cliffs MTP/Peach/Kiwi variants.

The LineageOS `cliffs-mtp-peach.dtsi` currently observed includes `cliffs-mtp.dtsi` and changes an `S3E` regulator voltage range. This demonstrates that reusable Cliffs platform DTS sources exist, but it is NOT evidence that the Peach board DTS can be used unchanged on the Retroid G2.

## SDHCI reference

A public decompiled Qualcomm/Pineapple-family DTS found on GitHub contains an `sdhci@8804000` node with the same broad structure seen on G2, including:

- `compatible = "qcom,sdhci-msm-v5"`
- `reg = <0x8804000 0x1000>`
- `interrupts` / interrupt names
- `bus-width = <4>`
- `qcom,restore-after-cx-collapse`
- `clocks` / `clock-names`
- `qcom,dll-hsr-list`
- `iommus`
- `interconnects`
- `operating-points-v2`
- `vdd-supply`

This is useful as a structural reference only. Phandles, clocks, regulators, interrupts and board-specific pinctrl must be resolved against the G2 platform before use.

## Important limitation

A search of the public `qualcomm-linux/kernel` repository did not return `qcom,cliffs` or `sdhci@8804000` matches through the available GitHub code-search interface. Therefore there is currently no basis to claim that an upstream Linux Cliffs board DTS already exists in that repository.

## Engineering conclusion

The G2 Linux DT does not need to be invented from zero: public Cliffs/CliffsP DTS material exists and provides platform-level references. However, no existing public file identified so far is proven to be the Retroid Pocket G2 board DTS.

The next safe task is a **static comparison** between:

1. G2 Android DT values already collected;
2. public Cliffs/CliffsP DTS;
3. Linux `sdhci-msm` DT binding requirements.

Unknown values must remain explicitly marked `UNKNOWN`; do not guess them and do not create a bootable DTB yet.

## Safety status

This research does not require changing the G2's UFS, ABL, UEFI, boot, vbmeta or slot state. No flashing or boot modification is authorized by this document.
