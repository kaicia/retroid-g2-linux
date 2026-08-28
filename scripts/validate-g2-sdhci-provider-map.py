#!/usr/bin/env python3
"""Static provider-map validator for the Retroid Pocket G2 (Cliffs) SDCC2 DTS.

Checks the source-supported Cliffs interconnect endpoint IDs/topology against
the G2 SDHCI compile candidate. Forbids the SM7635/Milos per-NoC IDs and the
SM8550/SM8650 device-specific values that must not be copied to the G2.
"""
from pathlib import Path
import sys

HEADER = Path("dts/qcom,cliffs.h")
FRAGMENT = Path("dts/g2-sdhci-cliffs-merge.dtsi")
NOC = Path("dts/g2-cliffs-interconnect.dtsi")

def read(p):
    return p.read_text(encoding="utf-8")

header = read(HEADER)
frag = read(FRAGMENT)
noc = read(NOC)

results = []
def check(ok, label):
    results.append((ok, label))

# --- Cliffs interconnect ID header (source-verified flat IDs) ---
for needle, label in (
    ("MASTER_SDCC_2", "Cliffs header MASTER_SDCC_2"),
    ("SLAVE_SDCC_2", "Cliffs header SLAVE_SDCC_2"),
    ("SLAVE_EBI1", "Cliffs header SLAVE_EBI1"),
    ("MASTER_APPSS_PROC", "Cliffs header MASTER_APPSS_PROC"),
    ("47", "Cliffs MASTER_SDCC_2 = 47"),
    ("542", "Cliffs SLAVE_SDCC_2 = 542"),
    ("512", "Cliffs SLAVE_EBI1 = 512"),
    ("2", "Cliffs MASTER_APPSS_PROC = 2"),
):
    check(needle in header, label)

# --- G2 SDCC2 node: Cliffs interconnect topology ---
for needle, label in (
    ("&aggre1_noc MASTER_SDCC_2 QCOM_ICC_TAG_ALWAYS", "SDCC2 master on Cliffs aggre1_noc"),
    ("&mc_virt SLAVE_EBI1 QCOM_ICC_TAG_ALWAYS", "SDCC2 DDR destination mc_virt/EBI1"),
    ("&gem_noc MASTER_APPSS_PROC QCOM_ICC_TAG_ACTIVE_ONLY", "cpu-sdhc source gem_noc/APPSS_PROC"),
    ("&cnoc_cfg SLAVE_SDCC_2 QCOM_ICC_TAG_ACTIVE_ONLY", "cpu-sdhc config cnoc_cfg/SDCC_2"),
    ('interconnect-names = "sdhc-ddr", "cpu-sdhc";', "interconnect names sdhc-ddr/cpu-sdhc"),
    ("0x08804000", "SDHCI base"),
    ("GIC_SPI 207", "HC IRQ"),
    ("GIC_SPI 223", "power IRQ"),
    ("GCC_SDCC2_AHB_CLK", "AHB clock"),
    ("GCC_SDCC2_APPS_CLK", "core clock"),
    ("GCC_SDCC2_BCR", "SDCC2 reset"),
    ("apps_smmu", "SMMU provider label"),
    ("0x0007442c", "DLL config"),
    ("0x80040868", "DDR config"),
    ('status = "disabled";', "non-boot status"),
):
    check(needle in frag, label)

# --- Cliffs NoC provider compatible overrides ---
for needle, label in (
    ('compatible = "qcom,cliffs-aggre1_noc";', "aggre1_noc Cliffs compatible"),
    ('compatible = "qcom,cliffs-mc_virt";', "mc_virt Cliffs compatible"),
    ('compatible = "qcom,cliffs-gem_noc";', "gem_noc Cliffs compatible"),
    ('compatible = "qcom,cliffs-cnoc_cfg";', "cnoc_cfg Cliffs compatible"),
):
    check(needle in noc, label)

# --- Forbidden: SM7635/Milos per-NoC IDs and topology ---
forbidden = {
    "&aggre2_noc MASTER_SDCC_2": "SM7635 aggre2_noc SDCC2 topology",
    "&pm8550_gpios 12": "SM8650 PM8550 GPIO card-detect",
    "GPIO_ACTIVE_HIGH": "active-high card-detect (G2 is active-low)",
}
for needle, label in forbidden.items():
    check(needle not in frag, f"forbidden {label}")

# --- Forbidden: SM7635 numeric IDs must not appear as the Cliffs values ---
# The Cliffs header must not carry the Milos values 8/20/1 for SDCC2/EBI1.
if "MASTER_SDCC_2" in header:
    check("MASTER_SDCC_2\t\t\t8" not in header and "MASTER_SDCC_2  8" not in header,
          "no SM7635 MASTER_SDCC_2=8 in header")

failed = [label for ok, label in results if not ok]
for ok, label in results:
    print(("PASS" if ok else "FAIL") + f": {label}")

if failed:
    print("Validation failed:")
    for label in failed:
        print(f"- {label}")
    sys.exit(1)

print("All static provider-map checks passed.")
print("This does not prove DTS compilation, kernel integration, or bootability.")
