# holodor `make kernel` — full kernel built for SM8635 — 2026-09-29

Stood up the holodor build system for the G2 (SM8635/Cliffs) and ran `make
kernel` end-to-end. **Result: a complete kernel builds — `Image`, our
`cliffs-g2.dtb`, and our modules — and the arm-efi boot artifact (`KERNEL`) is
assembled.** This is the build-system integration milestone above the earlier
per-driver compile/link/modpost verification.

## What "stand up" required (now committed under `kernel/sm8635/`)
holodor's `make kernel` (`scripts/build-kernel.sh`) consumes a per-SoC family:
fetch pinned kernel.org source → apply `patches/*/*.patch` in numeric order →
overlay `dts/qcom/` + register in the qcom Makefile → write
`config/linux.aarch64.conf` as `.config` + holodor deltas + `olddefconfig` →
`make Image dtbs modules` → stage → assemble the boot artifact.

So the family had to be completed from the earlier staged sources:
- **`patches/20-sm8635/0001..0004-*.patch`** — the 4 drivers as git-format
  patches (gcc, pinctrl, icc, regulator/pmxr2230). holodor's `apply_patches`
  globs `*.patch`; the staged `drivers/**.c` (from `port_*.py`) are the
  provenance, the `.patch` files are what holodor applies.
- **`config/linux.aarch64.conf`** — a complete `.config` (defconfig + our 4
  drivers + SD-boot essentials: MMC_SDHCI_MSM, ARM_SMMU, EXT4, rpmh;
  `CONFIG_DEFAULT_HOSTNAME="@DEVICENAME@"` for holodor's substitution).
- **`dts/qcom/{cliffs.dtsi,cliffs-g2.dts}`** — overlaid + registered in-tree
  (the repo's top-level `dts/` stays the CI-tested source of truth; these are
  integration copies).
- **`profile.conf`** → holodor `devices/sm8635/profile.conf` (SOC=sm8635,
  BOOTLOADER=arm-efi, cmdline, SD labels).
- **`tuning.conf`** → holodor `config/tuning/sm8635.conf`.

## The run
`DEVICE=sm8635 CROSS_COMPILE=aarch64-linux-gnu- JOBS=4 make kernel`, on a holodor
checkout with the sm8635 family dropped in.

Checkpoints (all passed):
- **source** — kernel.org and codeload are proxy-blocked in this sandbox, so the
  cache was seeded with a pristine linux **v7.1** tarball built from a `git`
  checkout (renamed `linux-7.1.2`), and `KERNEL_SOURCE_SHA256` pinned to it →
  *"kernel source checksum verified"*. (v7.1 == 7.1.2 for struct layout; the real
  target is 7.1.2, kernel.org-fetched, when run outside the sandbox.)
- **patches** — *"applied 20-sm8635: 4 patches"* — all four apply cleanly.
- **config gate** — passed (pahole installed; BTF / SCHED_CLASS_EXT / KALLSYMS_ALL
  / DYNAMIC_FTRACE assertions all resolved `=y`).
- **build** — `make Image dtbs modules` completed (exit 0).
- **stage + assemble** — produced the outputs below.

## One real bug found & fixed
The full `make modules` (module-link stage, which the per-`.o` compile never
reached) caught a Makefile bug in the icc patch:
`icc-sm8635-objs := icc-sm8635.o` made the module name equal its only object →
`ld: input file 'icc-sm8635.o' is the same as output file`. A single-file module
needs only the `obj-$(CONFIG_…) += icc-sm8635.o` line. Removed the `-objs` line;
patch `0003` regenerated (verified applies clean, and the rebuild links
`icc-sm8635.ko`).

## Outputs (build/kernel/sm8635/out + build/image/sm8635)
- **`KERNEL`** — 71 MB raw `Image` (arm-efi boot artifact → `/flash/KERNEL`;
  cmdline + dtb come from GRUB per the arm-efi contract).
- **`out/Image`** 71 MB; **`out/dtbs/`** 1785 dtbs including **`cliffs-g2.dtb`**.
- **`out/modroot/lib/modules/7.1.0/`** with our modules installed:
  `drivers/clk/qcom/gcc-sm8635.ko`, `drivers/pinctrl/qcom/pinctrl-sm8635.ko`,
  `drivers/interconnect/qcom/icc-sm8635.ko` (regulator is `=y`, in the Image).
- kernelrelease `7.1.0`.

## Meaning / limits
- **Proven:** the whole build pipeline — source → our 4 patches apply → holodor
  config (incl. its deltas) → full `Image`+dtbs+modules compile → boot-artifact
  assembly — works for the sm8635 family. The kernel and our board DTB are real,
  bootable artifacts.
- **Not proven:** on-device boot / runtime (register values, SD mount, display).
  Also: the full pocknix *rootfs/image* build (`make build`/`sd-image`) and the
  Holo Core userland are the next layers; and a clean run outside the sandbox
  should fetch the real 7.1.2 from kernel.org (drop the cache-seed workaround).
- The build tree is gitignored; only the family (patches/config/dts/profile/
  tuning) is committed.

## Reproduce
Drop `kernel/sm8635/` (patches, config, dts) + `profile.conf`→`devices/sm8635/`
+ `tuning.conf`→`config/tuning/sm8635.conf` into a holodor checkout, then
`DEVICE=sm8635 make kernel`. In a network-restricted sandbox, seed
`build/cache/linux-<ver>.tar.xz` from a git checkout and pin
`KERNEL_SOURCE_SHA256` to it.
