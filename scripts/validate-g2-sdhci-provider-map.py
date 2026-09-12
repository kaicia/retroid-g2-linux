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
    'apps_smmu 0x140 0': "SMMU stream tuple (G2 dump value, not upstream 0x540)",
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
# Values that must never appear in an upstream-targeted G2 candidate.
# Each entry is (needle, why).
forbidden = [
    ('GPIO_ACTIVE_HIGH', 'G2 card detect is active-low; active-high is the Fairphone FP6 value'),
    ('&pm8550_gpios 12', 'SM8550 PMIC GPIO, unrelated to G2'),
    ('&aggre1_noc MASTER_SDCC_2',
     'upstream drivers/interconnect/qcom/milos.c registers the SDCC2 master in '
     'aggre2_noc; aggre1_noc is the downstream Cliffs provider for it'),
    ('apps_smmu 0x540', 'upstream milos SDCC2 stream ID; the G2 dump says 0x140'),
    ('GIC_SPI 204', 'upstream milos SDCC2 hc_irq; the G2 dump says 207'),
    ('GIC_SPI 125', 'upstream milos SDCC2 pwr_irq; the G2 dump says 223'),
    ('&tlmm 65', 'Fairphone FP6 card-detect GPIO; the G2 dump says GPIO 31'),
]
for needle, why in forbidden:
    if needle in text:
        missing.append(f"forbidden candidate content: {needle} ({why})")
        print(f"FAIL: forbidden {needle} -- {why}")
if missing:
    print("Validation failed:")
    for item in missing:
        print(f"- {item}")
    sys.exit(1)
print("All static provider-map checks passed.")
print("This does not prove DTS compilation, kernel integration, or bootability.")
