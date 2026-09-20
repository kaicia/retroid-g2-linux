# Project Decisions

## 2026-09-20

### Bricked G2 fully recovered via EDL (data preserved)
- Root cause: `fastboot set_active a` (in fastbootd) set both the GPT active slot
  and the UFS boot LUN to slot a, which has no bootable image → bootloop.
- Fix (all from bkerler/edl over EDL 9008 + WinUSB, with the verified native
  loader `xbl_s_devprg_ns.melf`): `setactiveslot b` (GPT flip) +
  `setbootablestoragedrive 2` (boot LUN → slot b) + reboot; last leftover
  `boot-fastboot` in misc/BCB cleared by rebooting to system. Device now boots
  Android 15 on slot b, all user data intact.
- Full as-executed record with every gotcha: `docs/g2-EDL-recovery-runbook.md`.
- Backup procedure to make a future incident a 5-minute restore:
  `docs/g2-edl-backup-runbook.md` (run while healthy — not yet performed).
- Key lessons: WinUSB (not QDLoader serial) is required for bkerler; two
  `firehose.py` patches were needed for reads over WinUSB; `getactiveslot`/
  `setactiveslot` reject `--memory` (auto-detects UFS); recovering the slot
  needs BOTH the GPT slot and the boot LUN.

## 2026-08-17

### Development workflow
- GitHub repository: kaicia/retroid-g2-linux
- GitHub Codespaces is the main development environment.
- Terminal results should be saved to files and pushed to GitHub rather than pasted into chat whenever practical.
- ChatGPT should inspect the resulting files directly from GitHub before deciding the next step.
- Multiple commands may be provided as one copy/paste block for convenience.
- Important project history and decisions are kept in docs/.

### ADB strategy
- Direct USB access from a mobile Chrome Codespace to a device connected to the Galaxy S20 FE is not available by default.
- We are investigating a remote-ADB architecture using the Galaxy S20 FE as the USB/ADB intermediary and Codespace as the development environment.
- The Galaxy S20 FE does not yet have the G2 connected for the ADB test.
- Termux is being used as the Android-side environment for ADB testing.

### Current state
- Termux was installed on the Galaxy S20 FE from the official Termux GitHub release.
- Termux ADB tools were installed/tested.
- The next physical test is to connect the G2 to the S20 FE and run adb devices in Termux.
