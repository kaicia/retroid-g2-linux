#!/usr/bin/env python3
"""Static provider-map validator for the Retroid Pocket G2 (Cliffs) SDCC2 DTS.

Checks the source-supported Cliffs interconnect endpoint IDs/topology against
the G2 SDHCI compile candidate. Forbids the SM7635/Milos per-NoC IDs and the
SM8550/SM8650 device-specific values that must not be copied to the G2.
"""
from pathlib import Path
import sys

HEADER = Path("dts/qcom,cliffs.h")
NOC = Path("dts/g2-cliffs-interconnect.dtsi")
FRAGMENT = Path("dts/g2-sdhci-cliffs-merge.dtsi")


def read(path):
    return path.read_text(encoding="utf-8")


header = read(HEADER)
noc = read(NOC)
frag = read(FRAGMENT)

results = []


def check(ok, label):
    results.append((ok, label))


# --- Cliffs interconnect ID header (source-verified flat vendor IDs) ---
header_id_map = {
    "MASTER_SDCC_2": 47,
    "SLAVE_SDCC_2": 542,
    "SLAVE_EBI1": 512,
    "MASTER_APPSS_PROC": 2,
}
for name, value in header_id_map.items():
    check(f"#define {name}" in header, f"header defines {name}")
    # Require the exact value on the same define line (robust to whitespace).
    found = False
    for line in header.splitlines():
        if line.lstrip().startswith(f"#define {name}"):
            if str(value) in line.split():
                found = True
            break
    check(found, f"header {name} = {value}")

# --- Cliffs NoC provider compatible overrides ---
noc_compatibles = {
    "aggre1_noc": "qcom,cliffs-aggre1_noc",
    "mc_virt": "qcom,cliffs-mc_virt",
    "gem_noc": "qcom,cliffs-gem_noc",
    "cnoc_cfg": "qcom,cliffs-cnoc_cfg",
}
for label, compat in noc_compatibles.items():
    check(f'compatible = "{compat}";' in noc, f"{label} -> {compat}")

# --- G2 SDCC2 node: Cliffs interconnect topology ---
frag_checks = {
    "&aggre1_noc MASTER_SDCC_2 QCOM_ICC_TAG_ALWAYS": "SDCC2 master on Cliffs aggre1_noc",
    "&mc_virt SLAVE_EBI1 QCOM_ICC_TAG_ALWAYS": "SDCC2 DDR destination mc_virt/EBI1",
    "&gem_noc MASTER_APPSS_PROC QCOM_ICC_TAG_ACTIVE_ONLY": "cpu-sdhc source gem_noc/APPSS_PROC",
    "&cnoc_cfg SLAVE_SDCC_2 QCOM_ICC_TAG_ACTIVE_ONLY": "cpu-sdhc config cnoc_cfg/SDCC_2",
    'interconnect-names = "sdhc-ddr", "cpu-sdhc";': "interconnect names sdhc-ddr/cpu-sdhc",
    "0x08804000": "SDHCI base",
    "GIC_SPI 207": "HC IRQ",
    "GIC_SPI 223": "power IRQ",
    "GCC_SDCC2_AHB_CLK": "AHB clock",
    "GCC_SDCC2_APPS_CLK": "core clock",
    "GCC_SDCC2_BCR": "SDCC2 reset",
    "apps_smmu": "SMMU provider label",
    "0x0007442c": "DLL config",
    "0x80040868": "DDR config",
    'status = "disabled";': "non-boot status",
}
for needle, label in frag_checks.items():
    check(needle in frag, label)

# --- Forbidden: SM7635/Milos topology and SM8550/SM8650 values ---
forbidden = {
    "&aggre2_noc MASTER_SDCC_2": "SM7635/Milos aggre2_noc SDCC2 topology",
    "&pm8550_gpios 12": "SM8650 PM8550 GPIO card-detect",
    "GPIO_ACTIVE_HIGH": "active-high card-detect (G2 is active-low)",
    "qcom,milos-aggre1-noc": "SM7635/Milos aggre1-noc compatible",
    "qcom,milos-mc-virt": "SM7635/Milos mc-virt compatible",
    "qcom,milos-gem-noc": "SM7635/Milos gem-noc compatible",
    "qcom,milos-cnoc-cfg": "SM7635/Milos cnoc-cfg compatible",
}
for needle, label in forbidden.items():
    check(needle not in frag, f"no {label} in SDHCI fragment")
    check(needle not in noc, f"no {label} in NoC provider fragment")

# --- Forbidden: SM7635/Milos numeric endpoint IDs must not be the G2 values ---
milos_ids = {
    "MASTER_SDCC_2": 8,
    "SLAVE_SDCC_2": 20,
    "SLAVE_EBI1": 1,
}
for name, value in milos_ids.items():
    for line in header.splitlines():
        if line.lstrip().startswith(f"#define {name}"):
            check(str(value) not in line.split(),
                  f"no SM7635/Milos {name}={value} in Cliffs header")
            break

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
