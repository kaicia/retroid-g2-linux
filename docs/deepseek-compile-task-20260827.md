# DeepSeek compile task — 2026-08-27

Task for OpenCode / DeepSeek:

1. Clone current Linux kernel source into a temporary `linux` directory and pin revision `73e3f0710014fe6d4ed98cfc02292f6121db7558`.
2. Run a known-good baseline build for `qcom/milos-fairphone-fp6.dtb`.
3. Copy the G2 Cliffs provider files (`dts/qcom,cliffs.h`, `dts/g2-cliffs-interconnect.dtsi`, `dts/g2-sdhci-cliffs-merge.dtsi`) into the Linux tree (header under `include/dt-bindings/interconnect/`, DTSI files under the QCOM DTS directory).
4. Create `g2-sdhci-compile-test.dts` including `milos.dtsi`, `pm7550.dtsi`, `qcom,cliffs.h`, the Cliffs interconnect override, and the G2 SDHCI merge fragment.
5. Add a temporary `dtb-y += g2-sdhci-compile-test.dtb` target to the QCOM DTS Makefile.
6. Compile the G2 candidate DTB with the Linux build system.
7. Do not modify any G2 hardware or boot files.
8. Report the first failure exactly if compilation fails; do not hide or guess errors.
9. Save the complete command/output summary to `docs/deepseek-compile-result-20260827.md` and commit it.
