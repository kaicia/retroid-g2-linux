# Retroid Pocket G2 Recovery File Search — 2026-08-20

## Scope

Search for G2-specific stock firmware, OTA packages, Qualcomm EDL/QFIL programmers, rawprogram/patch XML, GPT/partition images, and fastboot recovery material.

## Confirmed findings

### OTA / firmware versions

- Pocket G2 OTA 1.0.0.176 exists and was released in March 2026.
- The 1.0.0.176 update is documented as an OTA update, not a complete Qualcomm factory recovery package.
- A community reverse-engineering report states that an OTA delta from 1.0.0.164 to 1.0.0.176 was obtained by analyzing the Retroid OTA updater and retrieving a server download URL. The report explicitly says the delta package is only for G2 devices on 1.0.0.164.
- The same report indicates that older releases could be enumerated through the OTA mechanism, but this does not establish that a complete factory image is publicly available.

Sources:
- 4PDA Retroid Pocket 5 / G2 discussion, post #7204: https://4pda.to/forum/index.php?showtopic=1093941&st=7200
- 4PDA Retroid Pocket 5 / G2 discussion, post #6866: https://4pda.to/forum/index.php?showtopic=1093941&st=6860
- Notebookcheck report citing Retroid/Discord for OTA 1.0.0.176: https://www.notebookcheck.net/Retroid-releases-OTA-update-for-discontinued-handheld.1257906.0.html

### QFIL / EDL evidence

- A later G2 discussion post reports that users downloaded G2 firmware packages and attempted to use QPST/QFIL.
- The same report says the G2 firmware package did not contain a `firehose` programmer, leaving QFIL's Download operation unavailable.
- This is strong evidence that the files circulating publicly are not, by themselves, a complete QFIL/EDL recovery package.

Source:
- 4PDA Retroid Pocket 5 / G2 discussion, post #7231: https://4pda.to/forum/index.php?showtopic=1093941&st=7220

## Files NOT verified as publicly available for G2

As of this search, no G2-specific, verified public recovery package containing all of the following was found:

- G2-specific Qualcomm Firehose programmer (`prog_*.elf`/`*.mbn` as appropriate)
- `rawprogram*.xml`
- `patch*.xml`
- complete GPT image/dump intended for QFIL recovery
- complete partition image set for all critical A/B boot partitions
- a documented G2-specific QFIL/EDL recovery bundle with matching programmer and XML files

## Important distinction

The following files are useful recovery targets but have NOT been verified as publicly available for G2 in a complete, matched package:

- xbl_a / xbl_b
- abl_a / abl_b
- boot_a / boot_b
- init_boot_a / init_boot_b
- vendor_boot_a / vendor_boot_b
- dtbo_a / dtbo_b
- vbmeta_a / vbmeta_b
- modem and other Qualcomm firmware partitions
- GPT / partition metadata

Do not use equivalent files from RP5, RP6, Odin 2, Odin 3, or another Snapdragon platform as substitutes for G2 recovery.

## RP5 comparison

The Retroid Pocket 5 stock-firmware repository by TheGammaSqueeze demonstrates what a complete Qualcomm recovery package can look like for another Retroid device, including a device-matched Firehose programmer and flash XML files. This is useful as a reference for the expected package structure, but its files are NOT G2-compatible.

Repository reference:
https://github.com/TheGammaSqueeze/Retroid_Pocket_Stock_Firmware

## Current recovery readiness

Status: NOT READY for any internal flashing operation.

Before any internal recovery attempt is even considered, the project still needs:

1. Exact G2 firmware/build identification from the device.
2. A complete G2-specific stock firmware package, or a verified method to reconstruct one.
3. A G2-specific EDL/Firehose programmer matched to the hardware/firmware generation.
4. Matching rawprogram/patch XML or an equally reliable complete partition restore method.
5. Verification/hashes of the recovery files.
6. A tested recovery path that does not depend on files from another SoC/device.

## Project safety rule

No file discovered during this research authorizes flashing the G2. The project remains microSD-first and non-destructive. Internal UFS, ABL, boot, vendor_boot, dtbo, vbmeta, GPT and other internal partitions must remain untouched during the research and initial SD-boot testing phases.