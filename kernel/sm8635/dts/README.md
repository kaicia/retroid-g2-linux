# kernel/sm8635/dts/ — device tree source

The authoritative Cliffs/G2 device tree during bring-up lives in the repo's
top-level `dts/`:

- `dts/cliffs.dtsi`  — SoC description. Tier 0 base (CPUs, PSCI, arch timer,
  GIC, reserved-memory) **plus the Tier 1/2 providers wired 2026-09-29**:
  board clocks (`xo_board`, `sleep_clk`), the RPMh RSC (`apps_rsc`) +
  `apps_bcm_voter`, GCC (`qcom,gcc-sm8635`), TLMM (`qcom,sm8635-tlmm`), and the
  14 interconnect providers (`qcom,sm8635-*`), plus (2026-09-29) the apps SMMU
  (`arm,mmu-500`), the PMXR2230 SD rails (`vreg_l13b`/`vreg_l23b`), and the
  **SDCC2 microSD node** (`status = "okay"`, fully wired to gcc/icc/smmu/
  regulators/tlmm pins). These bind the drivers in `../patches/20-sm8635/`
  (gcc/pinctrl/icc) plus generic mainline drivers (arm-smmu, sdhci-msm,
  rpmh-rsc). Still to add: QUP/UART/USB/UFS peripheral nodes, PDC (tlmm wakeup),
  rpmhcc, rpmhpd (+ sdhc OPP), and a PMXR2230 entry in qcom-rpmh-regulator
  (the one runtime gap for SD — see docs/g2-regulators-sdcc2-wiring-20260929.md).
- `dts/cliffs-g2.dts` — board tree (`model = "Retroid Pocket G2"`,
  `compatible = "retroid,g2", "qcom,cliffs"`), `#include "cliffs.dtsi"`.

Both compile cleanly with `dtc`, zero warnings (verified 2026-09-29; dtb ~12.5 KB
with providers + SMMU + SDCC2, was ~6.5 KB at Tier 0; Tier 0 dtb archived at
`release/tier0/sd-files/cliffs-g2.dtb`). All `reg`/irq/RSC/regulator/SDCC2 values
are from the archived G2 device tree; see
`docs/g2-dts-providers-wiring-20260929.md` and
`docs/g2-regulators-sdcc2-wiring-20260929.md`.

At holodor integration time these files populate this directory (holodor's
`build-sd-image.sh` copies `${KOUT}/dtbs/*.dtb` onto the SD boot partition and,
for arm-efi, `grub.cfg` names the dtb via `devicetree /boot/grub/<board>.dtb`).
Kept as a pointer here rather than a copy so there is a single source of truth
during active DTS work; the integration script copies them in.

As Tier 1+ drivers land, grow `cliffs.dtsi` with the matching providers (gcc,
pinctrl, interconnect, regulators) per `../patches/20-sm8635/PORT-MANIFEST.md`.
