#!/usr/bin/env python3
from pathlib import Path
import sys

candidate = Path("dts/g2-sdhci-upstream-candidate.dtsi")
text = candidate.read_text(encoding="utf-8")
required = {
    'compatible = "qcom,milos-sdhci", "qcom,sdhci-msm-v5";': "Milos SDHCI compatible",
    '0x08804000': "SDHCI base",
    'GIC_SPI 207': "HC IRQ",
    'GIC_SPI 223': "power IRQ",
    'GCC_SDCC2_AHB_CLK': "AHB clock",
    'GCC_SDCC2_APPS_CLK': "core clock",
    'GCC_SDCC2_BCR': "SDCC2 reset",
    'MASTER_SDCC_2': "SDCC2 interconnect master",
    'SLAVE_EBI1': "EBI1 interconnect slave",
    'MASTER_APPSS_PROC': "APPSS interconnect master",
    'SLAVE_SDCC_2': "SDCC2 config slave",
    'apps_smmu 0x140 0': "SMMU stream tuple",
    'vreg_l13b': "VDD regulator",
    'vreg_l23b': "VDD-IO regulator",
    '0x0007442c': "DLL config",
    '0x80040868': "DDR config",
    'status = "disabled";': "non-boot status",
}
missing = []
for needle, label in required.items():
    if needle in text:
        print(f"PASS: {label}")
    else:
        missing.append(label)
        print(f"FAIL: {label}")
for needle in ('GPIO_ACTIVE_HIGH', '&pm8550_gpios 12', '&aggre1_noc MASTER_SDCC_2',
               'apps_smmu 0x540 0'):
    if needle in text:
        missing.append(f"forbidden candidate content: {needle}")
        print(f"FAIL: forbidden {needle}")
if missing:
    print("Validation failed:")
    for item in missing:
        print(f"- {item}")
    sys.exit(1)
print("All static provider-map checks passed.")
print("This does not prove DTS compilation, kernel integration, or bootability.")
