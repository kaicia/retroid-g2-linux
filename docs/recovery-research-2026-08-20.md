# Retroid Pocket G2 Recovery Research — 2026-08-20

## Safety requirement

The project has one Retroid Pocket G2 available. No recovery research justifies writing to ABL, boot, vendor_boot, vbmeta, GPT, or other internal storage before a verified G2-specific recovery path is established.

All current work remains read-only.

## Recovery paths investigated

### 1. Official Retroid / OTA path

Retroid's current G2 product information confirms Android 15, 128GB UFS 3.1 internal storage, microSD/TF slot, and official OTA support for incremental software upgrades. This confirms an official software update mechanism exists, but the public product page does not provide a complete downloadable G2 factory image or a documented EDL recovery package.

Status: **Not yet sufficient as an offline brick-recovery plan.**

### 2. Qualcomm EDL / 9008

Recent G2 community recovery evidence shows that a G2 which entered a fastboot boot loop after an incorrect boot image was successfully recovered using QFIL after resolving a Windows driver/BitLocker issue. This is useful evidence that a Qualcomm emergency-download recovery route is relevant to G2.

However, a working EDL recovery requires the correct G2 firmware and matching programmer/firehose package. A programmer from another Snapdragon/Retroid device must not be assumed compatible.

Status: **Promising, but G2-specific programmer/firmware still must be identified and verified.**

### 3. Hardware EDL / test points

A community discussion for Retroid Pocket 5/G2 reports that hardware disassembly and test points were used to enter EDL in a difficult recovery case. This is community evidence, not an official G2 procedure. It should therefore be treated only as a last-resort possibility until the exact G2 test points and procedure are independently verified.

Status: **Last resort; do not attempt during the current investigation.**

### 4. QFIL

The Retroid Pocket Stock Firmware project documents QFIL recovery for Retroid Pocket Mini/Pocket 5 and shows the general structure required for Qualcomm EDL recovery: Qualcomm USB drivers, QPST/QFIL, a device-specific Firehose programmer, and a matching firmware/flash package.

That documentation is for Snapdragon 865 RP Mini/RP5, not G2. Therefore it is useful for understanding the recovery architecture but is NOT a G2 flashing recipe.

Status: **Reference only until a G2-specific package is found.**

### 5. Fastboot

Community reports indicate that G2 can enter fastboot/boot-loop states and that recovery can proceed from such states in some cases. Exact G2 fastboot commands, partition accessibility, and safe recovery sequence have not yet been established.

Status: **Investigate read-only first. Never issue a flash command during the current stage.**

## Evidence found

- Official Retroid G2 product page: https://www.goretroid.com/en-au/products/retroid-pocket-g2-handheld
- Retroid Pocket Stock Firmware/QFIL reference: https://github.com/TheGammaSqueeze/Retroid_Pocket_Stock_Firmware
- 2026 G2 community recovery report: a user reported recovering a G2 after an incorrect boot.img caused a fastboot reboot loop; QFIL initially failed at Sahara communication, and the user reported that Windows BitLocker/driver handling was the cause. This is anecdotal evidence and must not be treated as an official procedure.
- Community Retroid Pocket 5/G2 discussion contains reports of EDL/test-point recovery and original firmware recovery. This is also anecdotal.

## What is still required before any write operation

1. Identify exact G2 hardware/SoC and firmware build from the device itself.
2. Identify exact current bootloader/boot chain structure using read-only ADB queries.
3. Determine whether the device exposes a usable fastboot interface.
4. Determine whether the device can enter Qualcomm EDL without hardware disassembly.
5. Find an exact G2 stock firmware package.
6. Find an exact G2-compatible Firehose/programmer package if EDL is required.
7. Verify that the firmware/package matches the G2 storage layout and current hardware generation.
8. Preserve all available read-only partition/device-tree information before any change.
9. Only after the above are confirmed, design a reversible test plan.

## Important conclusion

The existence of QFIL/EDL recovery for other Retroid Snapdragon devices is NOT enough to declare the G2 safely recoverable. The missing pieces are the exact G2 stock firmware and exact G2-compatible EDL programmer/recovery package, plus a verified G2 bootloader recovery procedure.

Until those are obtained and checked, the project remains in the read-only investigation phase.
