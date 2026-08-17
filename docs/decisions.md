# Project Decisions

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
