# G2 Platform Lineage Investigation — 2026-08-22

## Rule
Do not identify the G2 platform from commercial Snapdragon naming or from RP6/Odin2 similarity. Use exact G2 DT compatible strings, source bindings, register blocks, and vendor kernel evidence.

## G2 evidence to anchor the investigation
- DT model: Qualcomm Technologies, Inc. Cliffs MTP
- compatible: `qcom,cliffs-mtp`, `qcom,cliffs`, `qcom,cliffsp-mtp`, `qcom,cliffsp`, `qcom,mtp`
- boot property: `ro.boot.hardware.revision=Qualcomm G2 Gen 2`
- SKU: `cliffs`
- kernel: `6.1.115-android14-11`
- SDCC2: `sdhci@8804000`
- pinctrl compatible family: `qti,cliffs-pinctrl`
- SDCC2 regulators: PMXR2230 L13/L23
- SMMU: `apps-smmu@15000000`

## Current conclusion
The project must use "Cliffs/pineapple" as the hardware-source lineage label until an exact Qualcomm internal platform identifier is established from source evidence. `SM8550` and `SM8650` are not accepted as G2 identifiers merely because their Linux DTS structures look similar.

## Next source audit
Search exact strings and hardware blocks in:
- G2 DT/kernel source audit
- vendor kernel source references
- Cliffs GCC/ICC/pinctrl/PMIC/SMMU drivers
- upstream Linux Qualcomm drivers only as implementation references after exact hardware matching

The first goal is to establish the closest exact Linux source lineage, not to choose a kernel by product-family name.
