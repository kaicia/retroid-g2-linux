# G2 Read-Only Investigation Analysis — 2026-08-20

## Scope

This note records conclusions supported by the read-only investigation collected from the running Retroid Pocket G2. No UFS, bootloader, partition, or boot configuration write was performed.

## Confirmed device state

- Model: Retroid Pocket G2
- Device codename: `pineapple`
- Android: 15
- Kernel: `6.1.115-android14-11-maybe-dirty`, aarch64
- Current slot: `_b`
- AVB version: 1.2
- `ro.boot.vbmeta.device_state`: `unlocked`
- `ro.boot.verifiedbootstate`: `orange`
- `ro.boot.veritymode`: `enforcing`

## Current Android boot storage

The collected property reports:

```text
ro.boot.boot_devices = soc/1d84000.ufshc
ro.boot.bootdevice   = 1d84000.ufshc
```

Therefore the currently running Android boot path is associated with the internal UFS controller, not the external microSD device.

This does NOT prove that external SD boot is impossible. It only establishes the storage device used by the current Android boot configuration.

## A/B and boot-chain partition structure

The read-only `/dev/block/by-name` listing confirms the presence of A/B copies of important boot components, including:

- `abl_a` / `abl_b`
- `xbl_a` / `xbl_b`
- `uefi_a` / `uefi_b`
- `uefisecapp_a` / `uefisecapp_b`
- `boot_a` / `boot_b`
- `init_boot_a` / `init_boot_b`
- `vendor_boot_a` / `vendor_boot_b`
- `dtbo_a` / `dtbo_b`
- `vbmeta_a` / `vbmeta_b`
- `recovery_a` / `recovery_b`

These are observations of partition-node presence only. Their contents have not been modified or flashed.

## Security state

The device reports an unlocked AVB/boot state (`device_state=unlocked`, `verifiedbootstate=orange`). This is useful for future boot-chain investigation, but it is not by itself evidence that a Linux image can boot from microSD.

## microSD / SDHCI relationship already established

Previous direct Device Tree investigation confirmed the SDHCI controller at:

```text
/sys/firmware/devicetree/base/soc/sdhci@8804000
```

with Qualcomm MSM SDHCI v5 compatibility and a 4-bit bus. The SD interface uses the `sdc2_on` / `sdc2_off` pinctrl states and the previously recorded SD GPIO assignments.

The current 1 TB microSD is exposed as `mmcblk1` with `mmcblk1p1`, and Android mounts its exFAT filesystem through `/mnt/media_rw/C5D7-C07A` and `/storage/C5D7-C07A`.

The MMC device path is under:

```text
/sys/devices/platform/soc/8804000.sdhci/mmc_host/mmc1/mmc1:0001
```

and the block driver path resolves to the Linux MMC block driver.

## Important conclusion

At this point we have established both sides of the storage investigation:

```text
Current Android boot:
  boot properties -> 1d84000.ufshc -> internal UFS

External SD:
  sdhci@8804000 -> mmc1 -> mmcblk1 -> mmcblk1p1 -> exFAT -> Android storage
```

The remaining key technical question is therefore not whether the G2 hardware can communicate with the SD card—it clearly can—but whether the early boot chain (XBL/ABL/UEFI and associated firmware/configuration) can select and load a Linux boot payload from that SD controller without altering the internal Android installation.

## Safety decision

The project continues to use the following rule:

> All experiments must target the microSD first. The internal Android installation, UFS boot partitions, bootloader partitions, AVB metadata, and persistent device data must not be modified during the experimental phase.

Before any boot test, the boot-chain requirements and a reliable stock recovery path must be established.

## Next investigation

1. Analyze the complete collected SDHCI/Device Tree section.
2. Compare G2 boot-chain structure with Armada/RP5/RP6 projects.
3. Determine what boot payload formats the G2 early boot firmware can recognize.
4. Determine whether UEFI/ABL provides an SD boot path or whether a chainloader approach is required.
5. Identify a safe SD-only test architecture.
6. Do not flash internal UFS/bootloader partitions unless a separate, explicitly reviewed recovery plan exists.
