# G2 Linux Kernel Lineage Selection — 2026-08-22

## Decision target
Select the concrete Linux kernel lineage for the first G2 SDHCI bring-up without assuming that the G2 is an SM8550/SM8650 product.

## Evidence from the project repository
The G2 ADB audit establishes the device as `Snapdragon G2 Gen 2 / Cliffs`, with Android DT compatibles `qcom,cliffs-mtp`, `qcom,cliffs`, `qcom,cliffsp-mtp`, `qcom,cliffsp`, and `qcom,mtp`. The SD controller is `/soc/sdhci@8804000` and the internal Android boot storage is UFS. The project explicitly forbids copying provider IDs from RP6/SM8550/SM8650.

## Candidate base: ROCKNIX/pocknix kernel recipe
The current pocknix-os kernel documentation says its RP6/SM8550 kernel is a reproducible snapshot of ROCKNIX `next` plus selected patches and a config. Its stock kernel source pin is Linux `7.1.5` with SHA256 `22a0196b3cbcdf34dc27b77561f4d040585fd3447edc9ab3531a1ac79e3041e7`. The pocknix SM8550 profile is explicitly for Retroid Pocket 6 / AYN Odin 2 family and therefore its SM8550 device patches and DTBs are NOT G2 board support.

## Why this candidate is useful
- It gives us a concrete modern kernel baseline (Linux 7.1.5) already proven in an ARM handheld SteamOS-like workflow.
- It gives us the exact build/patch/config structure used by pocknix and referenced by Armada.
- Its SDHCI work is a useful implementation reference for Qualcomm handheld microSD support.

## Why it is not yet the G2 kernel
The pocknix SM8550 device tree and SM8550-specific patch stack cannot be copied to G2. G2 has a Cliffs-specific provider graph, and the project has already source-verified Cliffs GCC/interconnect IDs that differ from SM8550 values. The selected base must therefore be treated as a kernel-version/build-system candidate, not as a board-support source.

## Current required source work
Before drafting a compilable G2 DTS or patching the kernel:
1. Compare Linux 7.1.5's Qualcomm SDHCI driver against the G2 Android DT properties (`qcom,dll-hsr-list`, OPP, restore-after-CX-collapse, interconnects, IOMMU).
2. Verify whether Linux 7.1.5 already contains Cliffs GCC, interconnect, pinctrl, PMXR2230 and SMMU support. If not, identify the smallest source-level backport set from the exact Cliffs Linux implementation already located.
3. Map G2's PMXR2230 L13/L23, `sdc2_on/off`, GPIO31 card detect and apps-SMMU stream ID to Linux bindings without importing SM8550 numeric IDs.
4. Only after those checks, produce a compilable DTS and kernel patch set.

## Safety gate
No G2 flashing, boot-partition modification, UFS modification, ABL modification, or Android modification is part of this phase. The project target remains microSD Linux/SteamOS while preserving internal Android.

## Source references
- G2 evidence audit: `docs/g2-adb-evidence-audit-20260822.md`
- Cliffs source mapping: `docs/g2-cliffs-linux-source-mapping-20260822.md`
- Provider mapping: `docs/g2-cliffs-provider-mapping-progress-20260822.md`
- Static DTS skeleton: `dts/g2/g2-sdhci-linux-analysis.dts`
- External kernel recipe reference: `shuuri-labs/pocknix-os`, `kernel/README.md`, `kernel/sm8550/kernel.conf`, `devices/sm8550/profile.conf`
