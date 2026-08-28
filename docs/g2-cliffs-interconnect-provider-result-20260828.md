# G2 Cliffs interconnect provider — build result (G2-C-0002-R2)

Date: 2026-08-28

## 0. Execution identity

| Field | Value |
|---|---|
| Task ID | `G2-C-0002` |
| Request ID | `G2-C-0002-R2` (fresh rerun of `G2-C-0002-R1`) |
| Actions Run ID | `33161623434` |
| Model / provider | `deepseek/deepseek-v4-pro` (official DeepSeek API) |
| Branch | `opencode/g2-c-0002-cliffs-interconnect-r2-33161623434` |
| Commit | tip of branch (PR #21) |
| PR | #21 (OPEN, not merged) |
| Live trace | `automation/status:dispatch/trace/G2-C-0002-R2.json` |

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
(G2 raw tuple `0x1a2 0x2f`), not `aggre2_noc` as the SM7635/Milos reference
used.

Build-side only. Nothing was flashed, booted, or written to any G2 device,
microSD, Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo/firmware partition.

## 2. Source lineage

- Linux kernel: `torvalds/linux` pinned to revision
  `73e3f0710014fe6d4ed98cfc02292f6121db7558` (Linus, "Merge tag 'nfs-for-7.3-1'",
  2026-08-26), as instructed by the task. `VERSION = 7` in the Makefile.
  Milos/SM7635 DTS present at this revision (`milos.dtsi`,
  `milos-fairphone-fp6.dts`, `pm7550.dtsi`).
- Cliffs interconnect IDs: public Qualcomm `qcom,cliffs.h` binding,
  source-verified in `docs/g2-cliffs-provider-mapping-progress-20260822.md`
  and `docs/g2-cliffs-linux-source-mapping-20260822.md`
  (`MASTER_SDCC_2=47`, `SLAVE_SDCC_2=542`, `SLAVE_EBI1=512`,
  `MASTER_APPSS_PROC=2`).
- G2 hardware ground truth: physical G2 ADB DT dumps in `dumps/g2/` (SDHCI
  `0x08804000`, IRQs 207/223, 4-bit, card-detect GPIO31 active-low, NoC
  compatibles `qcom,cliffs-*`, raw interconnect tuples, SMMU stream `0x140`).
- The 4 Cliffs NoC compatible strings and addresses come from the physical G2
  DT (see `docs/g2-cliffs-source-verification-20260822.md` and
  `dumps/g2/g2-sdhci-phandle-resolution-20260821-061126.txt`):
  `aggre1_noc@16e0000`, `mc_virt` (interconnect@1), `gem_noc@24100000`,
  `cnoc_cfg@1600000`.

Not copied: SM8550/SM8650 numeric IDs, PM8550 GPIOs, and the SM7635/Milos
per-NoC interconnect IDs.

## 3. Changed files

- `dts/qcom,cliffs.h` — NEW minimum Cliffs interconnect ID header (4 IDs).
- `dts/g2-cliffs-interconnect.dtsi` — NEW Cliffs NoC provider compatible
  overrides (`qcom,cliffs-aggre1_noc` / `-mc_virt` / `-gem_noc` / `-cnoc_cfg`).
- `dts/g2-sdhci-milos-merge.dtsi` -> `dts/g2-sdhci-cliffs-merge.dtsi` — renamed
  and reworked to use Cliffs IDs/topology; regulators/pinctrl/card-detect left
  as explicit UNRESOLVED comments.
- `scripts/validate-g2-sdhci-provider-map.py` — rewritten to require Cliffs
  IDs/topology and forbid the SM7635/Milos `aggre2_noc` SDCC2 topology and
  unverifiable regulator phandles (comment-aware).
- `.gitignore` — ignore the local `linux/` clone and `linux-revision.txt`.

### Deferred (not in this commit)

The two CI workflow updates could not be pushed: the workflow run's
`GITHUB_TOKEN` (GitHub App installation token) lacks the `workflows`
permission, so GitHub rejects any push that touches `.github/workflows/*`
with:

```text
! [remote rejected] ... (refusing to allow a GitHub App to create or update
workflow `.github/workflows/g2-sdhci-linux-dtc.yml` without `workflows` permission)
```

The intended workflow changes (needing a maintainer with a PAT or
`workflows`-scoped token) are:

- `.github/workflows/g2-sdhci-linux-dtc.yml`: pin Linux revision
  `73e3f0710014fe6d4ed98cfc02292f6121db7558`, install the Cliffs provider
  (`dts/qcom,cliffs.h` + the two Cliffs DTSI), and fix the known-good DTB
  target path from `arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb` to
  `qcom/milos-fairphone-fp6.dtb`.
- `.github/workflows/g2-sdhci-static.yml`: same provider install and target
  fix plus Cliffs-aware smoke checks.

The validator and kernel/DTB build were therefore run locally (exact commands
in section 4).

## 4. Exact commands

```sh
# clone + pin
git clone --depth 1 https://github.com/torvalds/linux.git linux
git -C linux fetch --depth 1 origin 73e3f0710014fe6d4ed98cfc02292f6121db7558
git -C linux checkout 73e3f0710014fe6d4ed98cfc02292f6121db7558

# deps
sudo apt-get install -y bc bison flex libssl-dev libelf-dev device-tree-compiler lld

# build system + known-good baseline
make ARCH=arm64 LLVM=1 defconfig                       # workdir: linux
make ARCH=arm64 LLVM=1 -j4 qcom/milos-fairphone-fp6.dtb   # workdir: linux

# install G2 Cliffs provider + candidate
cp dts/qcom,cliffs.h linux/include/dt-bindings/interconnect/qcom,cliffs.h
cp dts/g2-cliffs-interconnect.dtsi linux/arch/arm64/boot/dts/qcom/g2-cliffs-interconnect.dtsi
cp dts/g2-sdhci-cliffs-merge.dtsi linux/arch/arm64/boot/dts/qcom/g2-sdhci-cliffs-merge.dtsi
# wrapper dts (g2-sdhci-compile-test.dts) includes milos.dtsi + pm7550.dtsi +
#   <dt-bindings/interconnect/qcom,cliffs.h> + g2-cliffs-interconnect.dtsi +
#   g2-sdhci-cliffs-merge.dtsi

# G2 candidate build
make ARCH=arm64 LLVM=1 -j4 qcom/g2-sdhci-compile-test.dtb   # workdir: linux

# validator
python3 scripts/validate-g2-sdhci-provider-map.py
```

## 5. Checksums (SHA-256)

```text
bef96a491de5c54a91bb70e0f006e24905983763e0cf631ed4774a46880b1b70  dts/qcom,cliffs.h
cdb34aa25c0a15f8788e7d25d05563eea1ecb3fb4d4a18ecbeae8d239572c6ef  dts/g2-cliffs-interconnect.dtsi
d197b7d3b74110c8011bc7d5e4f14e85e825c5dfcfd54d64c33cf5420422abf1  dts/g2-sdhci-cliffs-merge.dtsi
5825351609e778f8e9b22822117e7dcbed932c41ff910f32877939c902bf2992  scripts/validate-g2-sdhci-provider-map.py
5436a9b144ad36eaa155a935d224961bcd0dc0ea40ac36b2e12787d8d10f7b23  .gitignore
8f032b130f7dec89f28db1747512ff3b400af0dd27d08399b8e954011fbc8cb1  linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a  linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
```

(Local build outputs under the gitignored `linux/` clone; the `.dtb` files are
not committed to the repository.)

## 6. Build / validation results

- Known-good `milos-fairphone-fp6.dtb`: **PASS** (69126 bytes).
- G2 `g2-sdhci-compile-test.dtb`: **PASS** (51888 bytes).
- Provider-map validator: **PASS** (29/29 checks).
- DTB disassembly confirms the SDCC2 `interconnects` cell values are the
  Cliffs IDs and the four NoC nodes carry `qcom,cliffs-*` compatibles:
  `interconnects = <aggre1_noc 0x2f 0x07 mc_virt 0x200 0x07>, <gem_noc 0x02 0x03 cnoc_cfg 0x21e 0x03>`
  (`0x2f=47`, `0x200=512`, `0x02=2`, `0x21e=542`; `0x07`=`QCOM_ICC_TAG_ALWAYS`,
  `0x03`=`QCOM_ICC_TAG_ACTIVE_ONLY`). `aggre2_noc` correctly remains
  `qcom,milos-aggre2-noc`.

Known, expected warnings (documented, non-fatal): including the Cliffs header
after `milos.dtsi` redefines `MASTER_SDCC_2`/`SLAVE_EBI1`/`SLAVE_SDCC_2`
because the compile candidate still reuses the Milos SoC scaffolding
(gcc/apps_smmu/pmic). This is a consequence of the "minimum provider overlay"
approach and does not affect the produced DTB values.

## 7. First compiler error (pre-existing baseline, out of scope)

Before this work, the SM7635/Milos candidate was already blocked by an
out-of-scope regulator phandle error (the exact first error, preserved
verbatim):

```text
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"
  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi:9.9-45.3
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l23b"
ERROR: Input tree has errors, aborting (use -f to force output)
```

The G2 rails are PMXR2230 LDO13/LDO23, which have no provider in the pinned
Linux tree. The milos/pm7550 `vreg_l13b`/`vreg_l23b` are board-level nodes not
present in the SoC DTSI. This work therefore marks the supplies as explicit
UNRESOLVED comments in the G2 fragment (rather than guessing a phandle), which
unblocks the interconnect build.

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
- SMMU stream ID: G2 physical is `0x140`; the candidate keeps the upstream
  Milos `0x540` placeholder. This is tracked under the SMMU stream task
  (G2-C-0001), not this interconnect task.
- GCC clock/reset IDs: G2 physical Cliffs GCC IDs are `GCC_SDCC2_AHB_CLK=108`,
  `GCC_SDCC2_APPS_CLK=109`, `GCC_SDCC2_BCR=17`; the candidate still uses the
  Milos `GCC_SDCC2_*` macros (121/122/20). Out of scope for this interconnect
  task.
- Per-NoC `qcom,bcm-voters`/clock wiring of the four Cliffs NoCs — the Milos
  scaffolding is retained and not asserted as G2-verified.
- `#interconnect-cells`: the physical G2 vendor binding uses `<1>` (flat
  endpoint namespace); the upstream Milos scaffolding uses `<2>` (endpoint +
  tag). Kept at `<2>` for mainline framework parsing; recorded as UNRESOLVED.
- Cliffs endpoints beyond the four SDCC2 endpoints (not invented).
- SDHCI compatible/driver selection (upstream vs downstream pocknix).

## 10. Safety status

No device, bootloader, partition, UFS, AVB metadata, or microSD was modified.
This task produced only repository DTS/header/script/workflow/documentation
changes and a local build-side DTB compile candidate. PR left unmerged.
