# kernel/sm8635 — Cliffs (Snapdragon G2 Gen 2) kernel family for holodor/pocknix

This is the `kernel/<soc>/` tree the holodor/pocknix build system consumes to
build `linux-pocknix-sm8635` for the Retroid Pocket G2. It is the concrete
"task 1" output identified in `docs/g2-holodor-deep-dive-20260929.md`: every G2
boot path (arm-efi, qcom-abl, or `fastboot boot`) needs this kernel, so it is the
long pole and is boot-path-agnostic.

## Layout (holodor convention)
```
kernel.conf                 base kernel version + SoC labels + source coords
config/                     linux.aarch64.conf (kernel defconfig fragment) — TODO
dts/                        device tree (points to repo dts/; Tier 0 present)
patches/10-mainline/        upstream/mainline patches (empty; N/A — authored, not synced)
patches/20-sm8635/          Cliffs SoC drivers, ported from Xiaomi GPL — see PORT-MANIFEST.md
patches/30-version/         kernel-version-specific patches (empty for now)
bootloader/                 arm-efi GRUB bits (Path A) — pending Path A re-verify
```

## Authored, not synced
holodor's `make sync` vendors `kernel/<soc>/` from a ROCKNIX `devices/<SOC>` dir.
**ROCKNIX has no SM8635** (SM8250/8550/8650/8750 only), so there is nothing to
sync from — this tree is authored by hand. **Do not run `make sync` for sm8635.**

## Status
- **Tier 0 (first kernel log, DTS only):** DONE and compiling (`dts/README.md`).
- **Tier 1 (GCC + pinctrl):** next; ports from Xiaomi `peridot-u-oss`
  (`patches/20-sm8635/PORT-MANIFEST.md`).
- Tiers 2–3: interconnect + SDHCI + regulators, then display/GPU/USB/audio.

See `docs/g2-task1-kernel-sm8635-plan-20260929.md` for the full plan and the
concrete next steps.
