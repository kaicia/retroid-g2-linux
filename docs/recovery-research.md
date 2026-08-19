# Retroid Pocket G2 Recovery Research

Updated: 2026-08-20

## Safety requirement

The project has exactly one Retroid Pocket G2 available for testing. Avoiding an unrecoverable brick is the highest-priority constraint.

Until a verified recovery path is available, all G2 work should be read-only. Do not flash or write ABL, boot, vendor_boot, vbmeta, DTB/DTBO, GPT, or other internal storage partitions.

## Recovery paths investigated

### 1. Stock firmware / QFIL-style recovery

TheGammaSqueeze's Retroid stock-firmware repository documents Qualcomm QFIL recovery packages for several Qualcomm Retroid devices, including RP5 and RP Mini. Those packages contain device-specific firmware files and Firehose programmers. This establishes that QFIL/EDL recovery is a real recovery model for related Qualcomm Retroid hardware, but it does NOT establish that an RP5/RP Mini programmer or package is safe or compatible with G2.

Source:
https://github.com/TheGammaSqueeze/Retroid_Pocket_Stock_Firmware

Important: G2-specific firmware/package must be identified before treating this as a G2 recovery solution.

### 2. Qualcomm EDL / 9008

EDL is a possible low-level Qualcomm recovery mechanism. Public Retroid recovery documentation for related devices uses Qualcomm HS-USB QDLoader 9008 and a device/SoC-specific Firehose programmer.

This is evidence for the recovery architecture, not proof of a G2-specific recovery package.

Do not attempt EDL flashing on the G2 during the investigation.

### 3. Fastboot / boot-loop recovery

A recent community report describes a Retroid Pocket G2 that entered a fastboot boot loop after an incorrect boot image was flashed and was subsequently recovered using a QFIL-based stock-firmware process. The report is community evidence only and must not be treated as an official recovery procedure.

A second important observation from the report is that the recovery attempt initially failed because of a PC/driver environment issue, then succeeded after addressing the Windows BitLocker/driver situation.

Source:
https://www.reddit.com/r/retroid/comments/1vg0qkj/retroid_pocket_g2%E5%BE%A9%E6%97%A9/

## What is NOT established yet

- Exact G2 stock firmware package suitable for recovery.
- Exact G2 Firehose programmer.
- Exact G2 EDL entry procedure.
- Whether G2 can always be recovered from an ABL/bootloader failure without hardware intervention.
- Whether a complete G2 firmware backup can be made safely before experimentation.
- Whether Retroid provides a current official G2 recovery package.

## Recovery readiness rule

Do not modify the G2 boot chain until at least one reliable recovery path is independently verified for the exact G2 hardware, preferably with the required stock images/programmer available offline.

Even after a recovery path is identified, first perform read-only inspection and preserve all available device-specific information.

## Current safe plan

1. Continue research without modifying the G2.
2. Connect the G2 only for read-only ADB investigation.
3. Record boot-chain, partition, firmware and device identifiers.
4. Search for an exact G2 stock recovery package and verify its provenance.
5. Determine whether a complete or sufficiently safe backup is possible.
6. Only then evaluate any boot-chain modification.

## Related project evidence

The Armada project itself warns that ABL flashing can brick a device or corrupt the Android partition. Armada's SD boot procedure therefore cannot be copied directly to the G2 merely because the G2 is Qualcomm-based.

Reference:
https://github.com/armada-os/armada
