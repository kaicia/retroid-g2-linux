# G2 Cliffs interconnect provider — build result (G2-C-0002-R2)

Date: 2026-08-28

## 1. Summary

Implemented the minimum source-supported Cliffs interconnect provider required
by the G2 SD-only SDHCI DTS and rebuilt/validated the G2 kernel/DTB compile
candidate at the pinned Linux revision
`73e3f0710014fe6d4ed98cfc02292f6121db7558`.

The G2 SDCC2 interconnect now uses the source-verified Cliffs vendor
`qcom,cliffs.h` flat-namespace IDs and topology instead of the SM7635/Milos
mainline per-NoC IDs:

| Endpoint | Cliffs ID (this work) | Raw G2 tuple | Prior SM7635/Milos ID |
|---|---|---|---|
| `MASTER_SDCC_2` | **47** (`0x2f`) on `aggre1_noc` | `0x1a2 0x2f` | 8 (aggre2_noc) |
| `SLAVE_EBI1` | **512** (`0x200`) on `mc_virt` | `0x189 0x200` | 1 |
| `MASTER_APPSS_PROC` | **2** on `gem_noc` | `0x1a3 0x02` | 2 |
| `SLAVE_SDCC_2` | **542** (`0x21e`) on `cnoc_cfg` | `0x1a4 0x21e` | 20 |

Topology correction: the physical G2 SDCC2 master sits on `aggre1_noc`, not
`aggre2_noc` as the SM7635/Milos reference used.

Build-side only. Nothing was flashed, booted, or written to any G2 device,
microSD, Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo/firmware partition.

## 2. Source lineage

- Linux kernel: `torvalds/linux` pinned to revision
  `73e3f0710014fe6d4ed98cfc02292f6121db7558` ("Merge tag 'nfs-for-7.3-1'"),
  as instructed by the task. Milos/SM7635 DTS present at this revision
  (`milos.dtsi`, `milos-fairphone-fp6.dts`, `pm7550.dtsi`, and
  `include/dt-bindings/interconnect/qcom,milos-rpmh.h`).
- Cliffs interconnect IDs: public Qualcomm `qcom,cliffs.h` binding,
  source-verified in `docs/g2-cliffs-provider-mapping-progress-20260822.md`
  (`MASTER_SDCC_2=47`, `SLAVE_SDCC_2=542`, `SLAVE_EBI1=512`,
  `MASTER_APPSS_PROC=2`).
- G2 hardware ground truth: physical G2 ADB DT dumps in `dumps/g2/`
  (`g2-sdhci-phandle-resolution-20260821-061126.txt` records the raw
  interconnect tuples `0x1a2 0x2f`, `0x189 0x200`, `0x1a3 0x02`,
  `0x1a4 0x21e`; SDHCI `0x08804000`, IRQs 207/223, 4-bit, card-detect
  GPIO31 active-low, NoC compatibles `qcom,cliffs-*`).
- The four Cliffs NoC compatible strings and addresses come from the physical
  G2 DT (see `docs/g2-cliffs-source-verification-20260822.md`):
  `aggre1_noc@16e0000`, `mc_virt` (interconnect@1), `gem_noc@24100000`,
  `cnoc_cfg@1600000`.

Not copied: SM8550/SM8650 numeric IDs, PM8550 GPIOs, the Fairphone board
card-detect GPIO 65, and the SM7635/Milos per-NoC interconnect IDs.

## 3. Changed files

- `.gitignore` — NEW; ignores the local `linux/` build clone and
  `linux-revision.txt`.
- `dts/qcom,cliffs.h` — NEW minimum Cliffs interconnect ID header (4 IDs).
- `dts/g2-cliffs-interconnect.dtsi` — NEW Cliffs NoC provider compatible
  overrides (`qcom,cliffs-aggre1_noc` / `-mc_virt` / `-gem_noc` / `-cnoc_cfg`).
- `dts/g2-sdhci-milos-merge.dtsi` -> `dts/g2-sdhci-cliffs-merge.dtsi` —
  renamed and reworked to use Cliffs IDs/topology; regulators/pinctrl/
  card-detect left as explicit UNRESOLVED comments.
- `scripts/validate-g2-sdhci-provider-map.py` — rewritten to parse the Cliffs
  ID values, require the Cliffs topology, and forbid the SM7635/Milos
  `aggre2_noc` SDCC2 topology plus SM8550/SM8650/board card-detect values.
- `docs/g2-sdhci-linux-provider-map-20260827.md` — corrected the interconnect
  endpoint IDs to the Cliffs values.
- `docs/g2-cliffs-interconnect-provider-result-20260828-r2.md` — this report.

### Deferred (not in this commit)

The CI workflows `.github/workflows/g2-sdhci-linux-dtc.yml` and
`.github/workflows/g2-sdhci-static.yml` still reference the old
`dts/g2-sdhci-milos-merge.dtsi` filename and the incorrect known-good DTB
target `arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb` (which fails; the
correct target is `qcom/milos-fairphone-fp6.dtb`). They must also copy the new
`dts/qcom,cliffs.h` and `dts/g2-cliffs-interconnect.dtsi` and include them in
the compile wrapper. These workflow edits could not be pushed in this run
because the OpenCode job's `GITHUB_TOKEN` lacks the `workflows` scope required
to modify `.github/workflows/*`. The validator and kernel/DTB build were run
locally instead. A maintainer with a PAT/`workflows` permission must apply the
workflow update as a follow-up.

## 4. Exact commands

```sh
# clone + pin
git clone --no-checkout --depth 1 https://github.com/torvalds/linux.git linux
git -C linux fetch --depth 1 origin 73e3f0710014fe6d4ed98cfc02292f6121db7558
git -C linux checkout 73e3f0710014fe6d4ed98cfc02292f6121db7558

# deps
sudo apt-get update
sudo apt-get install -y bc bison flex libssl-dev libelf-dev device-tree-compiler lld

# build system + known-good baseline
make ARCH=arm64 LLVM=1 defconfig                       # workdir: linux
make ARCH=arm64 LLVM=1 -j4 qcom/milos-fairphone-fp6.dtb   # workdir: linux

# install G2 Cliffs provider + candidate
cp dts/qcom,cliffs.h linux/include/dt-bindings/interconnect/qcom,cliffs.h
cp dts/g2-cliffs-interconnect.dtsi linux/arch/arm64/boot/dts/qcom/g2-cliffs-interconnect.dtsi
cp dts/g2-sdhci-cliffs-merge.dtsi linux/arch/arm64/boot/dts/qcom/g2-sdhci-cliffs-merge.dtsi
# wrapper dts (g2-sdhci-compile-test.dts) includes milos.dtsi + pm7550.dtsi +
#   g2-cliffs-interconnect.dtsi + g2-sdhci-cliffs-merge.dtsi
printf '%s\n' 'dtb-y += g2-sdhci-compile-test.dtb' >> linux/arch/arm64/boot/dts/qcom/Makefile

# G2 candidate build
make ARCH=arm64 LLVM=1 -j4 qcom/g2-sdhci-compile-test.dtb   # workdir: linux

# validator
python3 scripts/validate-g2-sdhci-provider-map.py

# disassembly confirmation
dtc -I dtb -O dts linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
```

## 5. Checksums (SHA-256)

```text
34a60c1df61de1a2d6df23fe21d7f3e771d291c99d47517a1e280a912916c373  dts/qcom,cliffs.h
d94da9a569e35601d7e0b4a9e36c22ce66f77b98bd3f320ed41abaece323fdfa  dts/g2-cliffs-interconnect.dtsi
b365f3817704721097588b500b434c487e538bb2bd214279b8bbda634dfdd069  dts/g2-sdhci-cliffs-merge.dtsi
b166081ddde28be9c411aef8db42a3b4853f89f8ed0b110ef5b381aa07429942  scripts/validate-g2-sdhci-provider-map.py
8f032b130f7dec89f28db1747512ff3b400af0dd27d08399b8e954011fbc8cb1  linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a  linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
```

## 6. Build / validation results

- Known-good `milos-fairphone-fp6.dtb`: **PASS** (69126 bytes).
- G2 `g2-sdhci-compile-test.dtb`: **PASS** (51888 bytes).
- Provider-map validator: **PASS** (28/28 checks).
- DTB disassembly confirms the SDCC2 `interconnects` cell values are the
  Cliffs IDs:
  `interconnects = <0x31 0x2f 0x07 0x32 0x200 0x07 0x2f 0x02 0x03 0x30 0x21e 0x03>`
  where `0x2f=47` (MASTER_SDCC_2 on aggre1_noc), `0x200=512` (SLAVE_EBI1 on
  mc_virt), `0x02=2` (MASTER_APPSS_PROC on gem_noc), `0x21e=542`
  (SLAVE_SDCC_2 on cnoc_cfg), and the four NoC nodes carry `qcom,cliffs-*`
  compatibles.

Known, expected warnings (documented, non-fatal): including the Cliffs header
after `milos.dtsi` redefines `MASTER_SDCC_2`/`SLAVE_EBI1`/`SLAVE_SDCC_2`
because the compile candidate still reuses the Milos SoC scaffolding
(gcc/apps_smmu/pmic) whose `qcom,milos-rpmh.h` uses the per-NoC namespace.
This is a consequence of the "minimum provider overlay" approach and does not
affect the produced DTB values. `MASTER_APPSS_PROC` produces no warning because
its value (2) is identical in both bindings.

## 7. First compiler/validator error (pre-existing baseline, out of scope)

Before this work, the SM7635/Milos candidate with the old
`g2-sdhci-milos-merge.dtsi` was blocked by an out-of-scope regulator phandle
error when the fragment referenced the board-level `vreg_l13b`/`vreg_l23b`
labels that only exist in `milos-fairphone-fp6.dts` (not in the SoC DTSI):

```text
ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"
ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l23b"
ERROR: Input tree has errors, aborting (use -f to force output)
```

The G2 rails are PMXR2230 LDO13/LDO23, which have no provider in the pinned
Linux tree. This work therefore marks the supplies as explicit UNRESOLVED
comments in the G2 fragment (rather than guessing a phandle), which unblocks
the interconnect build.

## 8. Next blocker

G2 SD regulator provider: PMXR2230 LDO13 (VDD) / LDO23 (VDD-IO) have no
upstream Linux regulator provider/binding at the pinned revision. A
source-supported PMXR2230 rpmh-regulator representation (or a verified G2 board
`apps_rsc` regulators block) is needed before the `vmmc`/`vqmmc` supplies can
be re-enabled.

## 9. Unresolved items (explicit, not guessed)

- PMXR2230 LDO13/LDO23 -> Linux regulator labels/phandles (next blocker).
- Exact Linux Cliffs pinctrl state/label for `sdc2_on`/`sdc2_off` and
  card-detect GPIO31.
- SMMU stream ID (0x540 in the Milos scaffolding vs G2-confirmed 0x140) —
  separate task G2-C-0001; left untouched here.
- Per-NoC `qcom,bcm-voters`/clock wiring of the four Cliffs NoCs — the Milos
  scaffolding is retained and not asserted as G2-verified.
- Cliffs endpoints beyond the four SDCC2 endpoints (not invented).
- SDHCI compatible/driver selection (upstream `qcom,milos-sdhci` vs downstream
  pocknix `qcom,sdhci-msm-v5-downstream`).
- CI workflow update to reference the renamed fragment + Cliffs header (needs
  `workflows`-scoped token; see section 3 Deferred).

## 10. Safety status

No device, bootloader, partition, UFS, AVB metadata, or microSD was modified.
This task produced only repository DTS/header/script/documentation changes and
a local build-side DTB compile candidate. PR left unmerged.
