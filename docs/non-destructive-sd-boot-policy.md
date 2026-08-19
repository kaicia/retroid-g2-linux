# G2 Non-Destructive SD Boot Testing Policy

## Primary safety requirement

Retroid Pocket G2 is the only physical G2 device available for this project. Preventing an unrecoverable brick is the highest-priority requirement.

The project will therefore pursue a **non-destructive microSD-first architecture** for Linux/SteamOS testing.

## Required architecture

- Existing Android on the internal UFS must remain intact.
- Linux/SteamOS kernel, DTB/DTBO, root filesystem, configuration and related test files should reside on the microSD card whenever technically possible.
- The preferred boot path is: microSD inserted -> boot Linux/SteamOS from microSD; microSD removed -> boot the original Android installation unchanged.
- Testing must not require overwriting the internal Android installation.

## Prohibited operations during the research and initial testing phases

Do not perform any of the following on the G2 internal storage or bootloader unless a later phase explicitly proves it is unavoidable, a verified recovery path exists, and the user explicitly approves it:

- flash or overwrite ABL/bootloader partitions
- `fastboot flash` to internal storage
- write to boot, vendor_boot, dtbo, vbmeta or other internal boot partitions
- `dd` writes to internal block devices
- modify GPT or internal partition layout
- format, resize or erase Android/UFS partitions
- replace the stock boot chain
- install an unverified programmer/firehose through EDL/QFIL

## Investigation rule

ADB investigation should be read-only whenever possible. Information needed for Linux porting should first be collected from the running Android system, Device Tree, boot configuration and storage layout without modifying the device.

## Recovery research is preparation, not a license to flash

Stock firmware, Firehose/programmer files, rawprogram/patch XML files, GPT and partition images are being researched as an emergency recovery capability. Their existence does **not** authorize flashing them to the G2.

A recovery package must be verified as G2-specific and matched to the relevant hardware/firmware generation before it can be considered usable.

## Test failure behavior

The preferred failure/recovery action during SD boot testing is:

1. Power off the G2.
2. Remove the microSD card.
3. Boot the unchanged internal Android system.

If SD boot fails, do not immediately modify internal partitions to make the test work.

## Decision gate before any internal write

An internal write may only be considered after all of the following are documented:

1. Why SD-only boot cannot achieve the required function.
2. The exact internal partition(s) that would need modification.
3. A verified complete backup/readback strategy for those partition(s).
4. A G2-specific recovery package and recovery procedure.
5. A tested recovery path that does not depend on an unverified file.
6. A clear rollback procedure.
7. Explicit user approval immediately before the write operation.

Until these conditions are satisfied, the project remains read-only with respect to the G2 internal storage.

## Project objective

The desired final result is a reversible dual-boot-like experience:

- microSD present -> Linux/SteamOS
- microSD absent -> original Android

The project should prefer solutions that preserve this behavior rather than solutions that replace the internal Android boot chain.