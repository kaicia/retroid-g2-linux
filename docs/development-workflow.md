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

Known defect: `g2-sdhci-linux-dtc.yml` clones `torvalds/linux` with `--depth 1`
and no commit pin, so its kernel input changes between runs. This contradicts
the project's reproducible-kernel-input requirement and should be fixed before
its results are treated as a stable baseline.

## 6. Outstanding technical work

These items were defined inside the now-deleted `dispatch/` request files and
are recorded here so they are not lost.

### 6.1 Decide the provider-header domain (blocking)

The repository currently carries two incompatible numbering systems for the
same hardware:

| Symbol | Downstream `qcom,cliffs.h` (`docs/g2-cliffs-provider-mapping-progress-20260822.md`) | Upstream SM7635/Milos (`docs/g2-sdhci-linux-provider-map-20260827.md`) |
|---|---|---|
| `GCC_SDCC2_AHB_CLK` | 108 | 121 |
| `GCC_SDCC2_APPS_CLK` | 109 | 122 |
| `GCC_SDCC2_BCR` | 17 | 20 |
| `MASTER_SDCC_2` | 47 | 8 |
| `SLAVE_SDCC_2` | 542 | 20 |
| `SLAVE_EBI1` | 512 | 1 |

Both sets are correct within their own header. The DTS fragments in `dts/` use
symbolic names, so the question is which header the selected kernel tree
provides. The retired G2-C-0002 dispatch request asked for upstream-Linux
compatibility while quoting the downstream numbers; that conflict must be
resolved before any further interconnect work.

### 6.2 Compile the G2 candidate DTB

Previously specified in `docs/archive/automation/deepseek-compile-task-20260827.md`
and never executed:

1. Build the baseline `arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb`.
2. Install `dts/g2-sdhci-milos-merge.dtsi` into the QCOM DTS directory.
3. Create a compile-test DTS including `milos.dtsi`, `pm7550.dtsi`, and the G2
   fragment.
4. Compile it and record the exact first error if it fails.

### 6.3 Choose the SDHCI driver path

`docs/g2-sdhci-driver-compatibility-20260827.md` leaves the choice between the
upstream `qcom,milos-sdhci` driver, the pocknix downstream SDHCI driver, and a
hybrid kernel unresolved. Its recommended order is to produce both compile
candidates and compare them.

### 6.4 Close out G2-C-0002

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
