# G2 consolidated hardware dump plan — 2026-09-12

Everything the port still needs from the physical device, collected in **one**
read-only ADB session instead of a script per question.

Run: `scripts/run-g2-consolidated-hardware-dump-readonly-v1.sh`
Output: `dumps/g2/g2-consolidated-hardware-<timestamp>.txt`

## How to run it

From Termux on the Galaxy S20 FE, with the G2 connected by USB and ADB
authorized:

```sh
cd ~/retroid-g2-linux
git checkout <the branch you want the dump on>
bash scripts/run-g2-consolidated-hardware-dump-readonly-v1.sh
```

The script refuses to run unless exactly one device is attached. It pushes a
collector to `/data/local/tmp`, runs it, pulls the result back, deletes the temp
files, then commits the dump and pushes it.

Preconditions it enforces before touching the device, so the dump lands as a
clean commit on the right branch:

- a branch must be checked out (not detached HEAD);
- the working tree must be clean;
- `git pull --ff-only origin <branch>` must succeed.

It commits to **whatever branch is currently checked out** — it never switches
branches and never force-pushes. Push failures retry five times with exponential
backoff (2s, 4s, 8s, 16s); if all fail the commit is still safe locally and the
script prints the manual retry command.

It also refuses to commit a dump that is empty or truncated: the collector writes
`END schema=1` as its last line, and the wrapper checks for it.

### Safety

Audited before commit: no `dd`, `mkfs`, `fastboot`, `parted`, `mount`,
`setprop` or any other write; exactly one output redirection (the dump file);
`/dev/block/` is only listed by name and existence-tested, never read. No flash,
erase, format, repartition, slot, AVB or firmware operation.

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

### C — Boot chain / SD boot feasibility

**This is the project's largest unknown and nothing in `dumps/g2/` answers it.**
The entire goal depends on the stock bootloader being able to reach removable
media without flashing anything.

Collected: all `ro.boot.*` properties, `/proc/cmdline`, partition **names**
(never contents), presence of an EFI system partition, which filesystems the
kernel knows, and the external SD block attributes.

What we are looking for is the same precedent Armada issue #155 documents for
the RP6: stock UEFI enumerating a removable SD, so an EFI/GRUB path can be
enabled without an ABL flash. If the G2's bootloader has no such path, the
project's premise needs revisiting before more DTS work.

### D — Subsystem inventory

Identity only, for phases after first boot: display panel, GPU, input devices
(the gamepad matters for a SteamOS-class target), USB, audio, Wi-Fi/Bluetooth,
power/battery/thermal, and the full vendor module list. Cheap to collect now,
and it avoids another device session later.

## After the dump lands

The script has already committed and pushed it. Then:

1. Resolve decision-doc §4.1 from section B5 — if the live SMMU group confirms
   `0x140`, the candidate fragments are already correct and the conflict closes.
2. Fill the real pinctrl states into `dts/g2-sdhci-upstream-candidate.dtsi` from
   section B2.
3. Assess SD-boot feasibility from section C before any further DTS work.
4. Answer the SoC-identity question from section A and, if confirmed, drop the
   remaining "SM7635" inference wording.

## Not covered here

The SDCC2 IRQ conflict (decision doc §4.2 — G2 DT says SPI 207/223, upstream
`milos.dtsi` says 204/125) cannot be settled by a dump. The device DT is already
the authority for the G2; the divergence only resolves when a G2 kernel actually
takes SDCC2 interrupts, or by inspecting upstream's own source for that value.
