#!/bin/sh
# USB experiment: force the gadget to full speed (12 Mbit/s).
# To use, copy this file to the SD card's FAT partition as g2/autorun.sh.
# Full speed has no HS chirp and far looser signal requirements. If the PC
# enumerates the G2 at full speed but not at high speed, the problem is HS
# signal integrity (eUSB2 PHY or repeater tuning), not the controller.
G=/sys/kernel/config/usb_gadget/g2
UDC=$(ls /sys/class/udc | head -1)
sleep 3
echo "" > $G/UDC
echo full-speed > $G/max_speed
echo "$UDC" > $G/UDC
echo "autorun: gadget rebound at full speed on $UDC"
