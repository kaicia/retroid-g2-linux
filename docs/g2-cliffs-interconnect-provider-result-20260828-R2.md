# G2 Cliffs interconnect provider — build result (G2-C-0002-R2)

Date: 2026-08-28
Request: G2-C-0002-R2 (fresh rerun of G2-C-0002-R1; this run's job/trace are the
sole evidence for R2 — R1 evidence is not reused).

## 1. Summary

Implemented the minimum source-supported Cliffs interconnect provider required
by the G2 SD-only SDHCI DTS and rebuilt/validated the G2 kernel/DTB compile
candidate.

The G2 SDCC2 interconnect now uses the source-verified Cliffs vendor
`qcom,cliffs.h` flat-namespace IDs and topology instead of the SM7635/Milos
mainline per-NoC IDs:

| Endpoint | Cliffs ID (this work) | G2 raw tuple | Previous SM7635/Milos ID |
|---|---|---|---|
| `MASTER_SDCC_2` | **47** (`0x2f`) | `0x1a2 0x2f` | 8 (aggre2_noc) |
| `SLAVE_EBI1` | **512** (`0x200`) | `0x189 0x200` | 1 |
| `MASTER_APPSS_PROC` | **2** (`0x2`) | `0x1a3 0x2` | 2 |
| `SLAVE_SDCC_2` | **542** (`0x21e`) | `0x1a4 0x21e` | 20 |

Topology correction: the physical G2 SDCC2 master sits on `aggre1_noc`
(`qcom,cliffs-aggre1_noc`), not `aggre2_noc` as the SM7635/Milos reference
used.

Build-side only. Nothing was flashed, booted, or written to any G2 device,
microSD, or Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo/firmware partition.

## 2. Source lineage

- Linux kernel: `torvalds/linux` pinned to
  `73e3f0710014fe6d4ed98cfc02292f6121db7558` (Linus, "Merge tag 'nfs-for-7.3-1'"),
  as instructed by the task. Milos/SM7635 DTS present at this revision
  (`milos.dtsi`, `milos-fairphone-fp6.dts`, `pm7550.dtsi`).
- Cliffs interconnect IDs: source-verified in
  `docs/g2-cliffs-linux-source-mapping-20260822.md` and
  `docs/g2-cliffs-provider-mapping-progress-20260822.md`
  (`MASTER_SDCC_2=47`, `SLAVE_SDCC_2=542`, `SLAVE_EBI1=512`,
  `MASTER_APPSS_PROC=2`).
- Cliffs NoC provider compatibles/addresses: physical G2 ADB DT
  (`docs/g2-cliffs-source-verification-20260822.md`):
  `aggre1_noc@16e0000`, `mc_virt` (interconnect@1), `gem_noc@24100000`,
  `cnoc_cfg@1600000`.
- G2 hardware ground truth: `dumps/g2/` (SDHCI `0x08804000`, IRQs 207/223,
  4-bit, card-detect GPIO31 active-low).

Not copied: SM8550/SM8650 numeric IDs, PM8550 GPIOs, and the SM7635/Milos
per-NoC interconnect IDs (8/20/1).

## 3. Changed files

- `dts/qcom,cliffs.h` — NEW minimum Cliffs interconnect ID header (4 IDs).
- `dts/g2-cliffs-interconnect.dtsi` — NEW Cliffs NoC provider compatible
  overrides (`qcom,cliffs-aggre1_noc` / `-mc_virt` / `-gem_noc` / `-cnoc_cfg`).
- `dts/g2-sdhci-milos-merge.dtsi` -> `dts/g2-sdhci-cliffs-merge.dtsi` — renamed
  and reworked to use Cliffs IDs/topology; regulators/pinctrl/card-detect left
  as explicit UNRESOLVED comments.
- `scripts/validate-g2-sdhci-provider-map.py` — rewritten to require Cliffs
  IDs/topology and forbid the SM7635 `aggre2_noc` SDCC2 topology and the
  SM8650 PM8550 card-detect values.
- `.gitignore` — NEW: ignore the local `linux/` build tree.

## 4. Exact commands

```sh
# clone + pin (shallow then fetch pinned rev)
git clone --depth 1 https://github.com/torvalds/linux.git linux
git -C linux fetch --depth 1 origin 73e3f0710014fe6d4ed98cfc02292f6121db7558
git -C linux checkout 73e3f0710014fe6d4ed98cfc02292f6121db7558

# deps
sudo apt-get install -y bc bison flex libssl-dev libelf-dev device-tree-compiler lld

# build system + known-good baseline
make ARCH=arm64 LLVM=1 defconfig                     # workdir: linux
make ARCH=arm64 LLVM=1 -j4 qcom/milos-fairphone-fp6.dtb   # workdir: linux

# install G2 Cliffs provider + candidate into the kernel tree
cp dts/qcom,cliffs.h linux/include/dt-bindings/interconnect/qcom,cliffs.h
cp dts/g2-cliffs-interconnect.dtsi linux/arch/arm64/boot/dts/qcom/g2-cliffs-interconnect.dtsi
cp dts/g2-sdhci-cliffs-merge.dtsi linux/arch/arm64/boot/dts/qcom/g2-sdhci-cliffs-merge.dtsi
# wrapper dts (g2-sdhci-compile-test.dts) includes milos.dtsi + pm7550.dtsi +
#   qcom,cliffs.h + g2-cliffs-interconnect.dtsi + g2-sdhci-cliffs-merge.dtsi

# G2 candidate build
make ARCH=arm64 LLVM=1 -j4 qcom/g2-sdhci-compile-test.dtb   # workdir: linux

# validator
python3 scripts/validate-g2-sdhci-provider-map.py

# DTB sanity disassembly
dtc -I dtb -O dts linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
```

Toolchain observed on the runner: clang 18.1.3 (`LLVM=1`), dtc 1.7.0.

## 5. Checksums (SHA-256)

```text
abb970653078a4196fad33d2e1cc0593bc92928cceccc14dbfdb2a3cabed0381  dts/qcom,cliffs.h
77c41b6eadd802447390d4082d7b0176274d8e040d90289680d1dc1a7adcf5c8  dts/g2-cliffs-interconnect.dtsi
ad04a73e7cbaa1e7f53a430b2aae2be86b43726ddf180828c95cbcd609c812fe  dts/g2-sdhci-cliffs-merge.dtsi
433bc0d55dbcdef1d5a45e97a210f676657d921810d23892a254a4a1587681f7  scripts/validate-g2-sdhci-provider-map.py
8f032b130f7dec89f28db1747512ff3b400af0dd27d08399b8e954011fbc8cb1  linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a  linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
```

## 6. Build / validation results

- Known-good `milos-fairphone-fp6.dtb`: **PASS** (69126 bytes).
- G2 `g2-sdhci-compile-test.dtb`: **PASS** (51888 bytes).
- Provider-map validator: **PASS** (31/31 checks).
- DTB disassembly confirms the SDCC2 `interconnects` cells carry the Cliffs IDs:

```text
interconnects = <0x31 0x2f 0x07 0x32 0x200 0x07 0x2f 0x02 0x03 0x30 0x21e 0x03>;
```

i.e. `aggre1_noc MASTER_SDCC_2(0x2f=47) TAG_ALWAYS(0x07)`,
`mc_virt SLAVE_EBI1(0x200=512) TAG_ALWAYS(0x07)`,
`gem_noc MASTER_APPSS_PROC(0x02=2) TAG_ACTIVE_ONLY(0x03)`,
`cnoc_cfg SLAVE_SDCC_2(0x21e=542) TAG_ACTIVE_ONLY(0x03)`. The four NoC nodes
carry `qcom,cliffs-mc_virt`, `qcom,cliffs-cnoc_cfg`, `qcom,cliffs-aggre1_noc`,
`qcom,cliffs-gem_noc`.

Also verified in the DTB: clocks `iface/core` (GCC_SDCC2_AHB_CLK=121 /
GCC_SDCC2_APPS_CLK=122), reset `GCC_SDCC2_BCR=20`, IRQs 207/223,
`iommus = <apps_smmu 0x540 0>`.

Known, expected warnings (documented, non-fatal): including the Cliffs header
after `milos.dtsi` redefines `MASTER_SDCC_2` (8->47), `SLAVE_EBI1` (1->512),
`SLAVE_SDCC_2` (20->542) because the compile candidate still reuses the Milos
SoC scaffolding (gcc/apps_smmu/pmic). `MASTER_APPSS_PROC` is 2 in both
namespaces, so it is not redefined. This is a consequence of the "minimum
provider overlay" approach and does not affect the produced DTB values.

## 7. First compiler error (pre-existing baseline, reproduced verbatim for R2)

Before this work, the SDCC2 node with the milos/pm7550 regulator stand-ins was
already blocked by a phandle_references error. Reproduced verbatim by building
a throwaway wrapper that references `vreg_l13b`/`vreg_l23b`:

```text
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"

  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-regtest.dts:11.9-14.3
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l23b"

  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-regtest.dts:11.9-14.3
ERROR: Input tree has errors, aborting (use -f to force output)
```

The G2 rails are PMXR2230 LDO13/LDO23, which have no provider in the pinned
Linux tree. The milos/pm7550 `vreg_l13b`/`vreg_l23b` are board-level nodes
present only in `milos-fairphone-fp6.dts`, not in the SoC DTSI. This work
therefore marks the supplies as explicit UNRESOLVED comments in the G2 fragment
(rather than guessing a phandle), which unblocks the interconnect build.

## 8. Next blocker

G2 SD regulator provider: PMXR2230 LDO13 (VDD) / LDO23 (VDD-IO) have no
upstream Linux regulator provider/binding at the pinned revision. A
source-supported PMXR2230 rpmh-regulator representation (or a verified G2 board
`apps_rsc` regulators block) is needed before `vmmc`/`vqmmc` can be re-enabled.

## 9. Unresolved items (explicit, not guessed)

- PMXR2230 LDO13/LDO23 -> Linux regulator labels/phandles (next blocker).
- Exact Linux Cliffs pinctrl state/label for `sdc2_on`/`sdc2_off` and
  card-detect GPIO31 (board-specific).
- SMMU stream ID 0x540 vs G2-confirmed 0x140 — tracked separately by task
  G2-C-0001; left untouched in this interconnect task.
- Per-NoC `qcom,bcm-voters`/clock wiring of the four Cliffs NoCs — the Milos
  scaffolding is retained and not asserted as G2-verified.
- Cliffs endpoints beyond the four SDCC2 endpoints (not invented).
- SDHCI compatible/driver selection (upstream `qcom,milos-sdhci` vs pocknix
  downstream `qcom,sdhci-msm-v5-downstream`).

## 10. Safety status

No device, bootloader, partition, UFS, AVB metadata, or microSD was modified.
This task produced only repository DTS/header/script/gitignore/documentation
changes and a local build-side DTB compile candidate. PR left unmerged.
