# Development Workflow

Status: active as of 2026-09-12. Replaces the retired ChatGPT → GitHub →
OpenCode → DeepSeek automation loop (see `docs/archive/README.md`).

## 1. Execution model

Development is performed by a coding agent (Claude Code) working directly on
this repository: it reads the repository, makes changes, commits, and pushes to
a branch. There is no dispatch bridge, no `dispatch/request.json` handshake, no
external model-routing policy, and no `/oc` comment trigger.

Consequences of the change:

- A task is a request in conversation, not a JSON request file.
- Work is verified by reading the actual diff, the actual CI result, and the
  actual branch — not by correlating run/job/trace identifiers.
- There is no waiting period between dispatching a task and discovering whether
  a backend accepted it.

## 2. Task cycle

1. Inspect the current repository state and the open technical blockers.
2. Agree on exactly one concrete task.
3. The agent implements it on a working branch.
4. The agent runs the repository's own validation locally where possible.
5. Push the branch. Open a PR only when one is explicitly requested.
6. Review the diff and CI result before the task is treated as done.

One task at a time remains the rule. It is carried over from the retired loop
because it was a project preference, not an automation constraint.

## 3. Evidence rules carried forward

These survive the retirement of the automation loop and still apply:

- Unknown values stay explicitly unknown until a source or hardware observation
  supports them. Do not fill a gap with a plausible number.
- G2 ADB dumps in `dumps/g2/` are the hardware source of truth.
- Exact Cliffs/SM7635 evidence takes precedence over commercial Snapdragon
  marketing labels.
- RP5/RP6/Odin/ROCKNIX/pocknix/Armada are references and precedents. They are
  not permission to copy unrelated numeric IDs (IRQs, GPIOs, regulator IDs,
  interconnect IDs, QoS masks).
- Never present an earlier result as the outcome of a later request. This was
  the lesson of the 2026-08-28 stale-receipt incident and it is independent of
  which backend runs the work.
- Decisions and findings are committed to this repository, not left in chat.

## 4. Device safety rules (unchanged)

The project target is microSD-only Linux/SteamOS with the stock Android boot
path preserved.

- No internal Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo/firmware
  modification.
- No flashing, erasing, repartitioning, or reformatting of internal storage.
- Build-side validation comes before any physical G2 test.
- Removing the microSD card must leave stock Android booting normally.

## 5. Continuous integration

Two workflows remain and are unrelated to the retired dispatch machinery:

| Workflow | Trigger | Purpose |
|---|---|---|
| `.github/workflows/g2-sdhci-static.yml` | changes to the G2 DTS fragments or the validator | runs `scripts/validate-g2-sdhci-provider-map.py` and structural smoke checks |
| `.github/workflows/g2-sdhci-linux-dtc.yml` | changes to `dts/g2-sdhci-milos-merge.dtsi` or the provider map | builds a known-good Milos DTB, then compiles the G2 candidate fragment |

Both are driven by `scripts/build-g2-dtb-compile-candidate.sh`, which pins the
upstream kernel revision. The pin matters: the G2 candidate exists precisely to
disagree with upstream `milos` on IRQs, SMMU stream ID and pin map, so an
unpinned tree would silently change what the build is compared against.

## 6. Outstanding technical work

These items were defined inside the now-deleted `dispatch/` request files and
are recorded here so they are not lost.

### 6.1 Decide the provider-header domain — RESOLVED 2026-09-12

Settled in `docs/g2-provider-domain-decision-20260912.md`: target upstream Linux
`milos` symbols exclusively; downstream `cliffs` IDs are vendor-topology evidence
only and must never appear in an upstream DTS. Two hardware conflicts were found
while resolving it and remain open — SMMU stream ID (`0x140` per the G2 dump vs
`0x540` upstream) and SDCC2 IRQs (207/223 vs 204/125). Both are recorded as
bring-up blockers, and the SMMU one is answered by the consolidated hardware dump
(`docs/g2-hardware-dump-plan-20260912.md`, section B5).

### 6.2 Compile the G2 candidate DTB — DONE 2026-09-12

`dts/g2-sdhci-compile-test.dts` builds against pinned Linux
`5225b8eec4c9bb21aecff6295fab6346a3c3738e` and passes DT schema validation apart
from the unregistered board compatible. Reproduce with
`scripts/build-g2-dtb-compile-candidate.sh`; results and the four known runtime
risks are in `docs/g2-dtb-compile-result-20260912.md`. The `g2-sdhci-linux-dtc`
workflow now pins the kernel revision, closing the reproducibility defect noted
in §5.

### 6.3 Decide whether to write a Cliffs SoC description (largest open question)

Upstream has no Cliffs support of any kind. The 2026-09-14 dump showed the G2
differs from upstream `milos` in every fixed-silicon ID space checked —
interrupts, pin map, SMMU stream — so treating `milos.dtsi` as the SoC base means
overriding essentially all of it. Writing a Cliffs SoC DTSI and pinctrl driver is
now the honest path, and it is substantially more work than the roadmap assumed.
This should be decided explicitly rather than drifted into; see
`docs/g2-dump-findings-20260914.md` §1 and the sizing in
`docs/g2-cliffs-port-estimate-20260914.md`.

The first gate is now cleared: Qualcomm's Cliffs source **is** published, GPL,
and verified as this SoC's — `docs/g2-cliffs-vendor-source-found-20260914.md`.
The driver port is adaptation of existing source, not reverse-engineering. What
remains is the decision to commit to it, with real sizes in hand (8566 lines
across the three core drivers). Second, **Tier 0 is worth doing either way**: a first kernel log needs a minimal DTSI and no Cliffs driver code,
because earlycon writes MMIO directly and the firmware has already set up the
UART.

Related and still open: the G2's PMXR2230 LDO13/LDO23 rails have no upstream
description, so the compile candidate currently has no `vmmc-supply` /
`vqmmc-supply` and cannot power the card.

### 6.3b Choose the SDHCI driver path

`docs/g2-sdhci-driver-compatibility-20260827.md` leaves the choice between the
upstream `qcom,milos-sdhci` driver, the pocknix downstream SDHCI driver, and a
hybrid kernel unresolved. The compile candidate takes the upstream path; the
downstream comparison has not been built.

### 6.4 Collect the consolidated hardware dump — DONE 2026-09-14

`docs/g2-hardware-dump-plan-20260912.md` plus
`scripts/run-g2-consolidated-hardware-dump-readonly-v2.sh` gather every
outstanding device-side fact in one read-only session, and archive the **entire**
device tree so later DT questions never need the device again. Requires physical
access to the G2; nothing else in this list does.

Collected: `dumps/g2/g2-consolidated-hardware-20260914-222623.txt` plus the full
device-tree archive (4015 nodes). Analysis in
`docs/g2-dump-findings-20260914.md`. It closed decision-doc §4.1 and §4.2 in
favour of the G2 values, and established that Cliffs is different silicon from
upstream `milos` — which makes §6.3 bigger than previously framed.

### 6.4b Choose a console channel before any boot attempt

`docs/g2-boot-console-feasibility-20260912.md` settled most of this build-side:
the bootloader is already unlocked, the boot chain is UEFI with no internal ESP,
and `chosen/stdout-path` names `serial@a94000`, which upstream already supports
as `qcom,geni-debug-uart`. Three console channels need zero new driver code;
ramoops is the fallback that needs no console at all. What remains is picking one
from the dump's section C data, plus physical inspection for UART accessibility.

A boot attempt without a chosen channel returns no information and should not
happen.

### 6.5 Close out G2-C-0002

The last dispatch (`G2-C-0002-R2`, Actions run `33161623434`, 2026-08-28) was
recorded as `dispatched` and its result was never confirmed. Several
`opencode/g2-c-0002-*` branches exist on the remote. Determine whether any
contains usable work before redoing the interconnect task.

## 7. Document precedence

1. `docs/development-workflow.md` — this document; how work is executed.
2. `docs/project-rebuild-20260825.md` — Track A technical ladder and success
   criteria.
3. `docs/development-roadmap-20260822.md` — bring-up phases and method.
4. Dated technical documents — evidence for a specific subsystem.
5. `docs/archive/` — retired mechanisms; history only, do not follow.

Documents written before 2026-08-26 that describe repository contents (notably
`docs/project-overview.md` and `docs/next-session.md`) contain stale
statements about which files exist. Trust the working tree over those
descriptions.
