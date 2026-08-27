# DeepSeek compile result — 2026-08-27

Task: `docs/deepseek-compile-task-20260827.md`

**Round 1 (original):** G2 SDHCI candidate FAIL — exact first compiler error
preserved verbatim in sections 6/7. Known-good baseline PASS.

**Round 2 (this round):** regulator phandles `vreg_l13b`/`vreg_l23b` resolved
with the smallest compile-wrapper-only change (section 12). G2 candidate now
**PASS**. Known-good baseline re-confirmed **PASS** and byte-identical.

No device, bootloader, Android partition, or firmware was modified. All work was
performed inside a temporary throwaway Linux kernel checkout (`linux/`) in the
CI workspace. The G2 SDHCI fragment was **not** changed.

## 1. Source checkout

```text
$ git clone --depth 1 https://github.com/torvalds/linux.git linux
$ git rev-parse HEAD
73e3f0710014fe6d4ed98cfc02292f6121db7558
```

## 2. Build dependencies installed

```text
$ sudo apt-get install -y bc bison flex libssl-dev libelf-dev device-tree-compiler
$ sudo apt-get install -y llvm lld     # LLVM=1 needs unversioned ld.lld/llvm-* tools
```

## 3. Kernel config

```text
$ make ARCH=arm64 LLVM=1 defconfig
*** Default configuration is based on 'defconfig'
configuration written to .config
EXIT=0
```

Note: the first attempt of step 3 failed with `scripts/Kconfig.include:41:
linker 'ld.lld' not found` because the runner only had versioned LLVM tools;
installing `llvm` and `lld` resolved it.

## 4. Known-good baseline — milos-fairphone-fp6.dtb

```text
$ make ARCH=arm64 LLVM=1 -j2 arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
make[2]: *** No rule to make target 'arch/arm64/boot/dts/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb'.  Stop.
```

The top-level `%.dtb` pattern rule (Makefile:1655) prepends `$(dtstree)` to the
goal, so the fully-qualified form was path-doubled in this kernel revision. The
equivalent dtstree-relative goal builds correctly:

```text
$ make ARCH=arm64 LLVM=1 -j2 qcom/milos-fairphone-fp6.dtb
  DTC     arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
EXIT=0
```

Result file:

```text
-rw-r--r-- 1 runner runner 69126 Aug 27 03:17 arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
```

**Known-good baseline: PASS**

## 5. G2 candidate setup (as prescribed by the task)

```text
$ cp dts/g2-sdhci-milos-merge.dtsi \
     linux/arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi
```

Wrapper `arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dts`:

```dts
/dts-v1/;

#include "milos.dtsi"
#include "pm7550.dtsi"
#include "g2-sdhci-milos-merge.dtsi"

/ {
	model = "Retroid Pocket G2 SDHCI compile test";
	compatible = "retroid,g2-sdhci-compile-test", "qcom,milos";
};
```

Temporary Makefile addition (last line of
`arch/arm64/boot/dts/qcom/Makefile`):

```make
dtb-y += g2-sdhci-compile-test.dtb
```

## 6. G2 candidate compile — full verbatim output

```text
$ make ARCH=arm64 LLVM=1 -j2 qcom/g2-sdhci-compile-test.dtb
  UPD     include/config/kernel.release
  DTC     arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"

  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi:9.9-45.3
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l23b"

  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi:9.9-45.3
ERROR: Input tree has errors, aborting (use -f to force output)
make[3]: *** [scripts/Makefile.dtbs:140: arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb] Error 2
make[2]: *** [scripts/Makefile.build:550: arch/arm64/boot/dts/qcom] Error 2
make[1]: *** [/home/runner/work/retroid-g2-linux/retroid-g2-linux/linux/Makefile:1656: qcom/g2-sdhci-compile-test.dtb] Error 2
make: *** [Makefile:248: __sub-make] Error 2
EXIT=2
```

## 7. First failure (exact, verbatim)

First compiler/dtc error emitted:

```text
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references): /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"
```

## 8. Failure analysis (root cause, verified in source)

The G2 merge fragment `dts/g2-sdhci-milos-merge.dtsi` references the regulator
labels `vreg_l13b` (`vmmc-supply`) and `vreg_l23b` (`vqmmc-supply`). In current
mainline, those labels are **not** defined in `milos.dtsi` or `pm7550.dtsi`;
they are board-specific and only exist in the board file
`arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dts`:

```text
$ grep -n "vreg_l13b:\|vreg_l23b:" arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dts
348:		vreg_l13b: ldo13 {
418:		vreg_l23b: ldo23 {
```

No such label definitions exist anywhere in `milos.dtsi` or the `pm7550*.dtsi`
family, so a wrapper that includes only `milos.dtsi`, `pm7550.dtsi`, and the G2
merge fragment cannot resolve the two `phandle_references`. dtc treats this as a
hard error and aborts DTB generation (`g2-sdhci-compile-test.dtb` was not
produced). The `&sdhc_2` node lives at `milos.dtsi:1754` (`mmc@8804000`), which
is why dtc reports the error location there.

## 9. G2 candidate verdict

- G2 SDHCI compile candidate: **FAIL — DTB not generated.**
- Exact first error preserved verbatim in section 7.
- No guesses, no hidden errors, no `-f` force-output used.
- No device/bootloader/Android partition/firmware was modified.

## 10. Artifacts (throwaway CI clone, not committed)

- `linux-revision.txt` (in workspace, not committed)
- `linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb` (69126 bytes, PASS)
- `linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb` — not generated

---

## 11. Round 2 — diagnosis (verified in source at
`73e3f0710014fe6d4ed98cfc02292f6121db7558`)

`vreg_l13b` / `vreg_l23b` are **board-specific labels**. They are defined only
in the Milos board file, not in any `.dtsi`:

```text
$ grep -n "vreg_l13b:\|vreg_l23b:" arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dts
348:		vreg_l13b: ldo13 {
418:		vreg_l23b: ldo23 {
```

Both live inside `&apps_rsc { regulators-0 { compatible =
"qcom,pm7550-rpmh-regulators" } }` (board file lines 280-431). The bare `.dtsi`
files carry **zero** regulator label definitions:

```text
$ grep -c "vreg_" arch/arm64/boot/dts/qcom/milos.dtsi
0
$ grep -c "vreg_\|regulators" arch/arm64/boot/dts/qcom/pm7550.dtsi
0
```

Therefore the round-1 wrapper (`milos.dtsi` + `pm7550.dtsi` + fragment) cannot
resolve the two `phandle_references`. The G2 fragment's wiring is the
upstream-standard Milos SDC2 wiring — identical to
`milos-fairphone-fp6.dts:813-820` and `eliza-evk.dtsi:59-61`:

```text
$ sed -n '813,826p' arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dts
&sdhc_2 {
	cd-gpios = <&tlmm 65 GPIO_ACTIVE_HIGH>;
	vmmc-supply = <&vreg_l13b>;
	vqmmc-supply = <&vreg_l23b>;
	no-sdio;
	no-mmc;
	...
	status = "okay";
};
```

## 12. Round 2 — smallest compile-wrapper-only fix

Only the **wrapper** `g2-sdhci-compile-test.dts` changed. Instead of including
the bare `milos.dtsi` + `pm7550.dtsi` (which cannot provide the board-only
labels), the wrapper includes the reference board `milos-fairphone-fp6.dts`
(which defines `vreg_l13b`/`vreg_l23b`) and then applies the unchanged G2
fragment. No G2 hardware values were invented; all regulator values come
verbatim from the existing Linux Milos board file.

```dts
/dts-v1/;

#include "milos-fairphone-fp6.dts"
#include "g2-sdhci-milos-merge.dtsi"

/ {
	model = "Retroid Pocket G2 SDHCI compile test";
	compatible = "retroid,g2-sdhci-compile-test", "qcom,milos";
};
```

The G2 SDHCI fragment `dts/g2-sdhci-milos-merge.dtsi` was **not modified**
(byte-identical check: `git diff --no-index` returned 0). Temporary Makefile
addition (last line of `arch/arm64/boot/dts/qcom/Makefile`):

```make
dtb-y += g2-sdhci-compile-test.dtb
```

## 13. Round 2 — baseline re-run (verbatim)

```text
$ make ARCH=arm64 LLVM=1 -j2 qcom/milos-fairphone-fp6.dtb
  DTC     arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
EXIT=0
-rw-r--r-- 1 runner runner 69126 Aug 27 12:09 arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb
md5sum = e741cd7d883c243702a4cd91ef61b22a
```

Byte-identical to the round-1 baseline. **PASS.**

## 14. Round 2 — G2 candidate compile (verbatim)

```text
$ make ARCH=arm64 LLVM=1 -j2 qcom/g2-sdhci-compile-test.dtb
  UPD     include/config/kernel.release
  DTC     arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
EXIT=0
-rw-r--r-- 1 runner runner 69150 Aug 27 12:09 arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb
```

No failure occurred this round, so there is no new first-error to preserve; the
round-1 verbatim error remains in sections 6/7.

dtc dump verification of the generated DTB:

```text
$ dtc -I dtb -O dts arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb | grep -E "vmmc-supply|vqmmc-supply|status"   (mmc@8804000)
			status = "disabled";
			vmmc-supply = <0x66>;
			vqmmc-supply = <0x67>;
```

`vmmc-supply`/`vqmmc-supply` now resolve to phandles 0x66/0x67, which are the
PM7550 LDO13 (2.7–3.3 V) / LDO23 (1.65–3.544 V) regulators from the reference
board:

```text
$ dtc -I dtb -O dts .../g2-sdhci-compile-test.dtb | awk '/ldo13 {/,/};/' | grep phandle
					phandle = <0x66>;
$ dtc -I dtb -O dts .../g2-sdhci-compile-test.dtb | awk '/ldo23 {/,/};/' | grep phandle
					phandle = <0x67>;
```

`mmc@8804000` remains `status = "disabled"` — the fragment's non-bootable
setting wins over the board file's `status = "okay"`, as intended for a
compile-only candidate.

## 15. Round 2 — verdict

- G2 SDHCI compile candidate: **PASS** (DTB generated, 69150 bytes).
- Known-good baseline: **PASS** (69126 bytes, byte-identical to round 1).
- Root cause of round-1 failure: board-specific `vreg_l13b`/`vreg_l23b` labels
  absent from `milos.dtsi`/`pm7550.dtsi`, resolved by including the reference
  board file in the wrapper only.
- G2 SDHCI fragment unchanged; no G2 hardware values invented.
- No device/bootloader/Android partition/UFS/firmware was modified; nothing was
  flashed.

## 16. Round 2 — artifacts (throwaway CI clone, not committed)

- `linux/arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb` (69126 bytes, PASS)
- `linux/arch/arm64/boot/dts/qcom/g2-sdhci-compile-test.dtb` (69150 bytes, PASS)
