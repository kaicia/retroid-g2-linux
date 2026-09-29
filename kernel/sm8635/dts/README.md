# kernel/sm8635/dts/ — device tree source

The authoritative Cliffs/G2 device tree during bring-up lives in the repo's
top-level `dts/`:

- `dts/cliffs.dtsi`  — SoC description. Tier 0 base (CPUs, PSCI, arch timer,
  GIC, reserved-memory) **plus the Tier 1/2 providers wired 2026-09-29**:
  board clocks (`xo_board`, `sleep_clk`), the RPMh RSC (`apps_rsc`) +
  `apps_bcm_voter`, GCC (`qcom,gcc-sm8635`), TLMM (`qcom,sm8635-tlmm`), and the
  14 interconnect providers (`qcom,sm8635-*`). These bind the drivers in
  `../patches/20-sm8635/`. Still to add: PMXR2230 regulators, SDCC2/QUP/USB/UFS
  peripheral nodes, PDC (for tlmm wakeup) and rpmhcc.
- `dts/cliffs-g2.dts` — board tree (`model = "Retroid Pocket G2"`,
  `compatible = "retroid,g2", "qcom,cliffs"`), `#include "cliffs.dtsi"`.

Both compile cleanly with `dtc`, zero warnings (verified 2026-09-29; grown dtb
~9.4 KB with providers, was ~6.5 KB at Tier 0; Tier 0 dtb archived at
`release/tier0/sd-files/cliffs-g2.dtb`). Provider `reg`/irq/RSC values are from
the archived G2 device tree; see `docs/g2-dts-providers-wiring-20260929.md`.

At holodor integration time these files populate this directory (holodor's
`build-sd-image.sh` copies `${KOUT}/dtbs/*.dtb` onto the SD boot partition and,
for arm-efi, `grub.cfg` names the dtb via `devicetree /boot/grub/<board>.dtb`).
Kept as a pointer here rather than a copy so there is a single source of truth
during active DTS work; the integration script copies them in.

As Tier 1+ drivers land, grow `cliffs.dtsi` with the matching providers (gcc,
pinctrl, interconnect, regulators) per `../patches/20-sm8635/PORT-MANIFEST.md`.
