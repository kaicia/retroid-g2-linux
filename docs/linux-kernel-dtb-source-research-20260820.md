# G2 Linux Kernel / DTB Source Research — 2026-08-20

## Scope

Research whether public Linux kernel and device-tree sources exist that can serve as a foundation for Retroid Pocket G2 Linux work.

## Confirmed G2 runtime identity

From direct Android ADB investigation:

- Model: Retroid Pocket G2
- Device codename: pineapple
- Android: 15
- Build ID: AQ3A.250226.002
- Kernel: 6.1.115-android14-11
- Architecture: aarch64
- SDHCI: `/sys/firmware/devicetree/base/soc/sdhci@8804000`
- SDHCI compatible: `qcom,sdhci-msm-v5`

## Public-source findings

### RetroidPocket GitHub organization

The RetroidPocket GitHub organization publicly exposes Linux-related repositories, including a fork of the Linux kernel and a U-Boot source tree. The U-Boot repository is explicitly described as an SM8250 / Retroid Pocket source tree, so it is useful as a reference for the RP5 generation, but it is not evidence that it applies to G2.

### Pocknix / RP5 and RP6

The public pocknix-os documentation distinguishes the two Qualcomm families:

- SM8250 / Retroid Pocket 5: stock factory ABL can boot the SD Linux payload through UEFI GRUB; Android remains on internal storage.
- SM8550 / Retroid Pocket 6: the project states that stock ABL cannot boot pocknix and uses ROCKNIX ABL instead.

This difference is important: an RP5 or RP6 bootloader must not be assumed compatible with G2.

### G2 / pineapple source search

Searches for public GitHub Linux kernel/device-tree sources matching `Retroid Pocket G2`, `SG6275P`, and `pineapple` did not identify a clearly attributable G2 kernel/DTB source that can safely be treated as the device's Linux source of record.

Some public Qualcomm/Android projects use the string `pineapple`, but that string is not sufficient to establish hardware identity. One example is a OnePlus SM7675 kernel target named `pineapple`; it must not be treated as the G2 source.

## Engineering conclusion

At this point we have strong evidence for the G2 Android hardware configuration from the device itself, but not a verified public G2 Linux kernel/DTB source.

Therefore:

1. Do not use an RP5 kernel/DTB as a G2 kernel/DTB.
2. Do not use an RP6/SM8550 kernel/DTB as a G2 kernel/DTB.
3. Do not flash or replace G2 ABL/UEFI based on those projects.
4. Continue with read-only collection of G2 Android DT information and public source comparison.
5. The first SD test should only be designed after a G2-compatible kernel/DTB and boot path are identified.

## Safety boundary

No command in this research writes to the G2 internal UFS. The intended final architecture remains SD-only experimentation, leaving Android on internal storage untouched.
