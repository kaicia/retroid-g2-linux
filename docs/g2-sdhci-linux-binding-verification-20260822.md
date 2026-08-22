# G2 SDHCI Linux binding verification

Date: 2026-08-22

## Purpose

Verify what can be carried from the physical G2 DT into a Linux DTS before generating the first draft.

## Evidence from physical G2

The physical G2 audit established the SDHCI node at `0x08804000`, `qcom,sdhci-msm-v5`, 4-bit bus width, `iface/core` clocks, `core_reset`, OPP entries at 100 MHz and 202 MHz, VDD/VDD-IO supplies, Apps SMMU, `sdc2_on/off` pinctrl, CD GPIO 31 through the Cliffs pinctrl controller, and four Cliffs interconnect tuples. The exact physical interconnect tuple is `<0x1a2 0x2f 0x189 0x200 0x1a3 0x2 0x1a4 0x21e>`.

## External Linux verification

The current Linux DeviceTree documentation shows Qualcomm interconnect consumers represented by provider labels plus provider-specific master/slave IDs, and the generic interconnect framework treats providers as software definitions of hardware and endpoints as provider nodes. Therefore the four physical G2 cell values cannot be translated into Linux macros without the selected Cliffs provider definitions.

Current upstream Linux source/binding indexes expose Qualcomm interconnect bindings for several SoCs, including SM8550/SM8650 RPMh-related material, but the searches performed for this audit did not establish an upstream `qcom,cliffs-*` provider binding. A proprietary Qualcomm/Android Cliffs device-tree source is known to exist, but that is not sufficient evidence that the same provider implementation exists in the selected Linux tree.

## Decision

Do NOT create the first bootable DTS yet.

The next required task is to select the exact ROCKNIX/pocknix kernel commit used as the G2 base and inspect that tree itself for:

- Cliffs interconnect provider definitions
- Cliffs GCC clock/reset definitions
- Cliffs pinctrl binding/driver
- PMXR2230 regulator binding/driver
- Cliffs SMMU binding/driver
- downstream `sdhci-msm` implementation and DT parsing

Only after those source-level definitions are present can the physical G2 values be translated into valid Linux labels/macros.

## Useful upstream reference

Linux DTS coding guidance demonstrates the expected provider-label + endpoint-ID form for interconnect consumers. The generic interconnect documentation defines provider, node, endpoint, and path semantics.

## Safety boundary

This stage is source/DTS analysis only. No bootable image, SD-card write, repartitioning, firmware update, bootloader modification, or Android storage modification is part of this step.
