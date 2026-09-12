# Retroid Pocket G2 SteamOS Project Rebuild — 2026-08-25

## 1. Project definition

### Final device goal

The target is a Retroid Pocket G2 Linux/SteamOS-class environment installed and booted from **microSD/removable media only**.

Required behavior:

- microSD inserted → the G2 reaches the Linux/SteamOS-class SD boot path;
- microSD removed → the normal stock Android boot path remains intact.

The normal development path must not require flashing, erasing, repartitioning, or modifying internal Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo storage.

### What counts as success

The project is not considered complete when a DTS compiles or when a kernel image is produced. The development ladder is:

1. G2 hardware facts and boot-path evidence are known;
2. reproducible kernel/DTS/image inputs exist;
3. a build-validated SD Linux artifact exists;
4. the first real G2 SD boot produces observable Linux evidence;
5. blockers are fixed from real device logs;
6. core device functionality works;
7. the Linux userspace is suitable for an Armada/SteamOS-class experience;
8. Steam/Proton/Game Mode integration is added and tested.

## 2. Track A — G2 technical/SteamOS work

### A0 — Hardware truth

Use the existing G2 hardware research and ADB collection work as the source of truth. Do not replace G2-specific evidence with RP5/RP6/Odin/SM8550 assumptions.

Required evidence includes, at minimum:

- exact Qualcomm platform/device-tree identity;
- kernel version/config and boot parameters;
- partition/block/mount layout;
- boot/vendor/dtbo/vbmeta/ABL structure relevant to SD boot;
- Device Tree model/compatible data;
- SDHCI and GPIO information;
- clocks/resets/interconnect/SMMU/power-provider requirements;
- display/GPU/USB/input/Wi-Fi/Bluetooth/audio/power details as needed later.

### A1 — Kernel + DT build skeleton

Use the already selected Linux/pocknix/ROCKNIX/Armada lineage as a build reference, but only retain values that are directly supported for G2/Cliffs.

Produce a reproducible kernel input set:

- pinned kernel source;
- G2 config fragment;
- G2 DTS/DTSI;
- G2-specific patch stack;
- deterministic build script;
- validation script.

### A2 — First removable-media artifact

Build the smallest SD image containing:

- kernel;
- G2 DTB/DTBO arrangement appropriate to the verified boot path;
- minimal rootfs;
- boot configuration;
- validation metadata/hashes.

The first target is **observable Linux boot evidence**, not a finished SteamOS desktop.

### A3 — First physical G2 SD test

Before inserting the card into the G2:

- validate the image on the build side;
- record kernel commit, DTB hash and image hash;
- verify no internal-storage operation is part of the test procedure.

The first physical test is intentionally small. The first useful result may be only an early kernel log, SDHCI probe, rootfs mount, serial/USB/network evidence, or another observable Linux signal.

### A4 — Log-driven bring-up

Use real G2 results to fix one blocker at a time. Default order:

1. boot/DT loading;
2. clocks/resets/power domains;
3. SDHCI and microSD;
4. SMMU/interconnect;
5. rootfs/storage;
6. display/GPU;
7. USB/input;
8. Wi-Fi/Bluetooth/audio;
9. suspend/power management;
10. Steam/Game Mode/Proton integration.

The actual order is determined by the first real boot log.

### A5 — SteamOS-class userspace

Only after basic Linux bring-up is working:

- integrate the kernel/DT/image build into the chosen Armada-class image workflow;
- establish graphics/display support;
- establish input/audio/networking;
- integrate Steam/Game Mode/desktop components;
- add Proton/FEX/other runtime pieces only where needed;
- test games and hardware acceleration.

### A6 — Maintainable port

Once the device boots reliably:

- minimize G2-specific patches;
- keep clean G2 DTS/DTSI structure;
- retain source provenance for every nontrivial numeric value;
- automate kernel/DTS/image validation;
- document known limitations and recovery procedure.

## 3. Track B — development execution loop

**Superseded 2026-09-12.** Track B originally specified a GitHub-centred
DeepSeek execution loop: one JSON dispatch request per task, a bridge workflow,
an OpenCode run, and a mandatory identity chain correlating task/request/run/job
/trace identifiers before a result could be accepted.

That loop was retired when development moved to a coding agent working directly
on the repository. The current execution model is `docs/development-workflow.md`.
The retired design is preserved in `docs/archive/automation/`.

Two Track B principles were carried forward and remain in force:

- one task at a time;
- a result is evidence only for the request that produced it, and an older
  result is never presented as the outcome of a later request.

Track A below is unaffected.

## 4. Temporary/test material

Automation/permission/trigger experiments are not project-development work.

Temporarily isolated test PRs are closed and must not be used as evidence for G2 development progress. Historical test comments may remain in GitHub history, but the active workflow must ignore them when deciding the next G2 task.

As of this rebuild, the following test PRs are treated as historical/temporary:

- PR #2 — Codex Cloud trigger test;
- PR #8 — GitHub Actions PR-creation permission test;
- PR #10 — OpenCode workflow dispatch plumbing test.

Real G2 implementation history remains separate:

- PR #3 — initial G2 hardware research/ADB collection work;
- PR #6 — first G2 Cliffs SD-only DTS work;
- PR #9 — first build-validated G2 microSD boot-test candidate.

## 5. Current technical baseline for the rebuild

The repository roadmap already records the iterative pocknix/ROCKNIX and Armada methodology: build harness → kernel/DTS → buildable image → hardware test → log-driven fixes. It also records the SD-only, reversible boot objective.

PR #9 established a first build-validated SD candidate using Linux 7.1.5, a G2 DTB, minimal rootfs and SD image. It also recorded the critical blocker that Linux 7.1.5 did not yet contain the required Cliffs providers, and that the G2 early boot path was not yet proven.

Therefore the rebuild does **not** restart by blindly recreating the first DTS/image work. Those are historical project artifacts. The next technical work must begin from the verified repository state and advance toward the first real G2 SD boot.

## 6. Clean starting state for the next cycle

The next active task must be explicitly identified before work begins.

The assistant must first inspect:

- current `main`;
- PR #6 and PR #9 diffs/results;
- current roadmap and hardware research;
- current CI workflows;
- any unresolved provider/boot-chain blockers.

Only then should one new development task be started.
