# G2 Tier 0 — first boot evidence

Goal: **one line of kernel output from the G2.** Not a desktop, not a working
SD card, not a usable device. One line.

Nothing is written to the G2's internal storage and no bootloader is flashed.
This is Path A from `docs/g2-decisions-20260914.md` §1.

## 1. What was built

| Artifact | Source | Notes |
|---|---|---|
| `dts/cliffs.dtsi` | new | minimal Cliffs SoC: CPUs, PSCI, timer, GIC, firmware carve-outs, the debug UART |
| `dts/cliffs-g2.dts` | new | G2 board: model/compatible, `qcom,msm-id`/`board-id`, aliases, `chosen` |
| `boot/grub.cfg` | new | three boot entries, described below |
| `scripts/build-g2-tier0-sd-image.sh` | new | builds `bootaa64.efi` and a GPT + FAT32 SD image |

Every value in the device tree comes from the G2's own archived tree
(`dumps/g2/g2-devicetree-20260914-222623.tar.gz`). Nothing is inherited from
upstream `milos`, which is a different SoC.

The device tree compiles clean and its only DT-schema finding is the
unregistered board compatible, expected for an out-of-tree board:

```
cliffs-g2.dtb: /: failed to match any schema with compatible:
  ['retroid,g2', 'qcom,cliffs']
```

## 2. Why this needs no Cliffs driver code

The estimate put Tier 0 at roughly zero Cliffs-specific code
(`docs/g2-cliffs-port-estimate-20260914.md` §3). That holds, and the console is
the reason.

`early_init_dt_scan_chosen_stdout()` in `drivers/of/fdt.c` resolves
`chosen/stdout-path`, matches the node's compatible against the earlycon table,
and calls `of_setup_earlycon()` — and it **does not check `status`**. So the
UART node can stay `disabled` (it has no clock, because there is no Cliffs clock
driver yet) and earlycon still attaches to it. The kernel writes to the UART's
registers directly, at the baud the firmware already programmed for its own log.

In the DTB the chain resolves as:

```
chosen/stdout-path = "serial0:115200n8"
aliases/serial0    = /soc@0/serial@a94000
serial@a94000      compatible = "qcom,geni-debug-uart"
                   reg = <0x0 0xa94000 0x0 0x4000>
```

`OF_EARLYCON_DECLARE(qcom_geni, "qcom,geni-debug-uart", …)` in
`drivers/tty/serial/qcom_geni_serial.c` is the matching entry.

## 3. Boot chain

```
XBL → factory ABL / UEFI
    → SD card GPT partition 1 (FAT32 ESP)
    → \EFI\BOOT\BOOTAA64.EFI          (the removable-media fallback path)
    → GRUB → /boot/grub/grub.cfg
    → linux /KERNEL <cmdline>
    → devicetree /cliffs-g2.dtb
```

Using the `\EFI\BOOT\` fallback rather than registering a boot entry is
deliberate: registering one would make UEFI write to the internal `uefivarstore`
partition. This way internal storage is never touched. It is also exactly what
pocknix does on the RP5 (`docs/g2-reference-projects-review-20260914.md` §3).

SD card layout:

```
GPT partition 1, FAT32, label G2BOOT
  /EFI/BOOT/BOOTAA64.EFI
  /boot/grub/grub.cfg
  /cliffs-g2.dtb
  /KERNEL
```

## 4. Build

```sh
# device tree
scripts/build-g2-dtb-compile-candidate.sh cliffs-g2

# kernel (arm64 defconfig is sufficient: EFI stub, GICv3, PSCI,
# arch timer and the geni earlycon are all enabled by default)
make -C .build/linux ARCH=arm64 LLVM=1 -j"$(nproc)" Image

# SD image
scripts/build-g2-tier0-sd-image.sh
```

The image builder writes a **file**. It never touches a block device; putting
the image on a card is a separate manual step and the script prints the command.

## 5. What success looks like

There is no root filesystem, so a successful boot ends in a panic:

```
VFS: Unable to mount root fs on unknown-block(0,0)
Kernel panic - not syncing: No working init found.
```

**That panic is the result we want.** Reaching it means the firmware handed off
to GRUB, GRUB accepted the DTB, the CPUs and timer came up, and the console
works. `panic=60` holds the message long enough to read or photograph.

## 6. Reading the outcome

Three menu entries exist so that a blank screen still tells us something.

| Entry | What it isolates |
|---|---|
| `g2-tier0` | `earlycon` with no argument → follows our `stdout-path`; `console=tty0` also puts the log on the display |
| `g2-tier0-addr` | `earlycon=qcom_geni,0xa94000` → explicit address, in case stdout-path resolution fails |
| `g2-tier0-fb` | display only → separates "kernel never started" from "kernel started, UART unreachable" |

| Observation | Reading |
|---|---|
| GRUB menu appears | the biggest unknown is resolved — the factory bootloader runs the removable-media fallback. Path A is viable |
| No GRUB menu, Android boots normally | the firmware did not take the card. Path A may be dead; reassess against Path B |
| GRUB menu, then a blank screen on every entry | the kernel is not starting, or is dying before any console. Suspect the DTB |
| Kernel log on the display but not the UART | the UART lines are not physically reachable. Continue on the framebuffer |
| Kernel log on the UART | best case — a real console for everything afterwards |
| Panic about the root filesystem | **Tier 0 complete** |

Whatever happens, the device is unaffected: remove the card and Android boots as
before.

## 7. What Tier 0 deliberately omits

No clock, pinctrl, interconnect, regulator or SMMU providers, so **no device will
probe**. No SD card access from Linux, no display driver, no USB, no storage.
Those are Tier 1 and they need the Cliffs vendor drivers located in
`docs/g2-cliffs-vendor-source-found-20260914.md`.

Also absent on purpose:

- **`/memory`** — under EFI the kernel takes its memory map from the firmware and
  ignores this node. A guessed one could hand Linux memory the firmware is still
  using.
- **`firmware/scm`** — the binding wants a SoC-specific compatible ahead of
  `qcom,scm` and there is no `qcom,scm-cliffs`; schema validation rejects the
  bare form. Nothing in Tier 0 needs SCM.

## 8. Next increment

A minimal initramfs with a static `/init` that prints and sleeps would turn the
panic into a live prompt, and costs little. That is the natural step after the
first successful boot, before starting Tier 1.
