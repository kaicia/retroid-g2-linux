# DeepSeek compile task — 2026-08-27

Task for OpenCode / DeepSeek:

1. Clone the Linux kernel source at the pinned revision `73e3f0710014fe6d4ed98cfc02292f6121db7558` into a temporary `linux` directory.
2. Run a known-good baseline build for `arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb`.
3. Copy `dts/g2-sdhci-milos-merge.dtsi` into the Linux QCOM DTS directory.
4. Create `g2-sdhci-compile-test.dts` including `milos.dtsi`, `pm7550.dtsi`, and the G2 merge fragment.
5. Add a temporary `dtb-y += g2-sdhci-compile-test.dtb` target to the QCOM DTS Makefile.
6. Compile the G2 candidate DTB with the Linux build system.
7. Do not modify any G2 hardware or boot files.
8. Report the first failure exactly if compilation fails; do not hide or guess errors.
9. Save the complete command/output summary to `docs/deepseek-compile-result-20260827.md` and commit it.

Notes updated by G2-C-0001-R1: the G2 merge fragment uses the G2-confirmed SMMU stream tuple `<&apps_smmu 0x140 0>`; the stale upstream `0x540` is preserved in git history only.
