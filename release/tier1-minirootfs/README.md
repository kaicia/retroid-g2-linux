# Tier 1: minimal rootfs on the SD card

This is a full SD image. Write it with Etcher; it has a ROCKNIX-ABL-shaped
layout:
- **p1 FAT32 `system` (POCKNIX):** `KERNEL`, which is the rev6 DTB (MDSS
  placeholder, SCM, SDC2 pins, reserved TLMM GPIOs) plus the 7.1 Image.
- **p2 ext4 `POCKNIX_ROOT`:** static busybox 1.36.1 (Ubuntu arm64
  busybox-static, pinned by sha256) and `rootfs/g2-mini/sbin/init`.

cmdline: `console=tty0 loglevel=7 clk_ignore_unused pd_ignore_unused log_buf_len=4M root=PARTUUID=…0002 rootfstype=ext4 rootwait`
(the root fs is mounted read-only).

What `/sbin/init` does:
1. Mounts proc, sys, devtmpfs, devpts, tmpfs and debugfs, then quiets the
   kernel console.
2. Shows a status screen: model, kernel, cmdline, CPUs, memory, block devices,
   thermal zones, deferred probes, and recent kernel warnings and errors.
3. Saves a full diagnostic bundle to the **FAT partition** as
   `g2-logs/boot-NNN.txt`, then unmounts it. The bundle holds:
   - dmesg;
   - cpuinfo, meminfo, interrupts, iomem;
   - devices_deferred;
   - clk, regulator and interconnect summaries;
   - gpio and pinmux;
   - platform devices and bound drivers.

   Read it on a PC from the POCKNIX drive.
4. Refreshes an uptime, load and free-memory line every 5 s, forever.

There are no input drivers yet. Turn the device off by holding the power key.

Built by:
```
scripts/build-g2-minirootfs.sh
ROOTFS_DIR=.build/g2-minirootfs scripts/build-g2-qcomabl-sd-image.sh
```
