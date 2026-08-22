# Kernel Lineage Verification — 2026-08-22

## Scope

Continue source-level selection of the Linux kernel lineage for the Retroid Pocket G2 SteamOS/Armada-style port. No G2 flashing, boot modification, partition modification, or device write was performed.

## Findings

### Mainline SM8650

Current upstream Linux contains an SM8650 platform DTS and a native SM8650 interconnect driver. The SM8650 DTS includes `sdhc_2` and the SD-card node uses the standard `qcom,sdhci-msm-v5`-style SDHCI hardware path. The upstream SM8650 MTP example uses PM8550/PM8550B regulators and PM8550 GPIO12 for card detect, so it is a useful structural reference but is not a drop-in G2 solution.

The upstream SM8650 interconnect driver already defines an `xm_sdc2` node. This confirms that SDCC2 is represented in the mainline SM8650 interconnect architecture, but its provider/binding IDs are not the same thing as the Cliffs vendor IDs previously recovered from the G2/Cliffs Android source.

### Pocknix / ROCKNIX

The existing pocknix lineage remains valuable because it supplies the downstream SDHCI implementation and RP6/Odin2 device support, but it is SM8550-specific and therefore its PMIC, GPIO, SMMU and provider IDs cannot be copied to G2.

### Cliffs vendor source

The Cliffs Android source previously verified in this project contains platform-specific `gcc-cliffs.h` and `qcom,cliffs.h` bindings, with source-verified SDCC2 clock/reset/interconnect IDs. These are not yet proven to be available in the selected Linux 7.1.5/ROCKNIX kernel tree.

## Decision

Do not treat either upstream SM8650 DTS or pocknix SM8550 DTS as the final G2 DTS. The most promising strategy is now:

1. Use the ROCKNIX/pocknix kernel lineage for Armada integration and its existing SDHCI/downstream support where compatible.
2. Use upstream SM8650 Linux as the mainline reference for generic SM8650/SDCC2/interconnect architecture.
3. Identify and port only the missing Cliffs-specific provider pieces required by the G2 DTS, rather than copying an entire Android vendor kernel.
4. Keep the first G2 DTS non-bootable/WIP until GCC, interconnect, pinctrl, regulator and SMMU dependencies are all reconciled.

## Next source task

Compare the required Cliffs provider pieces against Linux 7.1.5/ROCKNIX and upstream SM8650, then enumerate the minimum kernel patches needed for G2 SDCC2. After that, construct a dependency-ordered patch plan before writing the first compilable G2 DTS.
