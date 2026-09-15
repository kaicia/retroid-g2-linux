# Tier 0 via `fastboot boot`

Path A is closed (`g2-path-a-closed-20260915.md`). This is what replaces it.

## Why this is still safe

`fastboot boot` downloads a boot image into RAM and jumps to it. It does not
write a partition, does not touch the slot, does not change the bootloader.
Power-cycle and Android comes back untouched. It is the same safety property
the SD card had, reached a different way.

The command to never type is `fastboot flash`. Nothing in this document uses
it, and nothing in this project ever should.

## The two problems this had to solve first

### 1. Without EFI there is no screen

Under Path A the EFI stub handed the kernel a Graphics Output Protocol and
`efifb` took it from there. `fastboot boot` has no EFI stub at all: ABL jumps
straight into the kernel. With no display driver - and at Tier 0 there is none,
there are no clock or regulator providers to build one on - the kernel would
have run perfectly and shown nothing.

The fix is the framebuffer the bootloader is *already* driving. XBL/ABL powers
the panel, programs the DPU and streams the boot splash from a fixed buffer.
If Linux does not touch the display clocks or regulators, that stays running,
and text written into the buffer appears on the screen.

Both numbers came out of the device's own dump:

```
/reserved-memory/splash_region   reg = <0x0 0xe3940000 0x0 0x02b00000>
                                 label = "cont_splash_region"
/sys/class/drm/card0-DSI-1/modes 1080x1920x60vid      (the only mode)
```

`dts/cliffs-g2.dts` now carries a `simple-framebuffer` at `0xe3940000`,
1080x1920, stride 4320, `a8r8g8b8`, as the first child of `/chosen` - which is
exactly where `of_platform_default_populate_init()` looks for one.

When that console registers, the kernel replays its whole log buffer into it.
So the screen shows the boot from its first line, not from the moment the
console appeared.

The format is the one guess in the whole file. 32bpp ARGB is what Qualcomm ABL
programs on recent targets and what mainline Qualcomm handset trees use, but
the dump does not state it. **Stripes or noise instead of text means the format
is wrong, not the address** - and that is still a success, because it means the
kernel ran far enough to write into the buffer.

### 2. Without EFI there is no memory map

Same root cause. The EFI stub used to supply one, and `reserve_regions()` would
wipe memblock and rebuild it from the EFI map, so `cliffs.dtsi` deliberately had
no `/memory` node at all. On this path nothing supplies one unless ABL patches
it in, which is not something to assume.

`dts/cliffs-g2.dts` now carries the device's own usable-DRAM list verbatim -
14 ranges, 7.354 GiB of the 8 GiB in the two DDR banks. Not reconstructed from
the bank geometry, because everything missing from that list is secure or
firmware-owned and touching it earns an SError.

The splash buffer sits inside usable range 10 (`0xe1d40000`, 474 MiB), so it is
also reserved `no-map` - otherwise the kernel would allocate over the
framebuffer it is trying to print into. The existing 41 carve-outs in
`cliffs.dtsi` did not cover it: they were generated from the device's `no-map`
children only, and `splash_region` carries no `no-map` property.

## The image

`release/tier0-fastboot/g2-tier0-fastboot.zip` -> `g2-tier0-fastboot.img`,
42,131,456 bytes.

Boot image **header version 2**, built by `scripts/mkbootimg-g2.py`. v2 is the
last version that carries the device tree inside the boot image itself; from v3
on the DTB lives in `vendor_boot`, so `fastboot boot` of a v3 or v4 image would
run our kernel against the **stock Qualcomm device tree**, which is the opposite
of the experiment.

| Section | Size | Load address |
|---|---|---|
| kernel | 42,113,536 | `0xa7008000` |
| ramdisk | 48 | `0xa8000000` |
| dtb | 6,501 | `0xa9000000` |

Addresses come from the one large clean block below 4 GiB in the device's
usable-DRAM map, `0xa7000000 .. 0xd8000000` (784 MiB). The boot header's address
fields are 32-bit, so the 5 GiB block at `0x8c0000000` cannot be named here, and
the 474 MiB block at `0xe1d40000` holds the framebuffer. Many Qualcomm ABLs
override these fields anyway, and the arm64 kernel is `CONFIG_RELOCATABLE` and
will move itself to a 2 MiB boundary regardless.

Command line:

```
console=tty0 loglevel=8 ignore_loglevel panic=60
```

No `earlycon`. There is no clock driver, so whether the GENI UART is clocked
depends on what ABL left behind, and a write to an unclocked GENI block can hang
on the spot. Since the UART pins are not exposed anyway, `earlycon` here is all
risk and no reward. The framebuffer console replays the full log, so nothing is
lost by waiting for it.

The ramdisk is a valid empty gzipped cpio rather than nothing, because some
bootloaders read `ramdisk_size == 0` as a malformed image rather than as "no
ramdisk". The kernel unpacks it, finds no `/init`, and panics.

## What success looks like

**A kernel log on the screen.** That is Tier 0, complete.

It ends in a panic - `No working init found`, or a root-filesystem panic. That
panic *is* the success: it means the kernel got through its entire startup on
Cliffs hardware with our device tree and reached the point of looking for
userspace. `panic=60` reboots the device a minute later, so nothing is stuck.

| What you see | Reading |
|---|---|
| Kernel log, ending in a panic | **Tier 0 complete.** Everything after this is Tier 1 |
| Stripes, noise, or wrong colours | The kernel ran and wrote to the framebuffer; only the pixel format is wrong. Also a success - send a photo and the format gets fixed |
| Splash frozen, then reboot after ~60s | The kernel started and panicked, but the framebuffer console never came up. The address or the `simple-framebuffer` binding is wrong |
| `FAILED (remote: 'unknown command')` | ABL has no `fastboot boot`. This route is closed too; Path B becomes the only option |
| Black screen, no reboot, needs a hard power-off | The kernel died before the console. Suspect the DTB |

## The gate

Everything above assumes ABL implements `fastboot boot`. It is not guaranteed -
some Qualcomm bootloaders ship with it removed - and it costs one command to
find out. `fastboot getvar all` is read-only and should be captured first
regardless: it reports slot state, unlock state, partition sizes and the
bootloader's own version string, none of which we currently have.
