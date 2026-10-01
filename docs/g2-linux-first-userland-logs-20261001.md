# First userland boot logs: what Linux sees on the G2 (2026-10-01)

Source: `dumps/g2/linux-boot/boot-00{1,2}-20261001.txt`. Both were written by
`rootfs/g2-mini/sbin/init` to the SD card's FAT partition. Kernel 7.1.0, rev6
DTB, minimal busybox rootfs. The two boots are identical apart from timestamps.

## Working
| Area | Evidence |
|---|---|
| SoC bring-up | 8 CPUs at EL1 under Gunyah. GICv3 with 988 SPIs, PSCI 1.1 (OSI), arch timer 19.2 MHz |
| Memory | 7210 MiB total, 7060 MiB available. The reserved map matches the vendor tree |
| SCM | `qcom_scm: convention: smc arm 64`, qseecom 0x1402000 found (skipped: untested machine) |
| SMMU | `arm-smmu 15000000.iommu: SMMUv2`, stage-1, coherent walk, default domain translated |
| Interconnect | 14 CLIFFS providers registered. sync_state is held by the MDSS placeholder |
| Regulators | `vreg_l13b` 3.2 V → mmc vmmc (800 mA load), `vreg_l23b` 1.8 V → mmc vqmmc (UHS signalling) |
| SD | `mmc0` IRQ 239 (163 irqs), card-detect IRQ via `msmgpio 31`. SDR104 SDXC, ext4 root |
| Pinctrl | `cliffs-pinctrl`, with reserved GPIOs 56-60 respected |
| Console | simple-framebuffer at 0xe3940000 with fbcon |

## Open items found in the logs

1. **`gcc_sdcc2_apps_clk_src: rcg didn't update its configuration`** (WARN in
   `update_config`, from `sdhci_msm_probe` → `dev_pm_opp_set_rate`).
   - clk_summary shows `gcc_gpll9` with enable_count 1 and hardware-enable N,
     and `gcc_sdcc2_apps_clk_src` at 201999975 Hz from gpll9 (808 MHz / 4).
   - "hardware enable" for a voted lucid-ole PLL is the APPS vote bit
     (0x52020 bit 9). `alpha_pll_lucid_evo_enable()` returns early without
     voting when the PLL is already running in non-FSM mode, so N alone does
     not prove gpll9 is off.
   - The vendor gpll9 carries `vdd_data` (CX ≥ LOW above 615 MHz), and the
     mainline equivalent is a CX performance vote. We have no rpmhpd and no sdhc
     OPP `required-opps` yet.
   - The RCG probably could not switch, because its old or new source was not
     running. The card then runs at whatever rate UEFI left, which is safe but
     possibly slower.
   - Next check: read GPLL9 MODE/USER_CTL, the vote register and the SDCC2 RCG
     CMD/CFG with `devmem`, from init. Then add rpmhpd plus an sdhc OPP table.
2. **ICC "failed to register ICC provider: -517"**, 14 lines at ~0.02 s.
   These are first-pass deferrals, and every provider registers later. The
   message is cosmetic: the driver should use `dev_err_probe()`.
3. **No thermal zones** (`thermal:` section empty). There is no tsens node
   yet, so nothing throttles. Before any sustained load, add tsens and
   thermal zones; until then CPUs stay at the boot frequency.
4. **No cpufreq** (no cpufreq node). The CPUs run at the bootloader's
   frequency. Mainline uses SCMI/CPUCP on this generation; SCMI core is
   registered but there is no node.
5. **No input, USB, PMIC or SPMI.** Nothing can be typed, and there is no
   network or USB gadget.

## Suggested order
1. **USB device mode (gadget: serial and ethernet)**: a shell and SSH from the
   PC. This ends the photo and SD-swap loop. Needs dwc3, the eUSB2 PHY and its
   repeater (PMIC over SPMI), the gcc USB clocks (already ported), and USB
   GDSCs.
2. **Input**: volume and power keys (PMIC PON/RESIN over SPMI, plus GPIO
   keys), then the gamepad MCU.
3. **Thermal and cpufreq**: tsens plus SCMI/CPUCP.
4. **Display**: dispcc plus DPU/DSI and the g1548 panel, filling the MDSS
   placeholder. Then the GPU (Adreno), which the SteamOS userland needs.
5. sdcc2 clock / CX vote cleanup (item 1), together with rpmhpd.
