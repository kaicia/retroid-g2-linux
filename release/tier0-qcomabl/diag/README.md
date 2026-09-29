# Diagnostic KERNEL: display-safe

Copy `KERNEL` over the one on the SD card's FAT partition, and delete
`KERNEL.md5`. Background: `docs/g2-sd-boot-rocknix-abl-20260929.md`.

- DTB `cliffs-g2-diag.dtb`, built from `dts/cliffs-g2-diag.dts`, is rev 2 with
  these disabled: apps_smmu, all interconnect providers, gcc, sdhc_2. It carries
  `__symbols__`.
- The cmdline is `console=tty0 loglevel=8 ignore_loglevel clk_ignore_unused
  pd_ignore_unused`.
- The kernel Image is the same as rev 2.
