# USB device mode: a shell over USB (2026-10-01)

Goal: replace the photo, SD-swap and RAM-dump loop with a shell on the PC.
The G2 enumerates as a USB CDC-ACM serial device. On Windows it is a COM port;
on Linux it is `/dev/ttyACM0`. A busybox shell runs on it.

## Hardware topology (from the G2's live device tree)
`dumps/g2` plus the full `/sys/firmware/devicetree/base` capture, decompiled
with `dtc -I fs`.

| Block | Vendor node | Notes |
|---|---|---|
| Controller | `ssusb@a600000` → `dwc3@a600000` | `qcom,dwc-usb3-msm`. IRQs: dwc SPI 133, pwr_event SPI 130, dp/dm HS on PDC 14/15 (edge), ss_phy on PDC 17. SMMU SID 0x40. Reset gcc #19 (USB30_PRIM_BCR) |
| GDSC | `qcom,gdsc@139004` `gcc_usb30_prim_gdsc` | Regulator-style in the vendor tree. In mainline it is gcc gdsc 0x39004 |
| HS PHY | `hsphy@88e3000` `qcom,usb-snps-eusb2-phy` | Ref: tcsrcc #4 (= mainline TCSR_USB2_CLKREF_EN). Reset gcc #15 (QUSB2PHY_PRIM_BCR). vdd = PMXR2230 L2 (0.88–0.95 V), vdda12 = L4 (1.2 V) |
| Repeater | `qcom,spmi@c42d000/qcom,pm7550ba@7/eusb2-repeater@fd00` | `qcom,pmic-eusb2-repeater`. vdd18 = L7 (1.8 V), vdd3 = L17 (2.7–3.3 V) |
| SPMI | `qcom,spmi@c42d000` (pmic-arb v7) | Same five regions as mainline sm8650. periph_irq on PDC 1 |
| PDC | `interrupt-controller@b220000` `qcom,cliffs-pdc` | Same pdc-ranges as mainline sm8650 |
| SS PHY | `ssphy@88e8000` | Not used (HS only) |

## Changes
**Kernel** (patch 0001 regenerated; `port_gcc.py` reproduces it byte for byte
from the vendor gcc-cliffs.c):
- `usb30_prim_gdsc`, gdscr 0x39004, the same definition as gcc-sm8650. Added
  as `gcc_cliffs_gdscs[]`, with `USB30_PRIM_GDSC 0` in `qcom,gcc-cliffs.h`.
- Config set to built-in: `PHY_SNPS_EUSB2`, `PHY_QCOM_EUSB2_REPEATER`,
  `USB_LIBCOMPOSITE`, `USB_CONFIGFS`, and the u_serial, ACM, NCM and u_ether
  function units. dwc3, dwc3-qcom, SPMI pmic-arb, PDC and sm8650 tcsrcc were
  already `=y`.

**DT** (`cliffs.dtsi`):
- `#power-domain-cells` on gcc.
- `tcsr` (`qcom,sm8650-tcsr`; the vendor calls cliffs' TCSR CC
  "pineapple-tcsrcc").
- `pdc`.
- `spmi_bus` with `pm7550ba` and `pm7550ba_eusb2_repeater`
  (`qcom,pm7550ba-eusb2-repeater`, `qcom,pm8550b-eusb2-repeater`, as in
  mainline pm7550ba.dtsi).
- `usb_1_hsphy` (`qcom,sm8550-snps-eusb2-phy` fallback).
- `usb_1` (flattened `qcom,snps-dwc3`, `dr_mode = "peripheral"`,
  `maximum-speed = "high-speed"`).
- PMXR2230 L2B, L4B, L7B and L17B, each pinned to one vendor voltage.

**Userland** (`rootfs/g2-mini/sbin/init`):
- A configfs gadget `g2`: 1d6b:0104, one `acm.usb0` function, bound to the
  first UDC.
- A respawning `setsid -c /bin/sh -i` on `/dev/ttyGS0`.
- The UDC state shown on the live status line and saved in the log bundle.

## Build
`scripts/build-g2-kernel.sh` is a standalone kernel build: v7.1 from GitHub,
`git am` of the patches, our DTS and the full config, then
`make Image qcom/cliffs-g2.dtb`. The SD image comes from
`scripts/build-g2-minirootfs.sh` and `scripts/build-g2-qcomabl-sd-image.sh`
(`ROOTFS_DIR`).

## Known gaps
- No rpmhpd, so the dwc3 `required-opps` (CX nominal) vote is absent. It is
  harmless at HS; revisit with rpmhpd.
- No Type-C or role switching (pmic-glink), no SuperSpeed, no host mode.
- If the tcsr clkref offset differs on cliffs, the PHY has no ref clock. The
  log bundle will show it: the eUSB2 PHY init fails, or the UDC stays at
  "not attached".
