# G2 consolidated hardware dump plan — 2026-09-12

Everything the port still needs from the physical device, collected in **one**
read-only ADB session instead of a script per question.

Run: `scripts/run-g2-consolidated-hardware-dump-readonly-v2.sh`

Two outputs:

| Artifact | Why |
|---|---|
| `dumps/g2/g2-devicetree-<stamp>.tar.gz` | **the whole** `/sys/firmware/devicetree/base` tree. With the complete DT in the repository, every future device-tree question is answerable offline and never needs the device again. This is the important one. |
| `dumps/g2/g2-consolidated-hardware-<stamp>.txt` | readable report: SoC identity, SDCC2 gaps, boot chain and console paths, subsystem inventory, kernel/proc/sys state |

Archiving the DT is a plain read — `/sys/firmware/devicetree/base` is a static
representation of the DTB. Only that subtree is archived, never all of `/sys`.

## How to run it

From Termux on the phone the G2 is plugged into. One command sets everything
up — no prior clone, no manual package installs:

```sh
pkg install -y curl
curl -fsSLO https://raw.githubusercontent.com/kaicia/retroid-g2-linux/refs/heads/claude/content-analysis-04z778/scripts/termux-bootstrap.sh
less termux-bootstrap.sh          # read it before running it
bash termux-bootstrap.sh
```

Download and read, rather than piping straight into a shell. The repository is
public, so no token is needed to fetch or clone; one is only needed to push.

Once this branch is merged, swap `refs/heads/claude/content-analysis-04z778`
for `refs/heads/main` and pass `G2_REF=main`.

`scripts/termux-bootstrap.sh` then:

1. checks it is really running under Termux;
2. installs whatever is missing (`git`, `tar`, `curl`, `fakeroot`, and `adb` if
   neither `termux-adb` nor `adb` is present);
3. clones or updates `$HOME/retroid-g2-linux` and checks out the branch;
4. refuses to continue on a dirty working tree — before the device is plugged
   in, not after;
5. asks for a git identity if none is set;
6. waits up to ~60s for exactly one authorized ADB device, explaining what
   `unauthorized` versus an empty list means;
7. runs the collector, which commits and pushes.

It is safe to re-run. Overridable: `G2_REF` (branch), `G2_REPO` (checkout path),
`G2_REMOTE` (clone URL).

### About the push credentials

The bootstrap never handles your token. It enables git's credential store, and
git itself prompts on the first push.

- The password git asks for must be a **GitHub Personal Access Token**, not your
  account password. A fine-grained token limited to `kaicia/retroid-g2-linux`
  with *Contents: read and write* is enough.
- That token is stored **in plain text** at `~/.git-credentials` on the phone.
- If that is not acceptable, use SSH instead:
  `G2_REMOTE=git@github.com:kaicia/retroid-g2-linux.git bash termux-bootstrap.sh`

### ADB access

`termux-adb` reaches USB devices without root and is what the earlier G2 dumps
were collected with; it is not in the main Termux repository, so install it
separately if you do not already have it. Plain `adb` also works when the device
is reachable some other way. The scripts detect whichever is present.

### Running the collector on its own

If the phone is already set up, the bootstrap is optional — the collector runs
standalone and does its own commit and push:

```sh
cd ~/retroid-g2-linux
git checkout <the branch you want the dump on>
bash scripts/run-g2-consolidated-hardware-dump-readonly-v2.sh
```

### Safety

Audited before commit: no `dd`, `mkfs`, `fastboot`, `parted`, `mount`,
`setprop` or any other write. The collector writes exactly two things, both on
the device's own `/data/local/tmp` and both removed afterwards: the text report
and the device-tree tarball. `/dev/block/` is only listed by name and
existence-tested, never read. No flash, erase, format, repartition, slot, AVB or
firmware operation. Both scripts pass `shellcheck` at warning level.

## What each section answers

### A — SoC identity (highest value)

**The gap:** no dump in `dumps/g2/` contains `/sys/devices/soc0`. Every claim
about which Qualcomm part the G2 carries currently rests on DT compatibles and
`ro.boot.hardware.revision` ("Qualcomm G2 Gen 2").

`docs/g2-provider-domain-decision-20260912.md` established Cliffs ≡ upstream
`milos` by address-level correspondence (all NoC provider addresses, apps_smmu,
SDCC2, UFS, and the UFS SMMU stream ID `0x60` all match). `soc0/soc_id` and
`soc0/machine` would turn that from strong inference into a fact, and would tell
us whether the G2 is the same die revision as the Fairphone FP6 that upstream
`milos` was developed against.

Also collected: `qcom,msm-id` / `qcom,board-id` / `qcom,pmic-id` from the DT
root, which is what the bootloader matches a DTB against — needed later to make
a G2 DTB the bootloader will accept.

### B — SDCC2 remaining gaps

| Item | Why |
|---|---|
| full pinctrl nodes behind `pinctrl-0`/`pinctrl-1` (phandles `0x3ac`/`0x3ad`) | to write real `sdc2_default`/`sdc2_sleep` states instead of the placeholder comments in `dts/g2-sdhci-upstream-candidate.dtsi` |
| `cd-debounce-delay-ms` value | present in the node listing but never decoded |
| PMXR2230 L13 / L23 regulator node properties | to decide whether the upstream `pm7550` labels (`vreg_l13b` / `vreg_l23b`) are electrically the same rails; currently assumed |
| live SMMU stream id (`/sys/class/iommu`, iommu_group) | **settles the 0x140 vs 0x540 conflict** — decision doc §4.1 |
| live mmc host state, `clk_summary` SDCC2 rates | confirms the OPP pair actually in use and the bus caps Android negotiates |

Some of B needs root to be fully useful (`/sys/kernel/debug/...`). The script
degrades gracefully and reports "unreadable" rather than failing.

### C — Boot chain, console, SD boot feasibility

Substantially narrowed on 2026-09-12 without the device — see
`docs/g2-boot-console-feasibility-20260912.md`. The bootloader is already
unlocked, the boot chain is UEFI with no internal ESP, and the device's own
`chosen/stdout-path` names a debug UART that upstream already supports. What
section C now collects is the data needed to *choose a console channel*:

| Item | Why |
|---|---|
| full `chosen` node | `bootargs` and `stdout-path` values, not just their paths |
| `qup_uart@a94000` node **and its pinctrl** | the G2's pin assignment for the designated console UART; the G2 TLMM map differs from upstream milos, so upstream's gpio25/26 cannot be assumed |
| every `reserved-memory` child with `reg` and `size` | `ramoops_region` (a reboot-surviving kernel log — the fallback that needs no console at all) and `splash_region` (the `simple-framebuffer` handoff candidate) |
| `/sys/fs/pstore` | whether a pstore backend is already active and readable |
| `ro.boot.*`, partition names, EFI-looking partitions, known filesystems | the reversible removable-media boot path, as in Armada issue #155 for the RP6 |

`/proc/cmdline` is permission-denied without root on this device, but
`chosen/bootargs` in the device tree carries the same information and is
readable.

### D — Subsystem inventory

For phases after first boot: display, GPU, input devices (the gamepad matters
for a SteamOS-class target), USB, audio, Wi-Fi/Bluetooth, power/battery/thermal.

The panel is already known from `chosen/bootargs` to be
`qcom,mdss_dsi_g1548_fhd_plus_60_video` — a `g1548`, FHD+, 60 Hz, DSI video-mode
panel. Section D now walks the matching DT nodes to get its timings, which the
`simple-framebuffer` console option also needs.

### E — Kernel / proc / sys state

New in v2. `/proc/interrupts` cross-checks the SDCC2 IRQ conflict (207/223 vs
upstream 204/125) against what the running kernel actually registered.
`/proc/iomem`, `/proc/devices`, `/proc/modules`, `/proc/config.gz` and a `dmesg`
attempt round out what the vendor kernel is doing, which is the reference for
what ours has to reproduce.

## After the dump lands

The script has already committed and pushed it. Then:

1. Resolve decision-doc §4.1 from section B5 — if the live SMMU group confirms
   `0x140`, the candidate fragments are already correct and the conflict closes.
2. Fill the real pinctrl states into `dts/g2-sdhci-compile-test.dts` from
   section B2.
3. Choose a console channel from section C against the ranking in
   `docs/g2-boot-console-feasibility-20260912.md` §6.
4. Answer the SoC-identity question from section A and, if confirmed, drop the
   remaining "SM7635" inference wording.
5. Keep the device-tree archive as the reference for all later DT work instead
   of collecting another targeted dump.

## Not covered here

Whether the debug UART lines are physically reachable — test pads, a header, or
the USB-C sideband pins — cannot be answered from software. That needs physical
inspection, and it is the reason ramoops is kept as the fallback channel.
