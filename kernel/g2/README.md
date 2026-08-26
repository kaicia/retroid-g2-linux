# kernel/g2 — G2 (Cliffs) kernel input set

This directory holds the G2 kernel build inputs for the Phase B SD-only
bring-up, mirroring the pocknix/ROCKNIX structure (kernel.conf + dts + config).

## Layout

- `kernel.conf` — stock kernel.org Linux pin (7.1.5, SHA-256 verified).
- `dts/qcom/g2-cliffs-sd.dts` — G2 SD-only DTS, integrated into the kernel
  DT build at `arch/arm64/boot/dts/qcom/g2-cliffs-sd.dts` by
  `scripts/build-g2-kernel.sh`. Values are source-grounded (physical G2 DT +
  exact Cliffs bindings); nothing is invented.
- `config/linux.aarch64.conf` — G2 config fragment merged on top of the arm64
  defconfig. Enables `CONFIG_SM_GCC_CLIFFS` for the patch-0003 GCC provider.
- `patches/` — G2 patch stack, applied by `scripts/build-g2-kernel.sh`
  (`patch -p1 --forward`) right after kernel extraction.
  - `0003-cliffs-gcc.patch` — minimum Cliffs GCC clock/reset provider required
    by the G2 DTS: adds `include/dt-bindings/clock/qcom,gcc-cliffs.h` and
    `drivers/clk/qcom/gcc-cliffs.c` (compatible `qcom,cliffs-gcc`) registering
    the SDCC2 clocks (`GCC_SDCC2_AHB_CLK` 108, `GCC_SDCC2_APPS_CLK` 109, src
    110) with their GPLL0/0-even/4/9 parents and the `GCC_SDCC2_BCR` (17)
    reset, plus Kconfig/Makefile wiring. All register/offset values are taken
    verbatim from the verified Cliffs source (OnePlusOSS
    `android_kernel_oneplus_sm8650` commit
    `e39bf7032e38c547d588372a11a5dd55eb714860`,
    `drivers/clk/qcom/gcc-cliffs.c`); the vendor-only framework extensions
    (vdd_data/HW_CLK_CTRL_MODE/enable_safe_config/DFS) are mapped to the
    equivalent upstream 7.1.5 APIs (`clk_rcg2_shared_floor_ops`), so the driver
    builds against stock Linux 7.1.5.

## Build

```sh
scripts/build-g2-kernel.sh --with-rootfs
```

See `docs/g2-phase-b-sd-boot-candidate-20260824.md` for the full report,
validation results and the exact blocker list.

## Safety

microSD-only. These inputs never touch internal Android/UFS/ABL/vbmeta/dtbo
storage; builds only write to `build/`.
