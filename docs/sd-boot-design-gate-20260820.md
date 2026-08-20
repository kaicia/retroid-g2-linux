# G2 SD Boot Design Gate — 2026-08-20

## Source-derived findings

### Pocknix
- Retroid Pocket 6 / SM8550: stock ABL cannot boot pocknix; ROCKNIX ABL is required.
- Retroid Pocket 5 / SM8250: stock factory ABL boots pocknix through UEFI GRUB after switching ABL boot mode to SD/alternative boot.
- Pocknix SD images are SoC-family-specific and include kernel/device support.

### Armada
- Armada supports SD boot on listed devices, including Retroid Pocket 6.
- Armada's documented SD flow uses a device-matched ROCKNIX ABL.
- Armada explicitly warns that flashing the wrong ABL can brick the device or corrupt Android.

## G2 evidence collected from the physical device
- Platform/device: pineapple / Retroid Pocket G2.
- Android reports boot device `soc/1d84000.ufshc` / `1d84000.ufshc`.
- Current slot observed: `_b`.
- SD controller: `sdhci@8804000`.
- SD card appears as `mmcblk1` under `mmc1`.
- Internal storage exposes A/B XBL, ABL, UEFI, UEFI SECAPP, boot, init_boot, vendor_boot and related partitions.
- The G2 investigation has remained read-only; no internal UFS bootloader flashing has been performed.

## Current conclusion

The existing RP5/RP6 recipes cannot be transplanted directly to G2. The public sources establish the two reference boot models, but do not establish that the G2 factory ABL can boot a Linux payload from microSD.

The G2 platform is SG6275P/pineapple, so an SM8250 or SM8550 ABL must not be treated as compatible.

## Test gate

Do NOT perform an internal UFS/ABL flash merely to test SD boot.

A first SD-only boot test is gated on:
1. identifying a G2-compatible boot path without modifying internal UFS;
2. identifying/building a G2-compatible kernel + DTB + boot payload;
3. establishing a stock recovery path and preserving required backups;
4. preparing a separate test microSD, not the user's 1 TB investigation card;
5. validating the SD image offline before insertion into G2.

## Next research target

Focus on publicly available Pineapple/SG6275P Linux, kernel, DT and UEFI/ABL material, and compare it against the G2 evidence. The objective is to determine whether a non-invasive SD boot path exists. If not, stop before any ABL modification and treat ABL work as a separate high-risk phase requiring a verified stock restore path.
