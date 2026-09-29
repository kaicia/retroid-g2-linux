# kernel/sm8635 — Cliffs (Snapdragon G2 Gen 2) kernel family for holodor/pocknix

This is the `kernel/<soc>/` tree the holodor/pocknix build system consumes to
build `linux-pocknix-sm8635` for the Retroid Pocket G2. It is the concrete
"task 1" output identified in `docs/g2-holodor-deep-dive-20260929.md`: every G2
boot path (arm-efi, qcom-abl, or `fastboot boot`) needs this kernel, so it is the
long pole and is boot-path-agnostic.

## Layout (holodor convention)
```
kernel.conf                 base kernel version + SoC labels + source coords
config/linux.aarch64.conf   complete .config (our 4 drivers + SD-boot essentials)
dts/qcom/                   cliffs.dtsi + cliffs-g2.dts (integration copies of repo dts/)
patches/10-mainline/        upstream/mainline patches (empty — authored, not synced)
patches/20-sm8635/          4 driver .patch files (gcc/pinctrl/icc/regulator) that
                            holodor applies + the staged sources/scripts (provenance)
patches/30-version/         kernel-version-specific patches (empty)
bootloader/                 arm-efi GRUB bits (Path A) — pending Path A re-verify
profile.conf                -> holodor devices/sm8635/profile.conf
tuning.conf                 -> holodor config/tuning/sm8635.conf
```

Drop this tree (+ `profile.conf`→`devices/sm8635/`, `tuning.conf`→
`config/tuning/sm8635.conf`) into a holodor checkout and `DEVICE=sm8635 make
kernel`. Verified 2026-09-29: builds `Image` + `cliffs-g2.dtb` + our modules and
assembles the arm-efi `KERNEL` — see `docs/g2-holodor-make-kernel-20260929.md`.

## Authored, not synced
holodor's `make sync` vendors `kernel/<soc>/` from a ROCKNIX `devices/<SOC>` dir.
**ROCKNIX has no SM8635** (SM8250/8550/8650/8750 only), so there is nothing to
sync from — this tree is authored by hand. **Do not run `make sync` for sm8635.**

## Status
- **Tier 0 (DTS):** done, compiles.
- **Tier 1 (GCC + pinctrl):** ported, compile+link+modpost-verified.
- **Tier 2 (interconnect + SDCC2 + PMXR2230 regulators):** ported/wired,
  compile+link+modpost-verified.
- **holodor `make kernel`:** DONE — full `Image` + `cliffs-g2.dtb` + modules +
  arm-efi `KERNEL` built against linux 7.1 (`docs/g2-holodor-make-kernel-20260929.md`).
- Tier 3 (display/GPU/USB/audio) and the pocknix rootfs/image (`make build`,
  Holo Core userland) are the next layers.

See `docs/g2-task1-kernel-sm8635-plan-20260929.md` and
`docs/g2-build-verification-20260929.md` for the full history.
