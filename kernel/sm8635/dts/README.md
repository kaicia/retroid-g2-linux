# kernel/sm8635/dts/ — device tree source

The authoritative Cliffs/G2 device tree during bring-up lives in the repo's
top-level `dts/`:

- `dts/cliffs.dtsi`  — Tier 0 SoC description (CPUs, PSCI, arch timer, GIC,
  reserved-memory). 409 lines. No clock/pinctrl/interconnect/regulator providers
  (those are Tier 1+ and need the drivers in `../patches/20-sm8635/`).
- `dts/cliffs-g2.dts` — Tier 0 board tree (`model = "Retroid Pocket G2"`,
  `compatible = "retroid,g2", "qcom,cliffs"`), `#include "cliffs.dtsi"`.

Both compile cleanly with `dtc` (verified 2026-09-29; Tier 0 dtb ~6.5 KB, also
archived at `release/tier0/sd-files/cliffs-g2.dtb`).

At holodor integration time these files populate this directory (holodor's
`build-sd-image.sh` copies `${KOUT}/dtbs/*.dtb` onto the SD boot partition and,
for arm-efi, `grub.cfg` names the dtb via `devicetree /boot/grub/<board>.dtb`).
Kept as a pointer here rather than a copy so there is a single source of truth
during active DTS work; the integration script copies them in.

As Tier 1+ drivers land, grow `cliffs.dtsi` with the matching providers (gcc,
pinctrl, interconnect, regulators) per `../patches/20-sm8635/PORT-MANIFEST.md`.
