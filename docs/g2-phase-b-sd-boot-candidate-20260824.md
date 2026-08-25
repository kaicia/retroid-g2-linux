# G2 Phase B — First microSD Boot-Test Candidate (build-validated)

Date: 2026-08-24
Status: BUILD-VALIDATED CANDIDATE (not yet boot-proven on hardware)

## Objective

Produce the smallest real Phase B microSD boot-test candidate: G2 kernel +
DTB, minimal rootfs, and boot configuration for the first removable-media
Linux boot experiment. This run performed real kernel builds (not just a
plan): Linux 7.1.5 was downloaded and SHA-256 verified, the G2 Cliffs
SD-only DTS was integrated into the kernel's own DT build target, the kernel
Image and G2 DTB were compiled, a minimal busybox rootfs was cross-built, and
a microSD image was assembled and validated non-destructively.

## What was built (exact artifacts)

All builds ran inside the repository under `build/g2/` (git-ignored) using the
committed scripts, which are the reproducible recipe.

| Artifact | Path (build output) | Size | SHA-256 |
|---|---|---|---|
| Kernel Image (arm64) | `build/g2/kbuild/arch/arm64/boot/Image` | 52,488,704 B | `408d95607e52440f57252e5f1cb63e7b31281488f7f04815a6ab8c550739842f` |
| G2 DTB | `build/g2/kbuild/arch/arm64/boot/dts/qcom/g2-cliffs-sd.dtb` | 3,891 B | `40f3e1eb52c3e2cba0d3656d609f00f1fe767fd8c53e734d71f984358bf9054a` |
| Minimal rootfs (busybox, static) | `build/g2/rootfs/` | ~2.2 MiB | busybox: `c8d4344b990c3079bc7f385c6376938caa8bda471c93b57b741b6e6190153797` |
| MicroSD image | `build/g2/g2-cliffs-sd.img` | 512 MiB (sparse GPT) | `9f6ebcbf796fc90a6974d1ed76a445077a07052a4e915c894d227d8562730e8a` |

MicroSD image layout (GPT):

- Partition 1 `G2-BOOT` (EFI/vfat, 256 MiB): `boot/Image`,
  `boot/g2-cliffs-sd.dtb`, `extlinux/extlinux.conf`
- Partition 2 `G2-ROOTFS` (Linux/ext4): minimal busybox rootfs
  (init, inittab, rcS, fstab)

## Kernel / DTS integration (the "real DT build target")

- Kernel pin: Linux `7.1.5` from kernel.org, SHA-256
  `22a0196b3cbcdf34dc27b77561f4d040585fd3447edc9ab3531a1ac79e3041e7` —
  the same pin already used by pocknix (`kernel/sm8550/kernel.conf`) and
  Armada. Recorded in `kernel/g2/kernel.conf`.
- The G2 DTS `kernel/g2/dts/qcom/g2-cliffs-sd.dts` (carried forward from the
  Phase A / PR #6 source-grounded DTS) is copied into
  `arch/arm64/boot/dts/qcom/g2-cliffs-sd.dts` and an ensured Makefile entry
  (`dtb-$(CONFIG_ARCH_QCOM) += g2-cliffs-sd.dtb`) makes it a first-class kernel
  DT build target.
- Build: `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig` +
  `make Image dtbs`. The kernel's own DT build (cpp + dtc via Kbuild) produced
  `g2-cliffs-sd.dtb`.

Config: Linux 7.1.5 arm64 defconfig already enables everything the SD boot
test needs (`CONFIG_ARCH_QCOM`, `CONFIG_MMC_SDHCI_MSM`, `CONFIG_MMC_BLOCK`,
`CONFIG_EXT4_FS`, `CONFIG_DEVTMPFS`, `CONFIG_SERIAL_MSM`). The G2 config
fragment (`kernel/g2/config/linux.aarch64.conf`) is intentionally minimal and
exists as the versioned place to add G2-specific config when a real boot log
demands it. No config value was invented.

## Validation results (non-destructive)

All performed with `scripts/validate-g2-sd-artifacts.sh` (read-only; no block
device, no internal Android storage touched):

1. **FDT magic** — PASS (`d00dfeed`, 3,891-byte DTB).
2. **DTB → DTS round-trip** — PASS (kernel's own `scripts/dtc/dtc`).
3. **dtc warnings** — informational only; the six warnings are structural
   (`simple-bus` children without `reg`, uppercase unit-name casing,
   opp-table without `reg`) and mirror the Qualcomm downstream DTS layout;
   no errors.
4. **G2 SDHCI node spot-check** — PASS for all source-verified values:
   `sdhci@8804000`, `qcom,sdhci-msm-v5`, clocks 108/109 (`0x6c`/`0x6d`),
   reset 17 (`0x11`), apps-smmu stream `0x140`, cd-gpios tlmm GPIO31.
5. **Checksums** — recorded above for reproducibility.
6. **DT schema check (dtbs_check)** — not run: the python `dtschema` package
   is not installed in this environment. Documented limitation; dtc static
   checks are complete.

Image-level verification: GPT layout confirmed (`G2-BOOT` + `G2-ROOTFS`),
boot partition staged with `boot/Image`, `boot/g2-cliffs-sd.dtb`,
`extlinux/extlinux.conf`, rootfs partition populated with the busybox init
tree. Performed on the image file via loop devices only.

## Key finding: mainline Linux 7.1.5 has NO Cliffs support

`grep -rI cliffs` across the full Linux 7.1.5 source returns **zero hits**.
This is the central Phase B blocker:

- `qcom,cliffs-*` GCC / interconnect / pinctrl providers referenced by the
  G2 DTS do not exist as drivers in Linux 7.1.5.
- The G2 DTB **compiles** because DTB compilation only requires the DTS +
  dt-bindings values (which are source-verified), but at runtime the Cliffs
  clock/interconnect/pinctrl/regulator providers will not probe in a stock
  7.1.5 kernel.
- Therefore this candidate is a **build-validated first SD test candidate**,
  NOT a claim of G2 bootability. The first physical SD test will likely stop
  at early boot / provider probe; that log is exactly what Phase C needs.

## Unresolved blockers (recorded, not guessed)

1. **Cliffs kernel drivers absent in mainline 7.1.5.** No `qcom,cliffs-*`
   GCC/interconnect/pinctrl, no PMXR2230 regulator driver, no Cliffs
   qsmmu config. Porting these from the vendor Cliffs source (LineageOS
   `android_kernel_qcom_sm8650-devicetrees` 4e146886, OnePlusOSS
   `android_kernel_oneplus_sm8650` e39bf703) is the largest Phase C task.
2. **PMXR2230 regulator phandles.** G2 supplies resolve to PMXR2230 LDO13/LDO23;
   the Linux-side regulator node/label in the target kernel is not yet
   verified, so `vdd-supply`/`vdd-io-supply` remain commented-out UNRESOLVED
   rather than guessed.
3. **G2 early-boot path unproven.** Whether stock ABL, UEFI+GRUB (RP5 class),
   or a ROCKNIX ABL (RP6 class) loads the SD Linux payload is not established
   from G2 device evidence. `extlinux.conf` is a draft layout; the physical
   boot chain must be tested from microSD.
4. **Downstream SDHCI driver not yet integrated.** G2 uses downstream
   properties (`qcom,dll-hsr-list`, `qcom,restore-after-cx-collapse`,
   qos0/qos1, IOMMU DMA props). The mainline `sdhci-msm` driver supports
   `qcom,sdhci-msm-v5`; the pocknix downstream SDHCI driver
   (`qcom,sdhci-msm-v5-downstream`) is the stronger candidate and requires a
   kernel patch set that is not yet in this build.
5. **DT schema check** requires `dtschema` tooling not present in this
   environment.

## Commands run (reproducible recipe)

```sh
# kernel + DTB (the real kernel DT build target)
scripts/build-g2-kernel.sh --with-rootfs
# image assembly
scripts/prepare-g2-sd-image.sh \
  --kernel build/g2/kbuild/arch/arm64/boot/Image \
  --dtb build/g2/kbuild/arch/arm64/boot/dts/qcom/g2-cliffs-sd.dtb \
  --rootfs build/g2/rootfs \
  --output build/g2/g2-cliffs-sd.img --size 512
# validation
scripts/validate-g2-sd-artifacts.sh
```

## Safety statement

- microSD/removable-media only. The image is a file; no block device was
  written, and no physical device was connected.
- Internal Android/UFS/ABL/vbmeta/dtbo/GPT storage: NOT modified.
- Removing the microSD preserves the stock Android boot path.
- The image-preparation script refuses internal-storage device names
  (`/dev/sda*`, `/dev/sdb*`, `/dev/nvme*`, `/dev/mmcblk0*`) and only permits
  a removable `/dev/mmcblk[1-9]*` with explicit confirmation.

## Is the SD image ready for a first physical G2 test?

**Structurally yes; functionally not yet.** The image contains a real
arm64 kernel, the source-grounded G2 DTB, a minimal rootfs and boot config,
all build-validated. However it should not be flashed to a G2 yet because the
early-boot chain for the G2 is unproven and the mainline 7.1.5 kernel lacks
the Cliffs providers the DTB references. The next concrete step is Phase C
item 1: port the Cliffs provider drivers, or obtain a first-boot log through
whatever loader the G2 exposes (stock UEFI/ABL investigation from
`docs/boot-chain-comparison.md`), then iterate.

## Next concrete step

1. Establish the exact G2 early-boot path from device evidence (does stock
   UEFI/ABL expose a removable-SD Linux payload path?).
2. Port the minimum Cliffs provider set (GCC, interconnect, pinctrl,
   PMXR2230 LDO13/LDO23) from the verified vendor source into the 7.1.5 tree
   as patches under `kernel/g2/patches/`.
3. Decide mainline vs pocknix downstream SDHCI driver for G2
   (`qcom,dll-hsr-list`, `qcom,restore-after-cx-collapse`, qos0/qos1).
4. Then produce a **second** candidate image that targets the first boot log.
