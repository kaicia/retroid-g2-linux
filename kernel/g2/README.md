# kernel/g2 — G2 (Cliffs) kernel input set

This directory holds the G2 kernel build inputs for the Phase B SD-only
bring-up, mirroring the pocknix/ROCKNIX structure (kernel.conf + dts + config).

## Layout

- `kernel.conf` — stock kernel.org Linux pin (7.1.5, SHA-256 verified).
- `dts/qcom/g2-cliffs-sd.dts` — G2 SD-only DTS, integrated into the kernel
  DT build at `arch/arm64/boot/dts/qcom/g2-cliffs-sd.dts` by
  `scripts/build-g2-kernel.sh`. Values are source-grounded (physical G2 DT +
  exact Cliffs bindings); nothing is invented.
- `config/linux.aarch64.conf` — minimal config fragment (no-op over the
  arm64 defconfig today; the versioned place to add G2 config later).
- `patches/` — reserved for the future minimum Cliffs provider patch set
  (GCC, interconnect, pinctrl, PMXR2230). Empty until source-verified.

## Build

```sh
scripts/build-g2-kernel.sh --with-rootfs
```

See `docs/g2-phase-b-sd-boot-candidate-20260824.md` for the full report,
validation results and the exact blocker list.

## Safety

microSD-only. These inputs never touch internal Android/UFS/ABL/vbmeta/dtbo
storage; builds only write to `build/`.
