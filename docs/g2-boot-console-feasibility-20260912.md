# G2 boot and console feasibility — 2026-09-12

Build-side investigation of the question that gates the first real device test:
**if we boot something on the G2, will we be able to see anything?**

Everything here comes from re-reading the existing dumps in `dumps/g2/` against
upstream Linux at `5225b8eec4c9bb21aecff6295fab6346a3c3738e`. No device was
accessed. Several of these facts were already in the dumps and had never been
written down anywhere in this repository.

## 1. The bootloader is already unlocked

```
ro.boot.flash.locked        = 0
ro.boot.vbmeta.device_state = unlocked
ro.boot.verifiedbootstate   = orange
```

This removes the scenario that would have broken the project's premise: no
unlock step is needed, so no userdata wipe is needed, and booting an unsigned
kernel does not require changing the device's lock state.

Caveat: this unit runs an engineering build
(`qti/pineapple/pineapple:15/AQ3A.250226.002/eng.RPG2.20260123.180002:user/dev-keys`).
A retail G2 may ship locked. Do not generalise this to other units.

## 2. The boot chain is UEFI

Partition table contains `uefi_a`, `uefi_b`, `uefisecapp_a`, `uefisecapp_b` and
`uefivarstore`, and the device tree reserves `uefi_log_region@81ce4000`. This is
the Qualcomm XBL/ABL UEFI stack.

There is **no ESP on internal storage**. An EFI boot would therefore come from
the microSD card's own EFI system partition, which is exactly the reversible
arrangement the project requires and the same shape as the RP6 path documented
in Armada issue #155.

One caution: registering an EFI boot entry makes UEFI write to the internal
`uefivarstore` partition. That is an internal write, small and reversible, but
still a write. It is avoidable — boot via the removable-media fallback path
`\EFI\BOOT\BOOTAA64.EFI` on the SD card instead of adding a boot entry, and
internal storage is never touched.

## 3. The device names its own debug console

`/sys/firmware/devicetree/base/chosen/stdout-path` decodes to:

```
/soc/qcom,qupv3_0_geni_se@ac0000/qcom,qup_uart@a94000:115200n8
```

Upstream has exactly that controller:

```dts
/* arch/arm64/boot/dts/qcom/milos.dtsi */
uart5: serial@a94000 {
        compatible = "qcom,geni-debug-uart";
        reg = <0x0 0x00a94000 0x0 0x4000>;
        interrupts = <GIC_SPI 525 IRQ_TYPE_LEVEL_HIGH 0>;
        clocks = <&gcc GCC_QUPV3_WRAP0_S5_CLK>;
        ...
        status = "disabled";
};
```

and `milos-fairphone-fp6.dts` turns it on in three lines (`serial0 = &uart5`
alias plus `&uart5 { status = "okay"; }`).

So the console the G2's own firmware designates is already supported upstream,
at the same register address, with no driver work required.

### The pin-map caveat, and why it may not matter

`docs/g2-provider-domain-decision-20260912.md` §4.3 establishes that the G2's
TLMM map differs from upstream milos. Upstream's `qup_uart5_default` uses
`gpio25`/`gpio26` with function `qup0_se5`; the G2's assignment for this UART is
not in any dump yet.

However, `earlycon` writes to the UART's MMIO registers directly, and the
bootloader has already muxed these pins for its own log output before Linux
starts. Early console output can therefore work before Linux pinctrl runs at
all, even with the pin map unresolved. Getting the pins right matters for the
full `console=` handover later, not for first evidence.

### Still unknown: physical access

Whether the UART lines are reachable — test pads, a board header, or muxed onto
the USB-C sideband pins — cannot be determined from the device tree. This is the
one part of the console question that needs physical inspection of the device
rather than software investigation.

## 4. Two console-independent evidence channels also exist

### ramoops

> **Corrected 2026-09-14.** The region turned out to have no fixed `reg` — it is
> dynamically allocated, so its address differs per boot and an Android-side
> readback of *our* kernel's log does not work without extra machinery. This
> section overstated it; see `docs/g2-dump-findings-20260914.md` §4. It is now
> ranked third, not first.

`reserved-memory` contains a `ramoops_region` with `compatible`, `size`,
`pmsg-size`, `mem-type` and `alloc-ranges` properties. Upstream carries
`fs/pstore/ram.c`, and a `ramoops` reserved-memory node is an established
pattern in the qcom DTS directory (`msm8956-sony-xperia-loire.dtsi`,
`msm8992-lg-bullhead.dtsi`).

This is the most valuable fallback: a kernel log that survives a reboot. Boot
the candidate, let it fail, reboot into Android, and read the log out of
`/sys/fs/pstore`. It turns a blind test into a readable one with no console at
all. The region's address and size still need to be captured.

### splash region / simple-framebuffer

`reserved-memory` contains a `splash_region` with `reg` and `label`, and there
is a `splash` partition. The firmware therefore paints the panel before Linux
starts. A `chosen { framebuffer { compatible = "simple-framebuffer"; ... } }`
node pointed at that buffer is a well-established pattern for Qualcomm ports in
this tree (`msm8937-xiaomi-land.dts`, `msm8953-*`), and `simpledrm` is present.

This would give a visible text console with no display driver work, but it needs
the splash region's address, the panel geometry, and the pixel format — none of
which are captured yet.

## 5. Panel identity (new hardware fact)

Fully decoding `chosen/bootargs` yielded a value that appears nowhere else in
the repository:

```
msm_drm.dsi_display0=qcom,mdss_dsi_g1548_fhd_plus_60_video
```

So the panel is a `g1548`, FHD+, 60 Hz, DSI **video** mode. That is the starting
point for the eventual display bring-up, and it constrains the framebuffer
geometry needed for the option above.

The same bootargs also confirm the production kernel runs with **no `console=`
and no `earlycon`**, plus `printk.console_no_auto_verbose=1` — the console is
compiled-in but silenced, which is consistent with a debug UART that exists but
is not wired for the user.

## 6. Console strategy, ranked

Revised after the 2026-09-14 dump:

| | Channel | Driver work | Blocked on |
|---|---|---|---|
| 1 | `earlycon` on `serial@a94000` (SPI 358, TX gpio22 / RX gpio23, already `status = "ok"`) | none | physical access to the UART lines |
| 2 | `simple-framebuffer` at `0xE3940000` (45 MB region; panel 1080x1920, 24 bpp) | none — `simpledrm` in tree | pixel format and stride |
| 3 | ramoops readback from Android | none, but the region is dynamically allocated | needs both kernels pinned to one fixed address plus raw-memory access |
| 4 | USB gadget serial | moderate | only works late in boot; useless for early hangs |

Options 1–3 all require zero new driver code. Option 2 is the one that needs
nothing from the hardware except a reboot, so it is the safety net: even if the
UART turns out to be unreachable and the framebuffer handoff does not work, a
boot attempt still produces a readable log.

## 7. What the first boot test does not need

Worth stating because it reorders the work queue. UEFI reads the kernel, DTB and
initramfs from the SD card using its **own** firmware SD driver. The kernel then
runs from RAM with an initramfs as its root filesystem. Linux's SDCC2 driver is
only needed to reach the card *after* boot.

So all four SDCC2 risks in `docs/g2-dtb-compile-result-20260912.md` — the pin
map, the SMMU stream ID, the interrupts, and the missing card power — can be
completely unresolved and a first boot can still produce kernel output. They
block a *usable* system, not first evidence.

## 8. Remaining gate before touching the device

1. Run the consolidated dump
   (`scripts/run-g2-consolidated-hardware-dump-readonly-v2.sh`). Section C now
   captures the chosen node, the UART node with its pinctrl, and every
   reserved-memory region's address and size.
2. Pick a console channel from §6 using that data.
3. Determine physical UART accessibility, or commit to ramoops as the channel.
4. Build kernel + DTB + initramfs with the chosen console, and **no regulator
   nodes** — a mis-described rail is the one way a wrong DTS can damage
   hardware.
5. Then boot. Target is one line of kernel output, nothing more.
