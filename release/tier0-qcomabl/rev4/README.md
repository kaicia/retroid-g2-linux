# rev4: full DTB + SCM + SDC2 pins on GPIOs

Rev 3 booted to the expected VFS panic with every ported driver enabled
(gcc, the CLIFFS interconnects, pinctrl, rpmh regulators). Two things still
deferred:
- `15000000.iommu` returned -517: arm-smmu-qcom waits for SCM, and there was
  no firmware/scm node. Rev 4 adds `qcom,scm-sm8635`, `qcom,scm`.
- `cliffs-pinctrl: does not have pin group sdc2_clk/cmd/data`: SM8635 muxes
  SDC2 on gpio62 (clk), gpio51 (cmd) and gpio38/39/48/49 (data). The pin states
  now use those GPIOs with the vendor drive and bias. `8804000.mmc` then should
  probe and list the SD card's partitions (mmcblk0p1, p2) before the VFS panic.

The cmdline adds `root=PARTUUID=706f636b-…-0002 rootfstype=ext4 rootwait`. That is the
card's p2, the empty ext4 POCKNIX_ROOT. Success is now
`VFS: Mounted root (ext4 filesystem)`, followed by a "No working init found"
panic: the SD path works end to end and there is simply no userland yet. If the
SD card does not come up, the kernel waits at "Waiting for root device" with
mmc/sdhci messages above it.
