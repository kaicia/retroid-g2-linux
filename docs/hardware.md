# Retroid Pocket G2 Hardware Investigation

This document records hardware information confirmed directly from the running Android Device Tree.

The current investigation has confirmed an SDHCI controller at:

/sys/firmware/devicetree/base/soc/sdhci@8804000

The controller is configured as a Qualcomm MSM SDHCI v5 controller with a 4-bit bus.

The SD card interface is associated with the sdc2 pinctrl states.

GPIO assignments confirmed from the Device Tree:

- GPIO31: SD card detect
- GPIO38: SD data
- GPIO39: SD data
- GPIO48: SD data
- GPIO49: SD data
- GPIO51: SD command
- GPIO62: SD clock

These values are direct observations from the G2 Android Device Tree and should be treated as hardware evidence for the Linux porting work.
