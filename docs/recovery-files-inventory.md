# Retroid Pocket G2 Recovery Files Inventory

Research date: 2026-08-20

## Safety rule

The G2 is the user's only device. No bootloader, ABL, GPT, boot, vendor_boot, vbmeta, DTB, DTBO, or other internal storage write operation is authorized until a verified G2-specific recovery package and recovery path are available.

## Files/components required for a robust Qualcomm recovery package

A complete EDL/QFIL package normally needs:

- G2-specific Firehose programmer (`prog_firehose_*.elf`)
- GPT headers / partition metadata
- `rawprogram*.xml`
- `patch*.xml`
- boot-chain images such as XBL/ABL and their A/B copies
- boot/recovery/vendor_boot where applicable
- DTBO/vbmeta where applicable
- modem/DSP and other firmware partitions
- UFS storage layout appropriate to the exact G2 hardware
- matching Qualcomm USB drivers and QFIL/QPST tools on a PC

These requirements are derived from working Retroid Qualcomm recovery packages for other models. They do NOT establish that those files are safe for G2.

## Exact G2 files found so far

### Stock firmware

A community discussion specifically for Retroid Pocket 5 / G2 reports that G2 firmware packages have been posted. However, the search-accessible material does not expose a complete, independently verifiable download package with hashes and all required EDL files.

A 4PDA post reports that a user extracted a G2 OTA delta from firmware 1.0.0.164 to 1.0.0.176. The delta is version-specific and is NOT a complete recovery image.

Therefore:

- G2 OTA 1.0.0.176 is confirmed to exist.
- It is not currently treated as a complete brick-recovery package.
- We still need an exact full G2 stock package and its provenance/hash verification.

## Important negative finding: Firehose

A G2-specific discussion reports that the available G2 firmware package did not contain a `firehose` file, preventing the QPST/QFIL download operation from being selected normally.

This is important evidence that a firmware archive called "G2 firmware" is not automatically sufficient for EDL recovery.

## Reference package: Retroid Pocket 5 / Mini

TheGammaSqueeze's Retroid_Pocket_Stock_Firmware repository provides a documented QFIL recovery package for Snapdragon 865 Retroid devices.

Its package contains, among other things:

- `flash/`
- `prog_ufs_firehose_sm8250_lite_lp5.elf`
- `QFILHelper.exe`
- QPST/QFIL installer
- Qualcomm USB driver package
- complete partition images and GPT-related files

The guide explicitly identifies the Firehose programmer as the component used for EDL communication.

**This is reference material only. Do not use the RP5/Mini Firehose on G2.** G2 uses Snapdragon G2 Gen 2 and requires a verified matching programmer/package.

## G2 firmware version evidence

The G2 received OTA version 1.0.0.176 in March 2026. The update included charge separation, Widevine/Netflix improvements and other fixes.

Because OTA updates are incremental, an OTA delta such as 1.0.0.164 -> 1.0.0.176 must not be mistaken for a full factory/EDL image.

## Recovery hierarchy for this project

1. Obtain a verified complete G2 stock firmware package.
2. Identify and verify a G2-compatible Firehose programmer.
3. Obtain matching rawprogram/patch XML and partition images if QFIL recovery is required.
4. Record SHA-256 hashes and firmware/build identifiers.
5. Determine G2 EDL entry method without modifying storage.
6. Only after all of the above are verified should recovery procedures be considered.

## Current status

SAFE / READ-ONLY.

No G2 internal storage has been flashed or modified as part of this project.
