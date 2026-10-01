# rev3: full DTB + TLMM reserved GPIOs (try after diag2 works)

`cliffs-g2.dts` with `gpio-reserved-ranges = <56 5>` on tlmm. gcc, the
interconnects, apps_smmu and sdhc_2 are all enabled. The cmdline is the same as
diag2's.
