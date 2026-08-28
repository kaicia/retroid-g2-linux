# G2 Cliffs interconnect provider — build result (G2-C-0002-R2)

Date: 2026-08-28
Request: G2-C-0002-R2 (fresh rerun of G2-C-0002-R1; R1 run/job/trace are NOT reused as evidence)

## 1. Summary

Implemented the minimum source-supported Cliffs interconnect provider required
by the G2 SD-only SDHCI DTS and rebuilt the G2 kernel/DTB compile candidate.

The G2 SDCC2 interconnect now uses the source-verified Cliffs vendor
`qcom,cliffs.h` IDs and topology instead of the SM7635/Milos mainline per-NoC
IDs:

| Endpoint | Cliffs ID (this work) | Previous SM7635/Milos ID |
|---|---|---|
| `MASTER_SDCC_2` | **47** (`0x2f`) | 8 (aggre2_noc) |
| `SLAVE_EBI1` | **512** (`0x200`) | 1 |
| `MASTER_APPSS_PROC` | **2** | 2 |
| `SLAVE_SDCC_2` | **542** (`0x21e`) | 20 |

Topology correction: the physical G2 SDCC2 master sits on `aggre1_noc`
(G2 raw endpoint cell `0x1a2 0x2f` on `interconnect@16E0000`), not
`aggre2_noc` as the SM7635/Milos reference used.

Build-side only. Nothing was flashed, booted, or written to any G2 device,
microSD, Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo/firmware partition.

## 2. Source lineage

- Linux kernel: `torvalds/linux` pinned to revision
  `73e3f0710014fe6d4ed98cfc02292f6121db7558` (Linus, "Merge tag 'nfs-for-7.3-1'",
  2026-08-26), as instructed by the task. Milos/SM7635 DTS present at this
  revision (`milos.dtsi`, `milos-fairphone-fp6.dts`, `pm7550.dtsi`).
- Cliffs interconnect IDs: public Qualcomm `qcom,cliffs.h` binding,
  source-verified in `docs/g2-cliffs-provider-mapping-progress-20260822.md`
  (`MASTER_SDCC_2=47`, `SLAVE_SDCC_2=542`, `SLAVE_EBI1=512`,
  `MASTER_APPSS_PROC=2`).
- G2 hardware ground truth: physical G2 ADB DT dumps in `dumps/g2/`:
  - SDHCI `/soc/mmc@8804000` base `0x08804000`, IRQs 207/223, 4-bit.
  - Interconnect phandle resolution
    (`g2-sdhci-interconnect-opp-resolution-20260821-061758.txt`):
    `0x1a2` -> `interconnect@16E0000` `qcom,cliffs-aggre1_noc`,
    `0x189` -> `interconnect@1` `qcom,cliffs-mc_virt`,
    `0x1a3` -> `interconnect@24100000` `qcom,cliffs-gem_noc`,
    `0x1a4` -> `interconnect@1600000` `qcom,cliffs-cnoc_cfg`,
    with endpoint cells `0x2f`(47), `0x200`(512), `0x2`(2), `0x21e`(542).

Not copied: SM8550/SM8650 numeric IDs, PM8550 GPIOs, and the SM7635/Milos
per-NoC interconnect IDs (8/1/20).

## 3. Changed files

- `dts/qcom,cliffs.h` — NEW minimum Cliffs interconnect ID header (4 IDs).
- `dts/g2-cliffs-interconnect.dtsi` — NEW Cliffs NoC provider compatible
  overrides (`qcom,cliffs-aggre1_noc` / `-mc_virt` / `-gem_noc` / `-cnoc_cfg`).
- `dts/g2-sdhci-cliffs-merge.dtsi` — NEW SDCC2 fragment using Cliffs
  IDs/topology; regulators/pinctrl/card-detect left as explicit UNRESOLVED.
- `dts/g2-sdhci-milos-merge.dtsi` — REMOVED (superseded; carried SM7635/Milos
  `aggre2_noc` topology and per-NoC IDs now proven wrong for G2).
- `dts/g2-sdhci-upstream-candidate.dtsi` — interconnect topology corrected
  from `&aggre2_noc` to `&aggre1_noc` and header comment updated to Cliffs IDs.
- `scripts/validate-g2-sdhci-provider-map.py` — rewritten to require Cliffs
  IDs/topology and forbid the SM7635/Milos `aggre2_noc` topology, the SM7635
  numeric IDs (8/20/1), the SM7635 `qcom,milos-*-noc` compatibles, and the
  SM8650 PM8550 card-detect values.
- `.gitignore` — NEW (ignore local `linux/` kernel clone used for build-side
  validation).

### Deferred (not in this commit)

The CI workflow updates (`.github/workflows/g2-sdhci-linux-dtc.yml`,
`.github/workflows/g2-sdhci-static.yml`) — pointing at the new Cliffs files and
installing the Cliffs provider — require the `workflows` write scope, which the
run's `GITHUB_TOKEN` does not carry. The validator and kernel/DTB build were
run directly instead. A maintainer with `workflows` permission must apply the
workflow update as a follow-up.

## 4. Exact commands

```sh
# clone + pin (into a git-ignored local dir)
git clone --depth 1 https://github.com/torvalds/linux.git linux
git -C linux fetch --depth 1 origin 73e3f0710014fe6d4ed98cfc02292f6121db7558
git -C linux checkout 73e3f0710014fe6d4ed98cfc02292f6121db7558

# build deps
sudo apt-get install -y bc bison flex libssl-dev libelf-dev device-tree-compiler lld

# kernel build system + known-good baseline
make ARCH=arm64 defconfig                          # workdir: linux
make ARCH=arm64 -j4 qcom/milos-fairphone-fp6.dtb    # workdir: linux

# install G2 Cliffs provider + candidate
cp dts/qcom,cliffs.h linux/include/dt-bindings/interconnect/qcom,cliffs.h
cp dts/g2-cliffs-interconnect.dtsi linux/arch/arm64/boot/dts/qcom/g2-cliffs-interconnect.dtsi
cp dts/g2-sdhci-cliffs-merge.dtsi linux/arch/arm64/boot/dts/qcom/g2-sdhci-cliffs-merge.dtsi
# wrapper dts: linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dts
#   includes milos.dtsi + qcom,cliffs.h + g2-cliffs-interconnect.dtsi +
#   g2-sdhci-cliffs-merge.dtsi; added to qcom/Makefile dtb-$(CONFIG_ARCH_QCOM)

# G2 candidate build
make ARCH=arm64 -j4 qcom/g2-sdhci-compile-test.dtb  # workdir: linux

# validator
python3 scripts/validate-g2-sdhci-provider-map.py
```

## 5. Checksums (SHA-256)

```text
0d536b0da0c08afbf62dcbbe0a6069a553d12ef29f55bf95c1a8ab120ff34041  dts/qcom,cliffs.h
7e3728eee0bf3cdfd2db9d3a66321c25d6a91c26d8dc7900428b77ca8a68ce5d  dts/g2-cliffs-interconnect.dtsi
0b5b751d984eb93c40b61ad1d38b690de80a5517bda4dd06f5bfedacf3086a86  dts/g2-sdhci-cliffs-merge.dtsi
61da926228f2346805039587897c7701f42642489c999a244f597ed4fc5333aa  dts/g2-sdhci-upstream-candidate.dtsi
60c361ed9c17e97454a5117f48dbf07f7f94c3fc0f231bb1ad5150441342de50  scripts/validate-g2-sdhci-provider-map.py
dd6c201cb651f3a2479f557e640e250f0f8d6d001ea9fe8af7cc4726754d93fc  linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a  linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
```

The known-good `milos-fairphone-fp6.dtb` checksum matches the value recorded
in G2-C-0002-R1 (`c3908fe0…`), confirming a reproducible baseline.

## 6. Build / validation results

- Known-good `milos-fairphone-fp6.dtb`: **PASS** (69126 bytes).
- G2 `g2-sdhci-compile-test.dtb`: **PASS** (51136 bytes).
- Provider-map validator: **PASS** (45/45 checks).
- DTB disassembly of the G2 SDCC2 node confirms the Cliffs IDs and topology:
  `interconnects = <aggre1_noc 0x2f 0x07 mc_virt 0x200 0x07>, <gem_noc 0x02 0x03 cnoc_cfg 0x21e 0x03>`.
  `0x2f=47`, `0x200=512`, `0x02=2`, `0x21e=542`; the four NoC nodes carry
  `qcom,cliffs-*` compatibles.

Known, expected warnings (documented, non-fatal): including the Cliffs header
after `milos.dtsi` redefines `MASTER_SDCC_2`/`SLAVE_EBI1`/`SLAVE_SDCC_2`
because the compile candidate still reuses the Milos SoC scaffolding
(gcc/apps_smmu/pmic). This is a consequence of the "minimum provider overlay"
approach and does not affect the produced DTB values.

## 7. First compiler error

No compiler/validator error was reached. The build and validator both pass.
For completeness, the pre-existing (out-of-scope) blocker that the previous
Milos/SM7635 candidate hit was a regulator phandle error; this work avoids it
by leaving the G2 SD rails (PMXR2230 LDO13/LDO23) as explicit UNRESOLVED
comments instead of referencing the milos/pm7550 `vreg_l13b`/`vreg_l23b`
board-level nodes that do not exist in the SoC DTSI.

## 8. Next blocker

G2 SD regulator provider: PMXR2230 LDO13 (VDD) / LDO23 (VDD-IO) have no
upstream Linux regulator provider/binding at the pinned revision. A
source-supported PMXR2230 rpmh-regulator representation (or a verified G2 board
`apps_rsc` regulators block) is needed before the `vmmc`/`vqmmc` supplies can
be re-enabled.

## 9. Unresolved items (explicit, not guessed)

- PMXR2230 LDO13/LDO23 -> Linux regulator labels/phandles (next blocker).
- Exact Linux Cliffs pinctrl state/label for `sdc2_on`/`sdc2_off` and
  card-detect GPIO31 (active-low).
- SMMU stream ID: physical G2 cell is `0x140`; the Milos scaffolding uses
  `0x540`. Handled by the separate task G2-C-0001; left untouched here.
- Cliffs GCC SDCC2 clock/reset IDs (AHB 108, APPS 109, BCR 17) vs the Milos
  GCC header values (121/122/20) used by the compile scaffolding — a separate
  GCC provider task.
- SDHCI compatible/driver selection (upstream vs downstream pocknix).
- Physical G2 NoCs use `#interconnect-cells = <1>` (flat endpoint, no tag);
  this candidate keeps the upstream `#interconnect-cells = <2>` extended form
  (endpoint + `QCOM_ICC_TAG_*`) for an upstream-Linux-7.1.5-compatible
  provider. The <1> downstream representation is a separate driver decision.
- Per-NoC `qcom,bcm-voters`/clock wiring of the four Cliffs NoCs — the Milos
  scaffolding is retained and not asserted as G2-verified.
- Cliffs endpoints beyond the four SDCC2 endpoints (not invented).

## 10. Safety status

No device, bootloader, partition, UFS, AVB metadata, or microSD was modified.
This task produced only repository DTS/header/script/.gitignore/documentation
changes and a local build-side DTB compile candidate. PR left unmerged.
