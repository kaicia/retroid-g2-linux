# Important Conversation Context

## 2026-08-17

- Project goal: investigate and develop a Linux/SteamOS porting path for Retroid Pocket G2 (Snapdragon G2 Gen 2).
- GitHub repository: kaicia/retroid-g2-linux
- Codespace is being used from mobile Chrome.
- Workflow agreed: save command results to files, commit/push them to GitHub, then ChatGPT directly checks GitHub before continuing.
- User prefers command explanations and a final copy/paste block.
- User prefers multiple commands in one copy/paste block rather than receiving commands one at a time.
- Important requests and decisions should be documented in GitHub so future sessions can resume accurately.
- Initial project directories and documentation were created and pushed.
- ADB was installed in Codespace; version 34.0.4-debian was confirmed.
- Codespace adb cannot automatically see a G2 connected by USB to the S20 FE.
- Termux was installed on the S20 FE to investigate an Android-side ADB/remote-ADB approach.
- G2 has not yet been connected to the S20 FE.
- Next test: connect G2 to S20 FE and run adb devices in Termux.
