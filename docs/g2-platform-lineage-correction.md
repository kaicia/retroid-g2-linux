# G2 Platform Lineage Correction — 2026-08-22

The earlier SM8550/SM8650 assumptions are invalid for this project.

Authoritative G2 evidence from `dumps/g2/` identifies the hardware as `Cliffs/pineapple`:
- model: Qualcomm Technologies, Inc. Cliffs MTP
- compatible: qcom,cliffs-mtp / qcom,cliffs / qcom,cliffsp-mtp / qcom,cliffsp / qcom,mtp
- ro.boot.hardware.revision: Qualcomm G2 Gen 2
- ro.boot.product.vendor.sku: cliffs
- Android kernel: 6.1.115-android14-11

From this point forward, G2 platform identity must be established from exact Cliffs source evidence. Commercial Snapdragon names and RP6/Odin2 similarity are not acceptable substitutes.

The next kernel audit is therefore Cliffs/pineapple source lineage first, followed by exact GCC/interconnect/pinctrl/PMXR2230/SMMU/SDHCI mapping. No bootable DTS changes until that audit is complete.
