# pocknix / Armada review, and the vendor-source check — 2026-09-14

Two tasks: verify that Qualcomm's Cliffs vendor source is published, and study
pocknix and Armada as references. The second went well. The first is **blocked**
and is reported as blocked, not as done.

## 1. Vendor-source check — RESOLVED later the same day

> This section is kept for the record. It was written while CodeLinaro looked
> like a dead end; the source was afterwards found on GitHub instead. See
> `docs/g2-cliffs-vendor-source-found-20260914.md`.

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
| Armada | **`armada-os/armada`** | **public, cloned and read** — pinned `f7eef8886d69af69fa5e9af015d7919a188aaacc` |

### Correction — an earlier revision of this document had Armada wrong

It said Armada was private and unreadable. That was wrong, and the error was in
the *address*, not the access. pocknix's README links
`https://github.com/shuuri-labs/armada`, which is a stale link — that path
behaves byte-identically to a repository that does not exist (git asks for
credentials, `raw.githubusercontent.com` returns 404 for every branch tried,
exactly as for a name invented at random). GitHub deliberately makes private and
absent repositories indistinguishable to unauthenticated clients, so "not
readable" was a correct observation about that URL and a wrong conclusion about
the project.

Armada's actual home is `armada-os/armada`, and it is public. It clones
anonymously through the same proxy as everything else.

### What Armada actually does — corrected again, 2026-09-14

An earlier revision of this section called Armada a "counter-example" that
"writes to internal storage". That conflated two separate things and was
misleading. The accurate picture:

**The operating system lives on, and boots from, the microSD card.** Armada's own
README lists "SD-card boot with optional internal-storage installation". People
run it from SD; that is the normal configuration, not an edge case.

**Installation additionally requires a one-time bootloader swap.** From the
`abl/` directory, the entire write is:

```sh
dd if=.../abl_signed-%DEVICE%.elf of=/dev/block/by-name/abl_a bs=1M
dd if=.../abl_signed-%DEVICE%.elf of=/dev/block/by-name/abl_b bs=1M
```

Two partitions, 258 KiB each per `abl/releases.tsv`. Nothing else on internal
storage is touched — not `boot`, not `system`, not `userdata`, not `vbmeta`. A
`backup_abl.sh` dumps the originals first and `restore_backup_abl.sh` writes them
back, so the change is reversible with the backup in hand.

**Android survives and stays selectable.** The replacement is ROCKNIX-ABL
(`github.com/ROCKNIX/abl`, public), a custom Qualcomm ABL whose stated purpose is
"making Linux the primary boot target **while retaining the ability to boot
Android** whenever needed". It boots Linux from internal storage, SD card or USB,
needs no GRUB or U-Boot, has a configurable default boot target and a
Volume-Up-at-startup override, and is used by ROCKNIX, Batocera, Knulli, Armada,
Thorch, MaSi-OS and NovaDeck.

So Armada is not a counter-example. It is a working, widely-used instance of
exactly what this project wants — Android intact, OS on removable media — reached
by a route this project's rules currently forbid.

### The roadmap citation is still wrong, but for a narrower reason

`docs/development-roadmap-20260822.md` credits Armada with a path "explicitly
avoiding an ABL flash". Armada does flash the ABL; that specific claim does not
hold. What is true, and what the citation was probably reaching for, is that
Armada achieves a reversible SD-booting Linux with Android preserved.

## 2b. Two candidate boot paths for the G2

Both are legitimate and they trade off differently. This is a decision for the
project owner, not a technical conclusion.

| | A — factory ABL + EFI | B — ROCKNIX-ABL swap |
|---|---|---|
| Precedent | pocknix RP5 (`arm-efi`) | Armada, ROCKNIX, Batocera, Knulli, Thorch, … |
| Internal writes | **none** | `abl_a` + `abl_b`, 258 KiB each, backed up and restorable |
| Mechanism | firmware runs `\EFI\BOOT\BOOTAA64.EFI` from the SD card's ESP; GRUB supplies kernel + DTB | purpose-built dual-boot bootloader with a boot-source menu |
| Android | untouched | untouched; selectable from the ABL menu |
| Status for the G2 | **unverified** — needs the G2's factory ABL to run the removable-media fallback | **blocked** — ROCKNIX-ABL must be built per device and no Cliffs build exists |
| Project rules | allowed | forbidden by the current "no ABL modification" rule |

Path B is how essentially the whole handheld Linux ecosystem does this, and its
risk profile is milder than the project's rules imply. But it is not available
today: `ROCKNIX/abl` publishes a README and an updater, not buildable ABL source,
and its own warning is to "verify the ABL is built for your specific device".
A Cliffs ABL would have to be produced by ROCKNIX or by someone with that
toolchain — a third-party dependency, not something this project can resolve
alone.

Path A remains the one this project can pursue unilaterally, and the G2's
unlocked bootloader plus `uefi_a`/`uefi_b`/`uefivarstore` partitions make it
plausible. It is still unverified.

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

- Vendor-source check: **resolved** — found on GitHub, not CodeLinaro
  (`docs/g2-cliffs-vendor-source-found-20260914.md`).
- pocknix: read, and it reframes the project — see §3.
- Armada: **read** at `armada-os/armada`. Its OS runs from the microSD card with
  Android intact — a working instance of this project's goal — reached via a
  one-time, reversible 258 KiB ABL swap that the project's current rules forbid.
  Two candidate boot paths for the G2 are set out in §2b; choosing between them
  is a decision for the project owner.
