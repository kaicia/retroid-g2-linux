# G2 Recovery Files Search — 2026-08-20 (continued)

## Purpose

This is a continuation of the recovery-file investigation. The project is intentionally **not** flashing these files to the G2. The purpose is to understand whether a complete, G2-specific recovery path exists before any internal-storage write is ever considered.

## New findings

### G2 firmware / OTA

- G2 OTA version **1.0.0.176** is confirmed to exist.
- Community discussion documents the 1.0.0.176 update and problems installing it on rooted devices.
- A community report also describes a **1.0.0.164 -> 1.0.0.176 OTA delta**. This is an OTA update package, not a complete factory restoration package.

### G2 QFIL / EDL evidence

A G2 owner reported downloading the G2 firmware packages and attempting to use QPST/QFIL, but found that the G2 firmware package did **not contain a Firehose file**, leaving the QFIL Download action unavailable. This is direct evidence that at least one publicly circulating G2 firmware package is not a complete QFIL/EDL restoration bundle.

### Recovery precedent from other Retroid devices

A Retroid Pocket 5/G2 community thread documents a recovery involving EDL test points and QFIL, followed by installation of an older original firmware version. This is useful as evidence that Qualcomm/EDL recovery can exist in the Retroid ecosystem, but it does **not** prove that the same programmer or firmware files are valid for G2.

The project will not substitute another Retroid model's programmer, Firehose, XML files, GPT or partition images for G2-specific files.

## Files still not verified as publicly available for G2

The following remain unverified as a complete G2-specific recovery set:

- G2-specific Firehose/programmer
- G2-specific `rawprogram*.xml`
- G2-specific `patch*.xml`
- complete G2 GPT/partition restoration set
- complete G2 factory/QFIL/EDL package
- a documented G2-specific EDL recovery procedure with matching files
- cryptographically verified hashes tying all recovery files to the same G2 firmware generation

## Important distinction

The existence of an OTA package does not mean that the OTA package can restore a completely bricked device. OTA update payloads and a Qualcomm EDL/QFIL factory restoration package serve different purposes.

## Safety decision

Because the G2 is the only physical unit available for this project, these unresolved recovery-file items are a reason to remain conservative. The project remains in a read-only investigation phase with respect to internal UFS and bootloader storage.

The preferred architecture remains:

- microSD present -> Linux/SteamOS test environment
- microSD absent -> original Android installation

No recovery-file discovery authorizes flashing the G2.

## Sources checked

- 4PDA Retroid Pocket 5 / G2 discussion, including G2 QFIL/Firehose reports and EDL recovery discussion.
- Reddit Retroid Pocket G2 community discussions.
- Public Retroid-related recovery documentation used only as comparative evidence.

## Next research targets

1. Find an independently verifiable G2 full stock package, if one exists.
2. Identify whether a G2-specific programmer/Firehose has ever been publicly extracted or shared.
3. Determine whether G2 firmware packages contain sufficient partition metadata for offline restoration.
4. Determine the exact relationship between G2 firmware versions and any available recovery files.
5. Continue to avoid internal writes until the recovery path is independently verified.
