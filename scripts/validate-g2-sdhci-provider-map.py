#!/usr/bin/env python3
"""Validate the G2 (Cliffs) SDHCI interconnect provider map.

This script checks that the G2 SDHCI compile candidate uses the
source-verified Cliffs interconnect endpoint IDs/topology and forbids the
SM7635/Milos per-NoC topology and SM8550/SM8650 board values.

It does NOT prove DTS compilation, kernel integration, or bootability.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
candidate = root / "dts/g2-sdhci-cliffs-merge.dtsi"
provider = root / "dts/g2-cliffs-interconnect.dtsi"
header = root / "dts/qcom,cliffs.h"

text = candidate.read_text(encoding="utf-8")
ptext = provider.read_text(encoding="utf-8")
htext = header.read_text(encoding="utf-8")

failures = []

def check(cond, label):
    print(f"{'PASS' if cond else 'FAIL'}: {label}")
    if not cond:
        failures.append(label)

# --- header: minimum Cliffs endpoint IDs ---
check('#define MASTER_SDCC_2\t\t\t\t47' in htext, "header: MASTER_SDCC_2 = 47")
check('#define SLAVE_EBI1\t\t\t\t512' in htext, "header: SLAVE_EBI1 = 512")
check('#define MASTER_APPSS_PROC\t\t\t2' in htext, "header: MASTER_APPSS_PROC = 2")
check('#define SLAVE_SDCC_2\t\t\t\t542' in htext, "header: SLAVE_SDCC_2 = 542")
check('MASTER_SDCC_2\t\t\t\t8' not in htext, "header: no Milos MASTER_SDCC_2=8")
check('SLAVE_EBI1\t\t\t\t1' not in htext, "header: no Milos SLAVE_EBI1=1")
check('SLAVE_SDCC_2\t\t\t\t20' not in htext, "header: no Milos SLAVE_SDCC_2=20")

# --- provider: four Cliffs NoC compatible overrides ---
check('compatible = "qcom,cliffs-aggre1_noc";' in ptext, "provider: aggre1_noc -> qcom,cliffs-aggre1_noc")
check('compatible = "qcom,cliffs-mc_virt";' in ptext, "provider: mc_virt -> qcom,cliffs-mc_virt")
check('compatible = "qcom,cliffs-gem_noc";' in ptext, "provider: gem_noc -> qcom,cliffs-gem_noc")
check('compatible = "qcom,cliffs-cnoc_cfg";' in ptext, "provider: cnoc_cfg -> qcom,cliffs-cnoc_cfg")

# --- candidate SDHCI node ---
check('compatible = "qcom,milos-sdhci", "qcom,sdhci-msm-v5";' in text, "candidate: SDHCI compatible")
check('0x08804000' in text, "candidate: SDHCI base 0x08804000")
check('GIC_SPI 207' in text, "candidate: HC IRQ 207")
check('GIC_SPI 223' in text, "candidate: power IRQ 223")
check('GCC_SDCC2_AHB_CLK' in text, "candidate: AHB clock")
check('GCC_SDCC2_APPS_CLK' in text, "candidate: core clock")
check('GCC_SDCC2_BCR' in text, "candidate: SDCC2 reset")
check('status = "disabled";' in text, "candidate: non-boot disabled status")

# --- Cliffs topology (aggre1_noc for the SDCC2 master path) ---
check('&aggre1_noc MASTER_SDCC_2' in text, "candidate: SDCC2 master on aggre1_noc")
check('&mc_virt SLAVE_EBI1' in text, "candidate: EBI1 slave on mc_virt")
check('&gem_noc MASTER_APPSS_PROC' in text, "candidate: APPSS master on gem_noc")
check('&cnoc_cfg SLAVE_SDCC_2' in text, "candidate: SDCC2 slave on cnoc_cfg")
check('interconnect-names = "sdhc-ddr", "cpu-sdhc";' in text, "candidate: interconnect names")

# --- forbidden values (comment-aware: skip lines inside /* */) ---
def active_lines(s):
    out = []
    for raw in s.splitlines():
        line = raw
        if '/*' in line:
            line = line[:line.index('/*')]
        if '*/' in raw:
            tail = raw[raw.index('*/') + 2:]
            out.append(tail)
        out.append(line)
    return '\n'.join(out)

active = active_lines(text)
for needle, label in (
    ('&aggre2_noc MASTER_SDCC_2', "forbidden: SDCC2 master on aggre2_noc (Milos)"),
    ('&pm8550_gpios 12', "forbidden: SM8550 card-detect GPIO"),
    ('vmmc-supply = <&vreg_l13b>', "forbidden: unverifiable regulator phandle"),
    ('vqmmc-supply = <&vreg_l23b>', "forbidden: unverifiable regulator phandle"),
):
    check(needle not in active, label)

if failures:
    print("\nValidation failed:")
    for item in failures:
        print(f"- {item}")
    sys.exit(1)

print("\nAll static provider-map checks passed.")
print("This does not prove DTS compilation, kernel integration, or bootability.")
