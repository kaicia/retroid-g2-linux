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

## Result 2026-10-05: first USB boot → dwc3 soft reset timeout

Log: `dumps/g2/linux-boot/usb-boot-001-20261005.txt`.

The new kernel boots normally. All of the new parts bind:
- `spmi_pmic_arb c400000.spmi: PMIC arbiter version v7`;
- `qcom_pdc`;
- `tcsr_cc-sm8650`;
- `snps-eusb2-hsphy -> 88e3000.phy`;
- `qcom-eusb2-repeater -> pmic@7:phy@fd00`;
- the four new LDOs.

The TCSR layout matches SM8650: the UFS clkrefs that the bootloader leaves on
read "hardware enable Y" at the sm8650 offsets.

dwc3 itself fails:
- `dwc3-qcom a600000.usb: DWC3 controller soft reset failed.`
- `... failed to initialize core` and `probe ... failed with error -110`.

**Cause:** this is a DWC_usb31 core, whose `DCTL.CSFTRST` clears only after
every clock has synchronised, the PIPE clock included. With no SS/QMP PHY
there is no PIPE clock.

**Fix:** add `qcom,select-utmi-as-pipe-clk` to `usb_1`. dwc3-qcom then sets
`PIPE_UTMI_CLK_SEL | PIPE3_PHYSTATUS_SW` in QSCRATCH before the core probes,
as mainline HS-only ports (hamoa, lemans) do. The change is DT only; the kernel
is the same as the first USB build.

## Result 2026-10-05: with UTMI-as-PIPE → enumeration starts, descriptor fails

- The panel shows `usb : gadget bound to a600000.usb (CDC-ACM serial: shell on
  ttyGS0)`. dwc3 now probes, the UDC exists, and the configfs gadget binds.
- Windows: **"Unknown USB device (device descriptor request failed)"**. The
  pull-up, PHY and repeater work well enough for the host to see an
  attach. The device then does not answer the first control transfer.
- Candidates:
  - dwc3 interrupt delivery (SPI 133);
  - event-buffer DMA through the SMMU (SID 0x40);
  - eUSB2 signal integrity (repeater or PHY tuning; the vendor hsphy carries
    `qcom,param-override-seq = <0x00 0x58>`).
- The init now saves extra snapshots: `boot-NNN-30s.txt`, and
  `boot-NNN-usb-K-<state>.txt` whenever the UDC state changes. Each snapshot
  has dwc3 debugfs (mode, link_state, lsp_dump, regdump) and
  `/proc/interrupts`. It also runs `g2/autorun.sh` from the FAT partition if
  present, so later diagnostics need no rootfs rebuild.
