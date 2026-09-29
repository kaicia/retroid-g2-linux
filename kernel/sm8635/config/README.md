# kernel/sm8635/config/

Holds the kernel defconfig fragment for the Cliffs family, holodor-style:

- `linux.aarch64.conf` — **TODO (Tier 1).** Start from holodor's sm8550
  `linux.aarch64.conf` and enable the Cliffs providers as their drivers land
  (GCC, TLMM pinctrl, interconnect, SDHCI, regulators). Tier 0 (first log) needs
  no defconfig work beyond a generic arm64 + earlycon + EFI-stub config.
- `kernel-firmware.dat` — firmware manifest (as ROCKNIX ships it); populated when
  Tier 3 firmware (display/GPU/Wi-Fi) is added.
