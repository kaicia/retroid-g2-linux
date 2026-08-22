# G2 Source Audit Next — 2026-08-22

Immediate next step: identify the exact Cliffs/pineapple vendor kernel/source lineage using the stored G2 DT/kernel-source audit. Search and correlate exact strings (`qcom,cliffs`, `qcom,cliffsp`, `qti,cliffs-pinctrl`, `pineapple`, `pmxr2230`, `sdhc2`, `apps-smmu`) and register/provider implementations. Do not infer the platform from Snapdragon commercial names.

After lineage identification, map only the dependencies required for SDCC2: GCC, interconnect, pinctrl, PMXR2230 regulators, SMMU, OPP/bandwidth and SDHCI quirks. Then produce a minimum Linux patch list. WIP DTS remains non-bootable until source-supported values are verified.

Safety boundary: no internal Android storage writes, no boot/DTBO flashing, no destructive device operation. Target remains microSD while preserving Android.
