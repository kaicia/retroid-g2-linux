# Retroid Pocket G2 SteamOS Porting Project — Project Status

## 1. Final Goal

The final goal is to run SteamOS/Linux on the Retroid Pocket G2 without permanently replacing the existing Android installation.

Target behavior:

- SteamOS/Linux is installed on a microSD card.
- With the SD card inserted, the device boots SteamOS/Linux.
- With the SD card removed, the original Android system continues to boot normally.
- The development path should therefore prioritize a non-destructive, SD-based dual-boot design.

The eventual goal is a usable SteamOS gaming environment on the G2, but early development must prioritize safe investigation and bootability.

## 2. Project Direction

Keep the original Android installation intact during early development. Do not begin by wiping or replacing the internal Android system.

Use existing public Linux/SteamOS porting work for Snapdragon handhelds as references, especially projects and research around:

- Retroid Pocket 5
- Retroid Pocket 6
- Odin 3
- Armada
- PockNix
- Other relevant Snapdragon Linux/SteamOS handheld projects

These projects should be studied for reusable approaches to the boot chain, kernel, Device Tree, GPU, display, input, audio, wireless, power management, and other hardware support. Do not assume that code is directly portable to the G2 without verification.

## 3. G2 Hardware and Software Investigation

Before modifying the kernel or boot chain, collect and document actual G2 information.

Areas to investigate include:

- SoC and CPU configuration
- GPU
- RAM
- Internal storage and storage interface
- Display and touch
- Wi-Fi and Bluetooth
- USB
- microSD behavior
- Buttons and joysticks
- Audio
- Battery and charging
- Cameras if relevant
- Power management
- Android version
- Current kernel version/source information
- Boot, vendor, dtbo and related partitions
- Device Tree
- Bootloader structure

The initial development phase is information gathering and comparison, not assuming that a known Snapdragon handheld configuration applies to G2.

## 4. Snapdragon G2 Gen 2 Driver Investigation

Snapdragon G2 Gen 2 Linux support is a major research area.

Investigate, as applicable:

- Adreno GPU support
- Mesa
- Vulkan
- DRM/KMS
- Display pipeline
- Qualcomm SoC drivers
- Wi-Fi/Bluetooth
- Audio
- USB
- Power management

No G2 driver modification should be treated as completed until it has been actually investigated, documented, and verified.

## 5. GitHub Repository and Documentation

Repository:

`kaicia/retroid-g2-linux`

GitHub is the project's central source of truth and long-term memory. Important decisions, research results, logs, code, test results, and Codex results should be preserved in the repository rather than relying only on chat history.

Planned documentation structure:

```text
retroid-g2-linux/
├── README.md
├── docs/
│   ├── project-status.md
│   ├── development-workflow.md
│   ├── codex-workflow.md
│   ├── progress.md
│   ├── hardware.md
│   ├── boot.md
│   ├── device-tree.md
│   ├── rp5.md
│   └── rp6.md
├── dumps/
│   └── g2/
├── dts/
│   └── g2/
└── scripts/
```

Purpose of key documents:

- `project-status.md` — current project state, goals, decisions, and workflow
- `development-workflow.md` — how ChatGPT, GitHub, Codespaces, and Codex are used
- `codex-workflow.md` — verified Codex Cloud automation procedure and safety rules
- `progress.md` — chronological project progress
- `hardware.md` — G2 hardware investigation
- `boot.md` — boot chain and boot process
- `device-tree.md` — Device Tree/DTS analysis
- `rp5.md` / `rp6.md` — reference-platform research
- `dumps/g2/` — G2 dumps collected during research
- `dts/g2/` — G2 Device Tree work
- `scripts/` — investigation, build, and automation scripts

## 6. Codespaces and Codex

GitHub Codespaces is part of the planned development environment.

The project direction is to delegate actual code investigation, modification, testing, and repository work to Codex whenever practical, while ChatGPT handles planning, review, verification, and deciding the next task.

## 7. Verified Codex Cloud Automation

A critical workflow has now been tested successfully.

A normal GitHub Issue containing `@codex` did not trigger a Codex Cloud task in the initial test.

A Pull Request comment containing `@codex` DID trigger a Codex Cloud task.

Test procedure:

1. Create a temporary branch.
2. Create a harmless test file.
3. Open a draft PR against `main`.
4. Add a PR conversation comment containing `@codex` and explicit instructions.
5. Codex Cloud automatically starts a task in the repository context.
6. Codex reports the result back in the PR conversation.

This was verified on test PR #2. Codex explicitly reported that the PR comment started a Codex task and that it was running in the checked-out repository at the PR head commit.

Therefore the intended workflow is now:

```text
ChatGPT
  ↓
GitHub PR / PR comment containing @codex + task instructions
  ↓
Codex Cloud automatically starts
  ↓
Codex checks out the repository and performs the requested work
  ↓
Codex reports results in GitHub
  ↓
ChatGPT reads and verifies the GitHub result
  ↓
Next task is planned and issued through GitHub
```

This removes the need for the user to manually copy ChatGPT's task instructions into Codex for each project task.

## 8. Codex Safety Rules

For every real project task, Codex must follow these rules.

Before making changes:

```bash
git status
git diff
```

During the task:

- Do not modify unrelated files.
- Do not delete existing project work without explicit justification.
- Create or modify only files necessary for the requested task.
- Run appropriate tests/checks when possible.

After the task:

```bash
git status
git diff
```

Only project-related changes may be committed.

If the task requires it, Codex may commit and push, but it must verify the working tree and diff first and must not include unrelated files.

## 9. Result Verification

Codex results must be preserved in GitHub through appropriate combinations of:

- PR comments
- Commits
- Pull requests
- Changed files
- Test output
- Research notes
- Logs

ChatGPT should inspect the actual GitHub result before treating a task as completed.

The Codex `chatgpt.com/s/cd_...` share link may not be directly readable by ChatGPT's web retrieval layer. Therefore GitHub is the authoritative result channel for this project.

## 10. GitHub Write Access Verification

GitHub write access is now confirmed to work from the ChatGPT GitHub connection.

Previously, attempts to write project documentation from ChatGPT did not work because the connected GitHub authorization/write state was not correctly available at that time.

The current connection is different and has been verified by an actual write operation:

1. ChatGPT accessed `kaicia/retroid-g2-linux`.
2. ChatGPT created `docs/project-status.md` directly on `main`.
3. GitHub accepted the file creation and created a real commit.
4. The resulting commit SHA was verified.
5. ChatGPT subsequently fetched the file from `main` and verified its contents.

This means ChatGPT can currently perform direct GitHub documentation/repository writes through the connected GitHub integration.

This capability is separate from the Codex Cloud workflow. The preferred division of responsibility is:

- ChatGPT: project planning, documentation/status updates, review, verification, and GitHub project management when appropriate.
- Codex Cloud: actual code investigation, code modification, testing, and implementation work whenever practical.

Direct ChatGPT GitHub writes should not bypass the Codex workflow for substantial implementation work unless there is a clear reason to do so.

## 11. Current Phase

### Phase 0 — Development and Project Workflow Setup

Completed/verified:

- [x] GitHub repository created
- [x] GitHub access verified
- [x] GitHub write access verified with an actual documentation commit
- [x] Codespaces identified as a development environment
- [x] Project documentation structure planned
- [x] GitHub chosen as the project's persistent record
- [x] Codex Cloud selected as the main coding/automation assistant
- [x] Codex GitHub repository access configured
- [x] Codex Cloud repository connection verified
- [x] `@codex` PR-comment trigger tested
- [x] Codex Cloud task execution from a PR comment verified
- [x] Codex result reporting back into GitHub verified

### Next — Phase 1: G2 Hardware and Software Information

1. Collect actual G2 hardware information.
2. Collect Android/kernel/partition information.
3. Obtain and preserve relevant dumps.
4. Analyze the boot chain.
5. Extract/analyze the Device Tree.
6. Compare the G2 against RP5/RP6/Odin 3 and other Snapdragon Linux projects.
7. Study Armada and PockNix for reusable components and methods.
8. Identify the minimum Linux support required for SD-card boot.

Later phases will cover:

- Phase 2 — Boot chain / Device Tree
- Phase 3 — Kernel / Drivers
- Phase 4 — SD-card Linux boot
- Phase 5 — SteamOS integration
- Phase 6 — Real G2 hardware testing

## 12. Test PR

PR #2 was created only to verify the Codex Cloud PR-comment trigger. It must not be merged into `main`.

After the workflow is fully documented, the temporary test branch/file/PR can be removed.
