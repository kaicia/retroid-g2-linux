# SteamOS-ARM + ROCKNIX-ABL investigation — 2026-09-28

Three tasks, all read from primary sources (repos cloned through the proxy;
web/CLO where noted): ① ROCKNIX-ABL internals, ② the Cliffs ABL base source,
③ Valve's official ARM SteamOS and its handheld ports (the Odin 3 case). The
result reshapes the roadmap: our end goal (pocknix-style) and "real SteamOS"
converge on one build system, and the boot decision has a new hard fact.

## ① ROCKNIX-ABL — the buildable source is PRIVATE

`github.com/ROCKNIX/abl` (public) is **only a release wrapper**: `README.md` +
`update.sh` + one workflow. `update.sh` flashes a **prebuilt per-device**
`abl_signed-${HW_DEVICE}.elf` to `abl_a`/`abl_b`.

The actual build (`.github/workflows/release-abl.yaml`) checks out
**`ROCKNIX/LinuxLoader` with an SSH deploy-key secret** and runs `./make_abl.sh
all` → `Output/abl_signed-<device>.elf`. Verified `ROCKNIX/LinuxLoader` is
**private** (anonymous clone prompts for credentials; raw returns 404 on
master+main; public `abl` returns 200).

**Consequences**
- We cannot fork/extend ROCKNIX-ABL source to add a Cliffs target — it isn't public.
- ROCKNIX-ABL is per-device (device name, not just SoC), built by their CI.
- Getting ROCKNIX-ABL on the G2 therefore means either (a) ROCKNIX adds a G2
  build (community ask; they need G2 specifics + a tester), or (b) we build an
  equivalent ourselves from Qualcomm's public ABL (see ②) and reimplement the
  Linux-boot layer LinuxLoader provides.

## ② The Cliffs ABL base source is obtainable (edk2 / QcomModulePkg)

Our `g2-abl-source-findings.md` was read from Qualcomm's public **QcomModulePkg
(edk2 ABL)**. Qualcomm's **Pineapple EDK2** history (incl. the `GetActiveSlot`
UFS-boot-LUN logic this device uses) is on CodeLinaro, with GitHub mirrors — the
same lineage route that produced `g2-cliffs-vendor-source-found-20260914.md` for
the kernel. So the **base** ABL for Cliffs/palawan is gettable; the part that is
*not* public is ROCKNIX's Linux-boot loader on top. A DIY ABL is thus feasible in
principle (secure boot is OFF, so unsigned runs) but is real bootloader work.

## ③ Valve's official ARM SteamOS is real — and already ported to Snapdragon

Valve shipped **SteamOS on ARM** with the **Steam Frame** (Qualcomm SD 8 Gen 3),
using **FEX** (open-source x86→ARM translation) + **Proton** + a native ARM64
Steam client ("Holo Core" = the official ARM64 SteamOS userland). Community
projects put that userland on Snapdragon handhelds:

| Project | Target | Notes |
|---|---|---|
| **transentient/holodor** | **AYN Odin 3** | **Holo Core + ROCKNIX kernel**, fork of `pocknix-os`. THE Odin 3 case. |
| hashtagbasit/SteamOS-ARM-SM8650 | KONKR Pocket FIT / 8 Gen 3 | "official SteamOS ARM (Steam Frame build)" |
| hashtagbasit/SteamOS-ARM-Handhelds | + AYANEO Pocket S2/S2 Pro | multi-device |
| MaSieS4Fun/SteamOS-ARM-SM8550 | SM8550 | official SteamOS ARM adapted to 8 Gen 2 |
| Chazmus/SteamOS-ARM-Handhelds | ARM handhelds | Steam Frame–based |
| Nova-Deck/os-build | Snapdragon | boots to Steam, Proton+FEX |

### holodor is the key reference — it unifies both our goals

`transentient/holodor` is a **fork of `pocknix-os`** (our stated target) that
swaps the plain-Arch session for **Valve's Holo Core packages**. So "go like
pocknix" and "real ARM SteamOS" are the *same build system*, just a package-set
choice. Holodor: boots to Steam Big Picture, keeps Android, FEX+Proton for x86
games, ROCKNIX kernel + **ROCKNIX bootloader**, SD-boot with optional install to
internal. Buildable (`make kernel/packages/build/sd-image`, qemu-user chroot,
~50 GB, hours). Honest caveats from their README: AAA ~20–30 fps (young GPU
driver), no kernel anti-cheat (ARM-wide), some UE5 games black-screen.

## The build system's device model = the exact recipe to add the G2

holodor/pocknix `devices/README.md` spells out how a SoC family is defined. Per
SoC there is:

```
devices/<soc>/profile.conf           # SOC, BOOTLOADER (qcom-abl | arm-efi),
                                     # SD labels, KERNEL_CMDLINE, pkg names
devices/<soc>/packages.list
devices/<soc>/packages/pocknix-bsp-<soc>/     # boards/<board>.conf, input maps
                                     # (dt-model gated), audio UCM, udev, cpuidle
devices/<soc>/packages/pocknix-device-<soc>/  # metapackage
kernel/<soc>/  kernel.conf + config/ patches/ dts/ bootloader/   # via `make sync`
config/tuning/<soc>.conf             # CPU -march/-mtune, FEX TUNE_CPU
```

**Crucial: `BOOTLOADER` is per family and is one of two:**
- **`arm-efi`** — used by **sm8250 (Retroid Pocket 5)**: factory ABL → GRUB/EFI
  from the SD ESP. **This is our Path A, and pocknix uses it in production.**
- **`qcom-abl`** — used by **sm8550 (Odin 2, RP6)** and sm8750 (Odin 3): the
  ROCKNIX-ABL swap. This is Path B.

So the pocknix/holodor system natively supports **both** boot paths; a G2
(`sm8635`) family would just set `BOOTLOADER=` accordingly.

## Synthesis — the G2 target architecture

**Goal:** an `sm8635` device family in the holodor/pocknix build system →
Holo-Core (SteamOS ARM) session, FEX+Proton, boots to Steam, Android intact.

Two hard dependencies, both are the same "sm8635 is newer than anything upstream
supports" gap we already know:

1. **ROCKNIX kernel for sm8635/Cliffs** — `kernel/sm8635/` is populated by
   `make sync` against a ROCKNIX SoC dir, but **ROCKNIX has no sm8635** (they ship
   SM8250/8550/8650/8750). This is our existing Cliffs kernel-porting work
   (`g2-cliffs-port-estimate`, DTS work). **Unavoidable for either boot path.**
2. **Bootloader for sm8635** — choose:
   - **`arm-efi` (Path A):** no ABL flash, no private source. BUT
     `g2-path-a-closed-20260915.md` recorded the G2 factory ABL not booting
     removable-media EFI. **Needs re-verification** (uefi_a/uefi_b partitions,
     ESP layout) — if it can be made to work, this is the self-sufficient route.
   - **`qcom-abl` (Path B):** ROCKNIX-ABL, best UX (boot menu, Android switch),
     but source is private → depends on ROCKNIX building an sm8635 image, or a
     DIY ABL from Qualcomm edk2 (②).

**Now-favorable safety net (either path):** abl_a/abl_b + full factory image are
backed up, EDL 9008 recovery is proven, secure boot is OFF. Flashing/experimenting
with a bootloader is reversible.

## Recommended next steps

1. **Kernel first, boot-path-agnostic.** The sm8635 ROCKNIX kernel is required
   no matter which bootloader wins, and it's the long pole. Continue the Cliffs
   kernel/DTS work; frame it as producing a `kernel/sm8635/` for this build
   system.
2. **Re-verify Path A on the G2** (cheap, unblocks self-sufficiency): can the
   factory ABL / uefi partitions boot `\EFI\BOOT\BOOTAA64.EFI` from an SD ESP?
   Re-open `g2-path-a-closed` with a proper ESP test now that we understand the
   ABL and have safe recovery.
3. **In parallel, engage ROCKNIX** about an sm8635 abl build (Path B), providing
   the G2 specifics we have (framebuffer 0xe3940000, DRAM map, UFS boot LUN a=1/b=2,
   secure:no). Community route; not blocking.
4. Stand up the holodor/pocknix build system locally and stub a `devices/sm8635/`
   from the sm8550 family as the scaffold.

## Sources
- github.com/ROCKNIX/abl (cloned: README, update.sh, release-abl.yaml → ROCKNIX/LinuxLoader private)
- github.com/transentient/holodor (cloned: README, INSTALL.md, devices/, kernel/, devices/README.md)
- github.com/shuuri-labs/pocknix-os (holodor's upstream)
- hashtagbasit/SteamOS-ARM-SM8650, -Handhelds; MaSieS4Fun/SteamOS-ARM-SM8550; Chazmus/SteamOS-ARM-Handhelds; Nova-Deck/os-build
- PC Gamer / Wikipedia (Steam Frame): Valve SteamOS-on-ARM + FEX, SD 8 Gen 3
- Prior: g2-reference-projects-review, g2-abl-source-findings, g2-cliffs-vendor-source-found,
  g2-path-a-closed, g2-boot-strategy-rocknix-abl-20260928
