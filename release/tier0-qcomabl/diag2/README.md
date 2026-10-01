# diag2: display-safe DTB + TLMM reserved GPIOs (try first)

`cliffs-g2-diag.dts`, now on top of `cliffs.dtsi` with
`gpio-reserved-ranges = <56 5>`. apps_smmu, the interconnects, gcc and sdhc_2
are disabled.

cmdline:
`console=tty0 loglevel=8 ignore_loglevel clk_ignore_unused pd_ignore_unused initcall_debug log_buf_len=4M`

Expected: kernel log on screen, ending in "VFS: Unable to mount root fs". If it
hangs again, take a RAM dump; initcall_debug names the last initcall.
