# holodor deep-dive — the build system, and the exact recipe to add the G2 (2026-09-29)

Read from a fresh clone of `github.com/transentient/holodor` (Makefile,
`scripts/*.sh`, `config/pocknix.conf`, `devices/*/profile.conf`,
`kernel/*/kernel.conf`, `packages/pocknix-bootloader-sm8250/`). This is the
"go deep on holodor first" deliverable; it defines the two follow-on tasks
(Path A re-verify, then the sm8635 kernel).

**One-line takeaway:** holodor is a *thin, per-SoC generator* on top of ROCKNIX.
Adding the G2 = add one `sm8635` family (a handful of config files + a synced
ROCKNIX kernel). The only two hard blockers are the same "sm8635 is newer than
upstream" gaps we already know: **(1)** ROCKNIX has no sm8635 kernel to sync,
**(2)** the bootloader choice. Everything else is scaffolding the system does
for us.

## What holodor actually is

- A **fork of `shuuri-labs/pocknix-os`** (our stated "go like pocknix" target)
  that swaps the rootfs from plain Arch-ARM (ALARM) to **Valve's Holo Core**
  aarch64 preview — i.e. the *real* official ARM SteamOS userland. So "pocknix"
  and "real SteamOS ARM" are literally the **same build system**, differing only
  in `ROOTFS_FLAVOR` (`holo` vs `alarm`).
- Boots to **Steam Big Picture / gamescope**, FEX + Proton for x86 games, keeps
  **Android bootable**, runs **from SD** with optional install to internal.
- Kernel = **ROCKNIX kernel**, vendored per-SoC. Bootloader = one of two modes
  (below). Rootfs = Holo Core, fetched as a tarball.

## Build-system architecture (Makefile → scripts)

| `make` target | Script | What it does |
|---|---|---|
| `sync` | `sync.sh` | **Vendor ROCKNIX** kernel + device integration into `kernel/<soc>/` for the selected DEVICE's SoC |
| `bootstrap` | `bootstrap.sh` | Download + verify + extract the base rootfs (Holo Core `.zst`, or ALARM) |
| `kernel` | `build-kernel.sh` | Build `linux-pocknix-<soc>` (raw `Image` + modules + dtbs) |
| `packages` | `build-packages.sh` | Build local `pocknix-*` pkgs → `build/localrepo` (bsp, device meta, **bootloader**) |
| `build` | `build-image.sh` | bootstrap → packages → assemble rootfs (needs `make kernel` first) |
| `sd-image` | `build-sd-image.sh` | Assemble a flashable **SD boot-test image** |
| `install` | `install.sh` | Install to internal storage, **preserving ABL** (on-device, Phase 6) |
| `publish` / `publish-image` | | Sign+publish the update repo / compress+upload the SD image |
| `check` / `du` / `trim` / `clean` | | Preflight, disk usage, reclaim space |

Everything keys off one env var **`DEVICE`** → `SOC` → `kernel/${SOC}/` +
`vendor/rocknix-${SOC}/` + `devices/${SOC}/`.

### `sync.sh` — how a ROCKNIX kernel becomes `kernel/<soc>/`

It rsyncs from a local ROCKNIX checkout (`ROCKNIX_PROJECT_DIR`, device dir =
`${ROCKNIX_PROJECT_DIR}/devices/${ROCKNIX_SOC}`) into `kernel/<soc>/`:

- `patches/10-mainline/` ← ROCKNIX `packages/linux/patches/mainline/`
- `patches/20-<soc>/`     ← ROCKNIX `devices/<SOC>/patches/linux/`  ← **SoC-specific**
- `patches/30-version/`   ← ROCKNIX `packages/linux/patches/<ver>/`
- `dts/`                  ← ROCKNIX `devices/<SOC>/linux/dts/` (may be empty; DTS can live in the patch stack)
- `config/linux.aarch64.conf`, `config/kernel-firmware.dat`
- `bootloader/`          ← ROCKNIX `devices/<SOC>/bootloader/`
- `filesystem/` (firmware overlay) and select ROCKNIX packages

**This is the wall for the G2:** `sync.sh` needs a ROCKNIX `devices/SM8635` dir.
ROCKNIX ships SM8250 / SM8550 / SM8650 / SM8750 — **no SM8635**. No amount of
holodor scaffolding fills this; it is our Cliffs kernel-port work
(`g2-cliffs-port-estimate`, DTS). Concretely, our output must become a
`kernel/sm8635/` (patch stack + dts + `linux.aarch64.conf`).

### rootfs source (Holo Core)

`config/pocknix.conf`:
```
ROOTFS_FLAVOR      = holo   (holodor default; set 'alarm' to fall back to Arch-ARM)
HOLO_MIRROR        = https://holo-packages.steamos.cloud/holo-core-aarch64-preview/mash-20251118.3
HOLO_TARBALL       = system.rootfs.zst
HOLO_ROOTFS_SHA256 = 7e3fb88454e1ac633b7488abb72d3ca0cc7d2578a38146fdd7d58b50fcbd60bf
MKBOOTIMG pinned   @ android.googlesource.com …d2bb0af5 (for boot.img assembly)
```
So the SteamOS-ARM userland is a **single pinned tarball download** — no build.
That is the whole "real SteamOS" half, and it is SoC-independent.

## The two BOOTLOADER modes (the crux for the G2)

`devices/<soc>/profile.conf` sets `BOOTLOADER` to exactly one of:

### `arm-efi` — used by **sm8250 (Retroid Pocket 5 / Flip 2)** = our Path A
- **Factory ABL is kept.** pocknix flashes **no** bootloader to internal.
- Factory ABL chainloads `\EFI\BOOT\bootaa64.efi` (GRUB) **off the SD's FAT
  partition**, GRUB reads `grub.cfg`, then `linux /KERNEL` (raw `Image`) +
  `devicetree /boot/grub/<board>.dtb`.
- `build-sd-image.sh :: populate_arm_efi_boot()` rsyncs, from the rootfs
  `/usr/share/pocknix/bootloader`, the `EFI/` + `boot/` trees onto the FAT
  partition, then copies `${KOUT}/dtbs/*.dtb` into `boot/grub/`. It **dies** if
  `EFI/BOOT/bootaa64.efi` or `boot/grub/grub.cfg` is missing.
- The GRUB binary ships in `packages/pocknix-bootloader-sm8250/` (`bootaa64.efi`,
  GRUB 2.14-rc1 `arm64-efi`, from the ROCKNIX-SM8250 release; rebuildable with
  `grub-mkimage -O arm64-efi -p /boot/grub …`).

### `qcom-abl` — used by **sm8550 (Odin 2 / RP6)** and **sm8750 (Odin 3)** = Path B
- Flashes the **ROCKNIX-ABL** `abl_signed-<SOC>.elf` to `abl_a`/`abl_b`.
- `populate_qcom_abl_boot()` copies the `rocknix_abl/` folder (signed ELF +
  Android-side flash/restore scripts) from the rootfs
  `/usr/share/bootloader/rocknix_abl` onto the SD FAT, so the user flashes it
  from Android. **Required on sm8750; only warned on sm8550** (its ABL predates
  the folder).
- Reminder from the ABL investigation: **ROCKNIX/LinuxLoader (the ABL source) is
  PRIVATE.** qcom-abl for a new SoC means ROCKNIX builds it, or we build a DIY
  ABL from Qualcomm edk2. This is why qcom-abl is the heavier path.

**Both modes share the SD layout** (`build-sd-image.sh`):
```
GPT  p1  fat32  name "<SD_BOOT_PARTNAME>"  label "<SD_FAT_LABEL>"  -> /KERNEL [+ EFI/ boot/  |  rocknix_abl/]
     p2  ext4   name "<ROOT_LABEL>"                                -> rootfs
parted set 1 legacy_boot on      # BOTH styles; NO esp flag
Deterministic PARTUUIDs (sgdisk):
  p1 SD_BOOT_PARTUUID = 706f636b-6e69-7830-626f-6f7400000001
  p2 SD_ROOT_PARTUUID = 706f636b-6e69-7830-726f-6f7400000002   (kernel root= is pinned to this)
```
Note: ROCKNIX/pocknix mark p1 `legacy_boot`, **not** the EFI `esp` flag, and the
kernel finds root **by PARTUUID**, not by label.

## The exact recipe to add an `sm8635` family

Mechanically (from `devices/README.md` + the sm8250/sm8550 trees):
```
devices/sm8635/profile.conf              # SOC=sm8635, BOOTLOADER=<arm-efi|qcom-abl>,
                                         #   SD labels, KERNEL_CMDLINE, pkg names
devices/sm8635/packages.list
devices/sm8635/packages/pocknix-bsp-sm8635/     # boards/<board>.conf (dt-model gated),
                                         #   input maps, audio UCM, udev, cpuidle
devices/sm8635/packages/pocknix-device-sm8635/  # metapackage
devices/sm8635/packages/pocknix-bootloader-sm8635/  # arm-efi: our own bootaa64.efi+grub.cfg
                                         #   OR qcom-abl: abl_signed-SM8635.elf (needs source)
kernel/sm8635/  (via `make sync`)        # kernel.conf + config/ patches/ dts/ bootloader/
config/tuning/sm8635.conf                # -march/-mtune, FEX TUNE_CPU
```
`kernel/<soc>/kernel.conf` pins e.g. `KERNEL_VERSION=7.1.2`,
`ROCKNIX_VERSION_PATCH_DIR=7.0`, `ROCKNIX_SOC=SM8550`. For sm8635 the
`ROCKNIX_SOC` must point at a ROCKNIX device dir that **doesn't exist yet** — so
this file is a stub until the Cliffs kernel port produces the patch stack/dts to
drop into `kernel/sm8635/` directly (bypassing `sync` against upstream ROCKNIX).

## Impact on our roadmap

1. **arm-efi (Path A) is a first-class, production pocknix path** — the RP5 uses
   it, factory ABL untouched, no private source, no ABL flash. If the **G2
   factory ABL can EFI-boot removable media**, this is the self-sufficient route
   and sidesteps the private-LinuxLoader blocker entirely. Our
   `g2-path-a-closed-20260915.md` said the factory ABL wouldn't boot removable
   EFI — but that predates understanding the exact contract above (GRUB
   `bootaa64.efi` on a FAT p1 marked `legacy_boot`, kernel by PARTUUID). **This
   is task 2: re-verify Path A against the precise arm-efi contract.**
2. **The kernel is required either way** (`kernel/sm8635/`), and is the long
   pole. **This is task 1**, after Path A.
3. The SteamOS-ARM userland is a solved, SoC-independent tarball; not on our
   critical path.

## The Path A re-verification test (defines task 2)

Replicate the arm-efi contract on an SD card and see if the G2's **factory** ABL
chainloads it — read-only to internal, fully EDL-recoverable:

1. SD GPT: p1 FAT32 `name="system"`, set `legacy_boot on` (no esp); p2 ext4.
2. p1: `\EFI\BOOT\bootaa64.efi` (a GRUB `arm64-efi` image, `-p /boot/grub`) +
   `\boot\grub\grub.cfg` with a trivial entry (`search --set -f /KERNEL; linux
   /KERNEL …; devicetree …`) or even just a GRUB that shows its menu/console.
3. Put a placeholder `/KERNEL` (or a known-good aarch64 `Image`) + a dtb.
4. Boot with SD inserted; observe whether the factory ABL hands off to GRUB.

Success at **any** stage (ABL → GRUB console visible) reopens Path A. Only if the
factory ABL provably ignores SD EFI does Path B (ROCKNIX-ABL / DIY ABL) become
mandatory. Either way, nothing is written to internal, and the abl_a/abl_b +
factory backup + proven EDL 9008 recovery cover a mistake.

## Sources
- `github.com/transentient/holodor` — Makefile; scripts/{sync,build-sd-image,
  build-kernel,build-packages,build-image,install,lib}.sh; config/pocknix.conf;
  devices/{sm8250,sm8550,sm8750}/profile.conf + devices/README.md;
  kernel/{sm8250,sm8550,sm8750}/kernel.conf; packages/pocknix-bootloader-sm8250/
  (bootaa64.efi + grub.cfg).
- `github.com/shuuri-labs/pocknix-os` (holodor's upstream).
- Prior repo docs: g2-steamos-arm-and-abl-investigation-20260928,
  g2-boot-strategy-rocknix-abl-20260928, g2-path-a-closed-20260915,
  g2-reference-projects-review-20260914, g2-cliffs-vendor-source-found-20260914.
