# Task 1 — the sm8635/Cliffs kernel, mapped onto holodor — 2026-09-29

Task 1 of the current plan (after the holodor deep-dive and the Path A
re-verification). Goal: produce the **`kernel/sm8635/`** tree the holodor/pocknix
build system consumes, bridging all prior Cliffs porting work into that layout.
This kernel is required for **every** boot path (arm-efi, qcom-abl, `fastboot
boot`), so it is boot-path-agnostic and the long pole — it should proceed
regardless of the Path A result.

## What was created this session (the scaffold)

`kernel/sm8635/` now exists in this repo in holodor's `kernel/<soc>/` shape:

```
kernel/sm8635/
  kernel.conf                     # base 7.1.2, ROCKNIX_SOC=SM8635 (authored), vendor coords
  config/README.md                # linux.aarch64.conf TODO (Tier 1)
  dts/README.md                   # -> repo dts/cliffs.dtsi + cliffs-g2.dts (Tier 0, compiling)
  patches/10-mainline/.gitkeep    # N/A (authored, not synced)
  patches/20-sm8635/PORT-MANIFEST.md  # per-driver port plan from Xiaomi GPL
  patches/30-version/.gitkeep
  bootloader/README.md            # arm-efi vs qcom-abl payload, pending boot decision
  README.md
```

**Key structural fact:** this family is **authored, not `make sync`-ed**. holodor's
`sync.sh` vendors `kernel/<soc>/` from a ROCKNIX `devices/<SOC>` dir, but ROCKNIX
has **no SM8635**. So there is no upstream to sync from — the patch stack is
hand-ported from the Xiaomi Cliffs GPL source and the DTS is our own bring-up
tree. `make sync` must not be run for sm8635 (it would try a nonexistent ROCKNIX
dir).

## Where the prior work lands in this structure

| Prior asset | Maps to | State |
|---|---|---|
| `dts/cliffs.dtsi` (409 ln), `dts/cliffs-g2.dts` (148 ln) | `kernel/sm8635/dts/` | **Tier 0 done; compiles (dtb ~6.5 KB, re-verified 2026-09-29)** |
| SDCC2 characterisation (IRQs, stream ID, pins, OPP, DLL/DDR) | Tier 2 SDHCI node | done + verified; folds into `cliffs.dtsi` at Tier 2 |
| Xiaomi `peridot-u-oss` GCC/pinctrl/interconnect (GPL) | `patches/20-sm8635/` | source located + cross-checked; **porting not started** |
| dt-bindings headers (gcc/interconnect/dispcc/gpucc-cliffs) | ported alongside `patches/20-sm8635/` | present in source |
| archived G2 device tree (`dumps/g2/…`) | authoritative board wiring | done; offline reference |

## Base-version decision

Target **mainline 7.1.2** (same as holodor's sm8250/sm8550/sm8750 families) for
parity with the build system. The Xiaomi vendor source is **6.1-based**
(msm-6.1 / ACK 6.1.115), so the port adapts its *data tables* onto the 7.1.x
driver frameworks — the "transcription that has to be exactly right" from the
port estimate. (If 7.1.x framework drift makes a table hard to land, an interim
option is to match whatever base ROCKNIX's nearest SoC uses; but default to 7.1.2.)

## Tier sequencing (from g2-cliffs-port-estimate + PORT-MANIFEST)

| Tier | Content | Cliffs-specific lines | Status |
|---|---|---|---|
| 0 | DTS only → first kernel log (earlycon, no driver) | ~0 (DTSI) | **DONE, compiles** |
| 1 | GCC clock + TLMM pinctrl (+ PDC/RPMh/cpufreq glue) | ~4500–5000 | next |
| 2 | interconnect + mmu-500 + SDHCI + PMXR2230 regulators | +~2000 | after T1 |
| 3 | dispcc + g1548 DSI panel, gpucc + Adreno + Mesa, USB/input/audio/WiFi | +~2000 | long |
| 4 | SteamOS userspace (Holo Core) | userspace | after T3 |

## Concrete next steps

1. **Build a Tier 0 kernel + our dtb and get it to a boot handoff.** This needs no
   Cliffs driver. Two ways, gated by the Path A test:
   - if Path A reopens: `linux /KERNEL` (7.1.2 `Image` + EFI stub) + `devicetree
     cliffs-g2.dtb` via GRUB, `earlycon`, `console=tty0` on the firmware fb;
   - else: wrap the same `Image`+dtb in a boot.img and try `fastboot boot`
     (pending the `ENABLE_BOOT_CMD` check, see the Path A doc), an EDL-loaded
     jump, or fall through to Path B once an ABL exists.
   Success criterion: **one line of kernel output** — the project's first on-device
   milestone.
2. **Author `config/linux.aarch64.conf`** from holodor's sm8550 fragment, minimal
   for Tier 0 (arm64 + earlycon + EFI stub + framebuffer console), then grow it
   per tier.
3. **Start Tier 1 porting** in `patches/20-sm8635/`: `gcc-cliffs.c` first (the
   single largest, gates everything that needs a clock), then `pinctrl-cliffs.c`.
   Pin to Xiaomi commit `062233df…`; split patches per driver; validate each by
   compile before the next.
4. **Stand up a holodor checkout** and drop `kernel/sm8635/` + a
   `devices/sm8635/` (stubbed from sm8550) to drive `make kernel`. This is where
   the config + patches get compiled for real.

## Sources
- `docs/g2-holodor-deep-dive-20260929.md` (kernel/<soc> contract + `make sync`
  limitation), `docs/g2-cliffs-port-estimate-20260914.md` (tiers + line counts),
  `docs/g2-cliffs-vendor-source-found-20260914.md` (Xiaomi source + 3-way
  verification), `docs/g2-path-a-reverify-20260929.md` (boot handoff for Tier 0),
  `kernel/sm8635/` (this session's scaffold), `dts/cliffs.dtsi` + `dts/cliffs-g2.dts`.
