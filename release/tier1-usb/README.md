# Tier 1: USB device mode (shell over USB)

`g2-usb-sd.img.xz` is a full SD image. Write it with Etcher, or unpack it and
write with Rufus in DD mode.
- **Kernel:** 7.1.0 from `scripts/build-g2-kernel.sh`. It adds the USB30 GDSC,
  the eUSB2 PHY and PM7550BA repeater, and a built-in configfs gadget. Its full
  config is in `kernel.config`.
- **DTB:** `cliffs-g2.dtb`, with tcsr, pdc, spmi and pm7550ba, the eUSB2 PHY,
  dwc3 in peripheral mode, and L2B/L4B/L7B/L17B.
- **Root fs:** the minimal busybox rootfs. Its init creates a CDC-ACM gadget and
  runs a shell on `/dev/ttyGS0`.

Use:
1. Boot from the card, then connect the G2 to the PC with a USB cable.
2. Windows shows a new **USB Serial Device (COMx)** under Ports. Linux shows
   `/dev/ttyACM0`.
3. In PuTTY choose **Serial** with that COMx (any speed) and press Enter. You
   get the `g2#` prompt.

The panel's live status line ends in `usb <state>`. `configured` means the PC
has enumerated the gadget. `g2-logs/boot-NNN.txt` on the FAT partition has a
`===== usb` section.

Background: `docs/g2-usb-device-mode-20261001.md`.
