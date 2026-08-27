# DeepSeek compile result — 2026-08-27

Task: `docs/deepseek-compile-task-20260827.md`
Result: **G2 SDHCI candidate FAIL — exact first compiler error preserved below.**
Known-good baseline: **PASS.**

No device, bootloader, Android partition, or firmware was modified. All work was
performed inside a temporary throwaway Linux kernel checkout (`linux/`) in the
CI workspace.

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
