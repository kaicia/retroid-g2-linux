# G2 SDHCI SMMU stream ID correction — result

Task: `G2-C-0001` / request `G2-C-0001-R1` — correct the stale SMMU stream ID
`0x540` to the G2-confirmed `0x140`, build-side only.

Status: **DONE — SMMU stream corrected, validator PASS, first G2 DTB validation
PASS with the corrected tuple.**

Safety: build-side only. No G2 device, SD card, or Android/UFS/ABL/GPT/boot/
vendor_boot/vbmeta/dtbo/firmware partition was flashed, booted, modified,
erased, repartitioned, or written.

## 1. Hardware evidence (existing, not re-collected)

The physical G2 Android DT audit
`dumps/g2/g2-sdhci-phandle-resolution-20260821-061126.txt` resolved the SDCC2
`iommus` property to `apps-smmu@15000000` (phandle `0x12a`) and captured the
raw tuple `00 00 01 2a 00 00 01 40 00 00 00 00`, i.e. stream ID `0x140`, mask
`0`. `0x540` was an upstream Milos/SM7635 reference value (still present in
`milos.dtsi` at the pinned revision, `mmc@8804000`).

## 2. Files changed (one task, SMMU stream only)

- `dts/g2-sdhci-milos-merge.dtsi` — `iommus = <&apps_smmu 0x140 0>;` + provenance comment.
- `dts/g2-sdhci-upstream-candidate.dtsi` — header note and `iommus = <&apps_smmu 0x140 0>;`.
- `scripts/validate-g2-sdhci-provider-map.py` — require `apps_smmu 0x140 0`; forbid `apps_smmu 0x540 0`.
- `docs/g2-sdhci-linux-provider-map-20260827.md` — section 4 correction with
  evidence, section 8 item 6 updated to `<0x140 0>`.
- `docs/deepseek-compile-task-20260827.md` — pin Linux revision
  `73e3f0710014fe6d4ed98cfc02292f6121db7558`; note the corrected tuple.
- `docs/g2-smmu-stream-id-correction-result-20260827.md` — this report.

The stale `0x540` value is preserved in git history (prior commits show the old
text) and is now rejected by the validator; it was not silently deleted.

## 3. Provider-map validator (re-run)

```text
python3 scripts/validate-g2-sdhci-provider-map.py
```

Result: **PASS — all 17 static provider-map checks passed**, including
`PASS: SMMU stream tuple`. The `0x540` tuple is now a forbidden-candidate
check.

## 4. First G2 kernel/DTB validation (re-run)

Linux revision pinned and verified:
`73e3f0710014fe6d4ed98cfc02292f6121db7558`
(`Merge tag 'nfs-for-7.3-1'`, `make ARCH=arm64 LLVM=1 defconfig`).

| Artifact | Result |
|---|---|
| Known-good `milos-fairphone-fp6.dtb` | **PASS** (69126 B) |
| G2 first-build candidate `milos-retroid-g2.dtb` | **PASS** (52983 B) — `dtc` disassembly shows `iommus = <0x2c 0x140 0x00>` on `mmc@8804000` |
| Kernel `Image` | **PASS** (52,075,008 B; `kernel.release 7.2.0-g73e3f0710014-dirty`) |
| `g2-sdhci-compile-test.dtb` (wrapper: `milos.dtsi` + `pm7550.dtsi` + `g2-sdhci-milos-merge.dtsi`) | **BLOCKED by pre-existing, out-of-scope error** — see section 5 |

Artifact checksums (this re-run):

```text
6cc1976a0d56bc55a9c2198eb4400253fe48faac0e745f3c1015a42edb370a54  Image
6b46bbf39284847405e146bc1536e6e5e7d294600f37494dda06ccc6a16bb297  milos-retroid-g2.dtb
c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a  milos-fairphone-fp6.dtb
```

The G2 first-build DTB and baseline DTB sizes (52983 B and 69126 B) match the
original `docs/g2-first-kernel-build-20260827.md` record, confirming a faithful
reproduction at the same revision with the G2-confirmed stream ID. The kernel
Image built successfully with the same `kernel.release`; its byte size differs
from the original record because `defconfig`-selected build options (e.g.
`CONFIG_KALLSYMS_ALL`, `CONFIG_DEBUG_INFO`) resolve via the installed
LLVM/GCC toolchain, while the DTB artifacts are bit-for-bit identical in size.

## 5. Exact first compiler error preserved (blocked item)

The compile wrapper validation hits a pre-existing error that is unrelated to
the SMMU stream correction. At revision `73e3f0710014...`, `pm7550.dtsi`
defines no RPMH regulators, so the merge fragment's `vmmc-supply` /
`vqmmc-supply` phandle references to `vreg_l13b` / `vreg_l23b` cannot resolve
(the first G2 board DTS supplies those regulators inline; that representation
is an unresolved provider-map item and is out of scope here). Exact first
errors, verbatim:

```text
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"

  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi:14.9-50.3
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l23b"

  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi:14.9-50.3
ERROR: Input tree has errors, aborting (use -f to force output)
make[3]: *** [scripts/Makefile.dtbs:140: arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb] Error 2
make[2]: *** [scripts/Makefile.build:550: arch/arm64/boot/dts/qcom] Error 2
make[1]: *** [/tmp/opencode/linux/Makefile:1656: qcom/g2-sdhci-compile-test.dtb] Error 2
make: *** [Makefile:248: __sub-make] Error 2
```

The SMMU reference itself resolved cleanly (no error for `&apps_smmu`), so the
correction is unaffected by the block.

## 6. Out of scope (not changed)

TLMM base, interconnect endpoint mapping, OPP representation, QoS masks,
pinctrl state/labels, regulator inline representation, and all other items
listed as unresolved in the provider map were left untouched.
