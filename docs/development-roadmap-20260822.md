# G2 Development Roadmap — 2026-08-22

## Non-negotiable project boundary

All bring-up and testing must use **microSD**. The internal Android storage/boot chain remains untouched.

Target behavior:
- microSD inserted -> Linux/SteamOS/Armada-class environment boots from SD
- microSD removed -> stock Android boots normally

No internal flash, erase, partition resize, boot/vbmeta/dtbo/ABL modification, or other destructive write is part of normal development.

## Why the development method changed

Previous workflow was too dependency-complete-first: it attempted to finish every provider mapping before producing a compilable artifact.

The reference projects show a more iterative bring-up pattern:

1. establish a reproducible build harness and kernel input set;
2. add a device/board DTS and required kernel patches;
3. produce a buildable image;
4. boot/test on hardware;
5. use logs and on-device evidence to fix one subsystem at a time;
6. add performance/features after basic bring-up.

This is now the G2 workflow, while retaining all existing safety and evidence rules.

## Evidence from pocknix/ROCKNIX

The pocknix history began with a build harness plus in-repo RP6 kernel inputs (`3602ad11`). Its kernel model is stock Linux + an ordered patch stack + config + DT/DTS inputs, with reproducible pins. The repository documents the kernel as a self-contained input set rather than waiting for every device feature to be solved first.

The RP6 development then proceeded incrementally. Examples from the commit history:
- downstream SDHCI was ported specifically to enable UHS-I SDR104 microSD (`065f09c`);
- the SDHCI change was later enabled for the Odin 2 family separately (`9e9a201`);
- RP5 first-boot issues were diagnosed on-device and fixed iteratively (`2526823`);
- panel/GPU issues were investigated through repeated A/B tests and on-device validation;
- later device-family consolidation happened after the working device support already existed (`94ad349`).

This is strong evidence for producing intermediate bootable artifacts and using hardware results to drive the next patch rather than requiring a perfect DTS up front.

## Evidence from Armada

Armada issue #1 shows RP5 support being treated as a port because existing Arabian/ROCKNIX support provided a starting point. The maintainer later reported RP5 support in a test image before the stable release, and testing was then driven by device reports.

More importantly for our safety model, Armada issue #155 documents a verified RP6 path through **stock UEFI + removable SD**, explicitly avoiding an ABL flash. The reported sequence was:
- stock UEFI sees removable SD;
- Armada's EFI/GRUB path can be enabled;
- the kernel boots;
- the missing/incorrect DT was then isolated and fixed by supplying the correct DTB to GRUB;
- the author reports the path as fully reversible and requiring no ABL flash.

This is a particularly relevant precedent for the G2 project because our project requires the same class of SD-only, reversible development path.

## G2 bring-up strategy

### Phase A — Build skeleton now

Do not wait for every dependency to be proven.

Create the smallest G2-targeted kernel/DTS build based on the closest verified Cliffs source and the existing Armada/pocknix build/image infrastructure.

The first artifact is allowed to be incomplete and is expected to fail at runtime. It must, however, be source-grounded and compile cleanly.

### Phase B — First SD boot artifact

Produce a microSD image containing:
- kernel;
- G2 DTB/DTBO arrangement appropriate to the selected SD boot path;
- minimal root filesystem;
- boot configuration.

Do not alter the internal Android boot chain.

The first goal is **any observable Linux boot evidence**, not a working SteamOS desktop.

Preferred evidence order:
1. kernel/early boot log;
2. SDHCI probe;
3. root filesystem mount;
4. display or other visible output;
5. SSH/ADB/network access if available.

### Phase C — Fix blockers from real logs

Once the first SD artifact exists, work one blocker at a time:

1. boot/DT loading;
2. clocks/resets/power domains;
3. SDHCI + SD card;
4. SMMU/interconnect;
5. rootfs/storage;
6. display/GPU;
7. USB/input;
8. Wi-Fi/Bluetooth/audio;
9. suspend/power management;
10. Steam/Game Mode integration.

The exact order may change according to the first boot log.

### Phase D — Convert the experimental artifact into a maintainable port

After basic boot works:
- minimize G2-specific patches;
- move board data into a clean G2 DTS/DTSI;
- keep only source-supported quirks;
- add automated DTS/kernel checks;
- integrate the kernel into Armada's reproducible image build;
- document known limitations.

### Phase E — Validation

Every hardware change must be tested from the microSD artifact. Record:
- exact image/kernel commit;
- DTB hash;
- boot result;
- logs;
- subsystem status;
- regression status.

## Current immediate task

Stop expanding the provider investigation indefinitely. Use the already verified G2/Cliffs SDHCI information to create the **first minimal compilable G2 kernel/DTS target**.

Remaining uncertain mappings (PMXR2230, SMMU stream ID, and any missing boot-path-specific details) should be handled as explicit bring-up blockers, not reasons to postpone the first compile indefinitely.

Before any G2 hardware test, validate the artifact on the build side. The first device test must be a microSD test and must not require an internal flash.

## Rules carried forward

- G2 ADB dumps are the hardware source of truth.
- Exact Cliffs/pineapple evidence takes precedence over commercial Snapdragon labels.
- RP5/RP6/Odin/ROCKNIX/pocknix/Armada are references and working precedents, not permission to copy unrelated numeric IDs.
- All important findings and decisions are committed to this repository.
- Unknown values remain explicitly unknown until supported by source or hardware evidence.
- No internal Android storage modification is required for the normal bring-up path.
