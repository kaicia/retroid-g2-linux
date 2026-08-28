#!/usr/bin/env python3
"""Validate the minimum G2 Cliffs interconnect provider map.

Checks that:
  * dts/qcom,cliffs.h carries the source-verified Cliffs flat-namespace IDs
    (MASTER_SDCC_2=47, SLAVE_SDCC_2=542, SLAVE_EBI1=512, MASTER_APPSS_PROC=2)
    and not the SM7635/Milos per-NoC values.
  * dts/g2-cliffs-interconnect.dtsi overrides the four NoC compatible strings
    to the physical-G2 qcom,cliffs-* values.
  * dts/g2-sdhci-cliffs-merge.dtsi uses the Cliffs topology
    (aggre1_noc, mc_virt, gem_noc, cnoc_cfg) and the G2 hardware-derived
    SDCC2 facts, and forbids copied SM8550/SM8650/board-specific values.

This is a static consistency check; it does not prove DTS compilation,
kernel integration, or bootability.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
HEADER = ROOT / "dts" / "qcom,cliffs.h"
NOC_DTSI = ROOT / "dts" / "g2-cliffs-interconnect.dtsi"
MERGE_DTSI = ROOT / "dts" / "g2-sdhci-cliffs-merge.dtsi"

failures = []


def check(label, ok):
    print(f"{'PASS' if ok else 'FAIL'}: {label}")
    if not ok:
        failures.append(label)


def read(path):
    return path.read_text(encoding="utf-8")


# 1. Header ID values (source-verified Cliffs flat namespace).
header = read(HEADER)
expected_ids = {
    "MASTER_SDCC_2": 47,
    "SLAVE_SDCC_2": 542,
    "SLAVE_EBI1": 512,
    "MASTER_APPSS_PROC": 2,
}
for name, value in expected_ids.items():
    m = re.search(rf"#define\s+{name}\s+(\d+)", header)
    ok = bool(m) and int(m.group(1)) == value
    check(f"qcom,cliffs.h {name} = {value}", ok)

# 2. NoC compatible overrides.
noc = read(NOC_DTSI)
for compat in (
    "qcom,cliffs-aggre1_noc",
    "qcom,cliffs-mc_virt",
    "qcom,cliffs-gem_noc",
    "qcom,cliffs-cnoc_cfg",
):
    check(f"g2-cliffs-interconnect.dtsi compatible {compat}", compat in noc)

# 3. SDCC2 merge fragment topology + G2 facts.
merge = read(MERGE_DTSI)
required_merge = {
    'compatible = "qcom,milos-sdhci", "qcom,sdhci-msm-v5";': "Milos SDHCI compatible",
    "0x08804000": "SDHCI base",
    "GIC_SPI 207": "HC IRQ",
    "GIC_SPI 223": "power IRQ",
    "GCC_SDCC2_AHB_CLK": "AHB clock",
    "GCC_SDCC2_APPS_CLK": "core clock",
    "GCC_SDCC2_BCR": "SDCC2 reset",
    "&aggre1_noc MASTER_SDCC_2": "SDCC2 master on aggre1_noc (Cliffs)",
    "&mc_virt SLAVE_EBI1": "EBI1 slave on mc_virt (Cliffs)",
    "&gem_noc MASTER_APPSS_PROC": "APPSS master on gem_noc (Cliffs)",
    "&cnoc_cfg SLAVE_SDCC_2": "SDCC2 config slave on cnoc_cfg (Cliffs)",
    "apps_smmu 0x540 0": "SMMU stream tuple",
    "0x0007442c": "DLL config",
    "0x80040868": "DDR config",
    'status = "disabled";': "non-boot status",
}
for needle, label in required_merge.items():
    check(f"g2-sdhci-cliffs-merge.dtsi {label}", needle in merge)

# 4. Forbidden content: SM7635/Milos aggre2 topology and SM8550/SM8650/board
#    numeric IDs must not appear in the G2 Cliffs merge fragment.
forbidden = {
    "&aggre2_noc MASTER_SDCC_2": "SM7635/Milos aggre2_noc SDCC2 topology",
    "GPIO_ACTIVE_HIGH": "Fairphone/board active-high card-detect",
    "&pm8550_gpios 12": "SM8650 PM8550 card-detect GPIO",
    "&tlmm 65": "Fairphone board card-detect GPIO 65",
}
for needle, label in forbidden.items():
    ok = needle not in merge
    check(f"forbidden {label} absent", ok)
    if not ok:
        failures.append(f"forbidden content present: {needle}")

if failures:
    print("\nValidation failed:")
    for item in failures:
        print(f"- {item}")
    sys.exit(1)

print("\nAll static G2 Cliffs interconnect provider-map checks passed.")
print("This does not prove DTS compilation, kernel integration, or bootability.")
