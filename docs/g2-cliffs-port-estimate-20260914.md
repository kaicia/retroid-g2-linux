# How big is a Cliffs SoC port? — estimate, 2026-09-14

Measured against the device tree archived on 2026-09-14 (4015 nodes, 22697
properties) and against upstream `milos`, whose drivers are the closest
structural analogue.

## 0. First, the identity question is now closed

The CPU complex ends the argument. ARM part numbers from `/proc/cpuinfo`
(implementer 0x41):

| | G2 / Cliffs | upstream milos |
|---|---|---|
| cores | 3× **Cortex-A520** (`0xd80`), 4× **Cortex-A720** (`0xd81`), 1× **Cortex-X4** (`0xd82`) | 4× A520, 4× A720 |
| clusters | 3 (`cpu-map` cluster0/1/2) | 2 |
| max clock | 1.90 / 2.61 / 2.80 GHz | — |

Different core counts, a different cluster count, and an X4 prime core that
milos does not have at all. Core composition cannot vary within one die. Cliffs
is its own SoC, and `milos.dtsi` is a reference, not a base.

## 1. What the DT gives us, and what it does not

This is the crux of the whole estimate.

The archived device tree contains **board wiring**: which pins, which
interrupts, which stream IDs, which clock *indices* each device uses. All of
that is now in the repository and needs no further device access.

It does **not** contain the **driver data tables**, which live in `.c` files:

| Missing | Where it lives | Size in upstream milos |
|---|---|---|
| clock tree — parents, RCGs, dividers, frequency tables | `gcc-milos.c` | 3224 lines |
| pin/function mux map | `pinctrl-milos.c` | 1336 lines |
| NoC node topology, links, QoS | `milos.c` (interconnect) | 1919 lines |
| display / GPU / camera / video clock trees | `dispcc`/`gpucc`/`camcc`/`videocc-milos.c` | 970 / 561 / 2167 / 402 |

A device tree tells you a device uses `<&gcc 75>`. It never tells you what clock
75 *is*. That data cannot be derived from our dump at any level of effort.

### So the estimate forks on one question

The G2 runs Android Common Kernel `6.1.115-android14-11` with Cliffs support as
loadable vendor modules: `gcc_cliffs`, `pinctrl_cliffs`, `qnoc_cliffs`,
`camcc_cliffs`, `gpucc_cliffs`, `debugcc_cliffs`. Clock, pinctrl and interconnect
drivers are GPL, so their source should be published — Qualcomm's usual host is
CodeLinaro (`git.codelinaro.org`, `clo/la/kernel/msm-6.1`).

**I could not verify this from here** — the session's proxy cannot reach
CodeLinaro (connection fails, not a 404). Checking it from any browser is the
single highest-value next action, because:

- **source available** → porting is mechanical table translation. Large, tedious,
  well-trodden; this is exactly what mainline SoC enablement normally is.
- **source not available** → the tables must be reverse-engineered from register
  dumps. For a clock tree and a NoC topology that is not a realistic hobby
  project.

Everything below assumes the source is available.

## 2. Scale indicators measured from the dump

| | Count |
|---|---|
| distinct `compatible` strings in the G2 DT | 361 |
| of those, `qcom,cliffs-*` (need Cliffs-specific driver data) | **39** |
| distinct GCC clock indices actually referenced | 59 (range 0–138) |
| nodes consuming a GCC clock | 69 |
| TLMM pin-state groups | 436 |
| distinct GPIOs referenced (max `gpio177`) | 91 |
| regulator nodes | 71 |
| interconnect providers | 12 |

The 322 non-Cliffs compatibles are generic Qualcomm or standard bindings
(`qcom,geni-debug-uart`, `arm,mmu-500`, `operating-points-v2`, …) — largely
already supported upstream. The Cliffs-specific 39 are the work.

## 3. Tiered estimate

### Tier 0 — first kernel log. Surprisingly cheap.

Needs only: `cpus` + `cpu-map`, `memory`, GIC, arch timer, PSCI, `reserved-memory`,
`chosen` with `stdout-path`, and the UART node.

**Cliffs driver work: plausibly none.** `earlycon` writes UART MMIO directly; the
firmware has already muxed gpio22/23 and left the clock running for its own log.
No GCC driver, no pinctrl driver, no interconnect driver is required to print.

Deliverable: one minimal `cliffs.dtsi` of roughly 200–400 lines, most of it
mechanically transcribed from the archived DT.

This is the cheapest meaningful milestone in the whole project and it is
reachable now.

### Tier 1 — the kernel stays alive

Needs `gcc-cliffs` (the big one), `pinctrl-cliffs`, PDC, RPMh, cpufreq.

| Deliverable | Proxy size | Notes |
|---|---|---|
| `gcc-cliffs.c` | ~3200 lines | ≥139 clock IDs; the single largest item |
| `pinctrl-cliffs.c` | ~1350 lines | ≥178 GPIOs; table is regular, mostly transcription |
| PDC / RPMh / cpufreq glue | small | upstream drivers exist, need Cliffs data |
| `cliffs.dtsi` grown out | ~1500–2500 lines | milos.dtsi is 3574 for comparison |

### Tier 2 — SD card actually works

Needs the interconnect provider (`qnoc-cliffs`, ~1900 lines by the milos proxy,
12 providers), `apps_smmu` (generic `arm,mmu-500` — free), the SDHCI node (already
written and compiling), and the PMXR2230 regulator description (71 regulator
nodes in the DT; the PMIC binding itself is the work).

Everything the project has done on SDCC2 so far — IRQs, stream ID, pins, OPP,
DLL/DDR — is already correct and verified. That part is done.

### Tier 3 — usable handheld

Display (`dispcc-cliffs` ~970 lines + the `g1548` 1080×1920 DSI panel driver),
GPU (`gpucc-cliffs` ~560 lines + Adreno support + Mesa), USB, input, audio,
Wi-Fi/Bluetooth, thermal, power. Each is its own sub-project.

### Tier 4 — SteamOS userspace

Out of scope for this estimate; it only starts after Tier 3.

## 4. Honest summary

| Milestone | Cliffs-specific code | Feasibility |
|---|---|---|
| Tier 0 — kernel log | ~0 lines (DTSI only) | **reachable now** |
| Tier 1 — kernel alive | ~4500–5000 lines | tractable if vendor source exists |
| Tier 2 — SD works | +~2000 lines | tractable |
| Tier 3 — usable device | +~2000 lines of clock data, plus panel/GPU/USB/audio | a long project |
| Tier 4 — SteamOS | userspace | after Tier 3 |

Roughly **7000–9000 lines of Cliffs-specific driver data** to reach a device that
boots Linux from SD with working storage — most of it transcription from vendor
source rather than original design, but transcription that has to be exactly
right.

For scale: that is a normal mainline SoC enablement effort, the kind that
usually takes a small team months, or one determined person considerably longer.
It is not a weekend, and it is not impossible.

## 5. Recommended sequencing

1. **Verify vendor source availability at CodeLinaro.** One browser check. It
   decides whether Tiers 1–3 are tractable at all, and nothing else should be
   committed to before it is answered.
2. **Do Tier 0 regardless.** It is cheap, needs no vendor source, and a first
   kernel log would be the project's first real device milestone. It also
   validates the UART console assumption, which everything later depends on.
3. Only then decide whether to commit to Tier 1.

## 6. What does not need redoing

The archived device tree answers future DT questions offline. SDCC2 is fully
characterised and its DTS compiles. The console path is identified. The
bootloader is unlocked and UEFI-based with no internal ESP. None of that work is
invalidated by the Cliffs/milos finding — only the assumption that `milos.dtsi`
could serve as the base.
