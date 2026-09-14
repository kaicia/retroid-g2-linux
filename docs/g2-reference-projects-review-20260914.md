# pocknix / Armada review, and the vendor-source check — 2026-09-14

Two tasks: verify that Qualcomm's Cliffs vendor source is published, and study
pocknix and Armada as references. The second went well. The first is **blocked**
and is reported as blocked, not as done.

## 1. Vendor-source check — BLOCKED, needs a browser

`git.codelinaro.org` is **unreachable from this session** — the connection
fails outright (not a 404, not an auth error). `git.kernel.org` is likewise
unreachable. Only `raw.githubusercontent.com` and `api.github.com` are
available, and the GitHub API is scoped to this repository.

So the question that decides whether Tiers 1–3 of
`docs/g2-cliffs-port-estimate-20260914.md` are tractable is still open.

**What to check, from any browser:**

```
https://git.codelinaro.org/clo/la/kernel/msm-6.1
```

Look for, on a `cliffs`/`pineapple`-family branch or tag:

| File | What it unlocks |
|---|---|
| `drivers/clk/qcom/gcc-cliffs.c` | the clock tree — the single largest item |
| `drivers/pinctrl/qcom/pinctrl-cliffs.c` | the pin/function mux map |
| `drivers/interconnect/qcom/cliffs.c` | NoC topology, links, QoS |
| `include/dt-bindings/clock/qcom,gcc-cliffs.h` | the clock IDs our DT already references |
| `include/dt-bindings/interconnect/qcom,cliffs.h` | the ICC IDs (47/512/2/542) |

The device runs ACK `6.1.115-android14-11` with `gcc_cliffs`, `pinctrl_cliffs`
and `qnoc_cliffs` loaded as modules; those are GPL, so the source should exist.
Confirming it is a one-minute check and nothing in Tier 1+ should be committed
to before it is answered.

## 2. pocknix and Armada — what they actually are

| | Repo | State |
|---|---|---|
| pocknix | `shuuri-labs/pocknix-os` | public, cloned and read |
| Armada | `shuuri-labs/armada` | **private** — anonymous clone is refused and this session cannot attach a cross-owner repo |

Armada could not be read. Everything below about it comes from pocknix's own
references to it.

### This invalidates two of this repository's citations

`docs/development-roadmap-20260822.md` cites "Armada issue #1" and "Armada issue
#155" as evidence. Those issues are in a **private repository**, so the
automated loop that wrote that document could not have read them either. Treat
both citations as unverified.

The #155 claim is worse than unverified — pocknix's own device profile
contradicts it. The roadmap says:

> Armada issue #155 documents a verified **RP6** path through stock UEFI +
> removable SD, explicitly avoiding an ABL flash.

But `devices/sm8550/profile.conf` (RP6) reads:

```
# --- qcom-abl boot contract (what the ROCKNIX-flashed ABL expects) ---
: "${BOOTLOADER:=qcom-abl}"
```

RP6 requires a **flashed** ABL. It is the **RP5** that boots off the factory
bootloader. The roadmap attributed the stock-bootloader path to the wrong
device, and it is the one precedent this project most depends on.

## 3. The precedent does not transfer — but a different one does

### What pocknix is not

pocknix does **no SoC enablement**. Its kernel recipe is stock kernel.org source
plus the ROCKNIX patch stack:

```
: "${KERNEL_VERSION:=7.2}"
: "${KERNEL_SOURCE_URL:=https://www.kernel.org/pub/linux/kernel/v7.x/linux-7.2.tar.xz}"
```

No CodeLinaro, no CAF, no vendor kernel anywhere in the repository. It can work
that way because **both its SoCs are already fully supported upstream** —
SM8550 (RP6, AYN Odin 2 family) and SM8250 (RP5, Flip 2). Its patches are
board-level: panels, touchscreen, gamepad MCU, audio, suspend/resume.

This repository's `development-roadmap-20260822.md` adopted pocknix's
"iterative bring-up" method as the G2 model. That method assumes an upstream SoC
base exists. For Cliffs it does not, so the shape of the work does not carry
over — only the discipline does.

Incidentally the roadmap's recorded pocknix kernel pin (Linux 7.1.5, sha256
`22a0196b…`) is now stale: pocknix moved to 7.2 (`f9fef3d1…`) on 2026-08-25.

### What does transfer: the RP5 arm-efi boot contract

This is the valuable find, and it is a working, shipping implementation of
exactly the boot path this project needs. From `devices/sm8250/profile.conf`:

> SM8250 boots via UEFI GRUB off the device's **FACTORY ABL**: XBL → factory ABL
> → `EFI/BOOT/bootaa64.efi` → `grub.cfg` → `linux /KERNEL` (RAW arm64 Image) +
> `devicetree /boot/grub/<board>.dtb`. **pocknix flashes no ABL here** (the
> ROCKNIX ABL is neither required nor recommended).

SD card layout:

- GPT p1 — FAT32, GPT partition name `system`, containing `KERNEL`,
  `KERNEL.md5`, `EFI/`, `boot/grub/`
- GPT p2 — ext4 root

and the menu entry itself:

```
menuentry 'pocknix (Retroid Pocket 5)' --id 'rp5' {
        search --set -f /KERNEL
        linux /KERNEL root=PARTUUID=… rw … rootwait console=tty0 video=efifb:off gpt
        devicetree /boot/grub/sm8250-retroidpocket-rp5.dtb
}
```

Three things matter for the G2:

1. **`EFI/BOOT/bootaa64.efi` is the removable-media fallback path.** UEFI boots
   it from removable media without a boot entry, so nothing is written to the
   internal `uefivarstore`. This is exactly the avoidance
   `docs/g2-boot-console-feasibility-20260912.md` §2 recommended, now confirmed
   as the mechanism a shipping distribution uses.
2. **GRUB's `devicetree` command supplies the DTB from the SD card.** No
   `dtbo`/`boot` partition flashing, no internal write. The G2's Cliffs DTB can
   be handed to the kernel this way.
3. **No initramfs** — storage drivers are built in and `root=` points at an SD
   PARTUUID.

The G2 is well placed for this shape: bootloader already unlocked, `uefi_a` /
`uefi_b` / `uefisecapp` / `uefivarstore` partitions present, and no ESP on
internal storage so an SD-hosted ESP does not compete with one.

What is still unverified for the G2 specifically is whether its factory ABL
enumerates removable media and runs the fallback path. RP5 does; that is
precedent, not proof.

## 4. Effect on the Tier 0 plan

`docs/g2-cliffs-port-estimate-20260914.md` §3 put Tier 0 (a first kernel log) at
roughly zero Cliffs-specific code, reached via `earlycon` on the debug UART, and
flagged physical access to gpio22/23 as the open risk.

The RP5 contract offers a route that sidesteps that risk entirely: boot through
EFI and take the console from the firmware's framebuffer rather than a UART.
`console=tty0` in the RP5 cmdline means the framebuffer console carries the
boot. That needs no UART pads and no Cliffs driver code.

Revised Tier 0 target:

```
SD card, GPT: p1 FAT32 (EFI/BOOT/bootaa64.efi + grub.cfg + KERNEL) , p2 ext4
  grub.cfg: linux /KERNEL earlycon console=tty0 …
            devicetree /boot/grub/cliffs-g2.dtb
```

with `cliffs-g2.dtb` the minimal 200–400 line DTSI, no regulator nodes.

Open items for this route: whether the G2's ABL runs the removable fallback, and
which GRUB build to use — pocknix ships a `bootaa64.efi` extracted from a ROCKNIX
release rather than building one, and its provenance notes should be read before
copying that approach.

## 5. Status

- Vendor-source check: **blocked**, needs a browser (§1).
- pocknix: read, and it reframes the project — see §3.
- Armada: private, unreadable; two of this repository's citations rest on it and
  one of them is contradicted by pocknix (§2).
