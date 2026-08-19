# G2 Project Safety and Recovery Plan

## Non-negotiable safety requirement

The project has exactly one Retroid Pocket G2 available for testing. A permanent brick or loss of the device is unacceptable.

Therefore the project will use a read-first, write-last approach.

## Operations prohibited during the research phase

Until a complete, device-specific recovery path has been verified, do NOT:

- flash ABL / bootloader partitions
- write to `abl_a` or `abl_b`
- flash `boot`, `vendor_boot`, recovery, DTB/DTBO or vbmeta
- modify GPT or partition layout
- use `dd` or another raw block-device write against internal storage
- resize or format Android partitions
- run unknown flashing scripts as root
- replace the stock boot chain

Reading information from the running Android system is preferred.

## Recovery paths identified by research

### 1. Normal Android recovery / stock firmware recovery

Retroid Pocket stock-firmware documentation indicates that a firmware recovery process exists and that the stock firmware repository contains extensive partition images, including boot, recovery, ABL-related and modem-related partitions. The exact G2 package and exact procedure must be verified before any use.

Source:
https://github.com/TheGammaSqueeze/Retroid_Pocket_Stock_Firmware

### 2. Qualcomm EDL / Emergency Download

The G2 uses a Qualcomm Snapdragon G2 Gen 2 platform, so Qualcomm EDL is a recovery path that must be investigated before any bootloader modification is considered.

Qualcomm documentation describes EDL as a ROM-level recovery/flash interface. A Qualcomm EDL device commonly enumerates over USB as VID:PID `05c6:9008`.

Important: the existence of EDL on a Qualcomm platform does NOT by itself prove that the G2 can be recovered with a generic loader. A device-specific signed programmer/firehose loader and the correct stock firmware package may be required.

Sources:
https://github.com/qualcomm-linux/qcom-linux-skills/blob/main/skills/qcom-flash-qdl/references/entering-edl.md
https://github.com/linux-msm/qdl

### 3. G2-specific community recovery evidence

A recent community report specifically describes recovering a Retroid Pocket G2 after an incorrect `boot.img` flash caused a fastboot boot loop. The report says recovery succeeded using the stock firmware/QFIL path after resolving a Windows BitLocker/driver issue.

This is community evidence, not an official Retroid recovery procedure, so it must be independently verified before being relied upon.

Source:
https://www.reddit.com/r/retroid/comments/1vg0qkj/retroid_pocket_g2/

### 4. Hardware-level EDL/test-point recovery

Qualcomm platforms can have a hardware path into EDL using board-specific test points. However, the exact G2 test points have NOT been verified in this project. No test-point operation should be attempted until an authoritative G2-specific source and the correct board revision are identified.

## Recovery research still required

Before any write operation on the G2, determine and document:

1. Exact G2 stock firmware package currently matching the device.
2. Whether the package contains all required boot/ABL/vendor_boot/vbmeta and other critical partitions.
3. Exact G2 recovery procedure using the official or well-verified stock package.
4. Whether G2 can reliably enter fastboot/bootloader recovery.
5. Whether G2 reliably enumerates in Qualcomm EDL (`05c6:9008`) when required.
6. Which exact programmer/firehose loader is required for the G2.
7. Whether the G2 bootloader is locked and what recovery implications that has.
8. Whether device-unique partitions must be backed up before any modification.
9. Whether a complete read-only backup can be made before experimenting.
10. Whether recovery can be performed without erasing Android user data.

## Project decision gate

No ABL, bootloader, boot, DTB, vendor_boot, vbmeta or partition-table write will be attempted until the recovery path is sufficiently verified for the exact G2 hardware/software revision.

The first priority is preserving a working Android G2, not achieving a Linux boot at any cost.
