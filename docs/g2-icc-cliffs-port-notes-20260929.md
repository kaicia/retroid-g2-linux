# Tier 2 port notes — interconnect (NoC) driver (cliffs → icc-sm8635) — 2026-09-29

Third driver, first Tier 2 item: the **interconnect / NoC (Network-on-Chip)**
bandwidth-voting driver. Required for SD storage and anything that needs
guaranteed bus bandwidth (once devices vote for it via the DT `interconnects`
property).

## Source → output
| | |
|---|---|
| Source | `MiCode/Xiaomi_Kernel_OpenSource` `drivers/interconnect/qcom/cliffs.c` |
| Pinned commit | `062233df735dd3db2e20aea2f7d3f87c0b1ffde2` (branch `peridot-u-oss`) |
| Source sha256 | `9e52a5610a8a2837d6308d173724745fbf119c1e812588fc52b9588f5a0ac02b` |
| Source lines | 3054 |
| Output | `kernel/sm8635/patches/20-sm8635/drivers/interconnect/qcom/icc-sm8635.c` (2323 lines) |
| Header (unmodified) | `.../include/dt-bindings/interconnect/qcom,cliffs.h` (GPL-2.0, 179 lines, 169 IDs, sha `18cd161d…`) |
| Transform script | `.../port_icc.py` (deterministic, reproducible) |

## The port decision — strip the downstream QoS/multi-voter layer

The downstream driver is a mainline-style **icc-rpmh** driver *extended* with two
things mainline icc-rpmh does not carry:

1. **Direct QoS-box programming** — via `#include "qnoc-qos.h"`, 32
   `qcom_icc_qosbox` structs, `.noc_ops`/`.qosbox` node fields, an
   `icc_regmap_config`, and `.config` on every desc. Mainline sm8550/sm8650
   icc-rpmh leaves NoC QoS to RPMh firmware and programs no QoS registers.
2. **Multi-voter support** — `VOTER_IDX_*` enum, per-desc `*_voters[]` arrays,
   `.voters`/`.num_voters` desc fields, `.voter_idx` on BCMs. Mainline uses a
   single `bcm_voter` per NoC (`of_bcm_voter_get`), not a per-desc voter list.

Both layers depend on downstream-only headers/struct members, so they cannot
compile against mainline and were **removed together**, yielding the clean
mainline icc-rpmh shape. This is the correct call for bring-up: the **bandwidth
topology (nodes, links, BCMs) and RPMh voting are fully preserved** — that is
what makes SD/UFS/USB bandwidth requests work. QoS *priority tuning* is a
performance refinement, deferred (re-addable if the target kernel's icc-rpmh
gains QoS-box support, which some mainline SoCs now have).

### Removed
| Removed | Count |
|---|---|
| `#include "qnoc-qos.h"` | 1 |
| `VOTER_IDX` enum + `*_voters[]` arrays + `.voters`/`.num_voters` desc fields | 1 + 14 + 28 |
| `icc_regmap_config` + `.config = &icc_regmap_config` desc field | 1 + 14 |
| `qcom_icc_qosbox` structs + `.qosbox` node fields | 32 + 32 |
| `.noc_ops` node fields | 169 |
| `.voter_idx` bcm fields | 46 |
| `.perf_mode_mask` bcm fields | 2 |

### Kept intact
All **183 `qcom_icc_node`s** (name/id/channels/buswidth/links), **60
`qcom_icc_bcm`s** (name/`enable_mask`/nodes), the **14 per-NoC** node+bcm arrays
and descs, and the already-mainline probe
(`qcom_icc_rpmh_probe`/`_remove`/`_sync_state`, `core_initcall`). Compatibles
renamed to mainline convention: `qcom,cliffs-<noc>` → **`qcom,sm8635-<noc>`**
with hyphens (e.g. `qcom,sm8635-aggre1-noc`, `qcom,sm8635-mc-virt`).

## Verification performed (offline)
- Brace balance 0, paren balance 0.
- Counts preserved: 183 nodes, 60 BCMs, 14 descs, 14 of_match compatibles, 18
  `.enable_mask`.
- Zero residual downstream tokens (`qnoc-qos.h`, `qcom_icc_qosbox`, `.qosbox`,
  `.noc_ops`, `voter_idx`, `_voters`, `icc_regmap_config`, `perf_mode_mask`,
  `qos_config`, `qcom,cliffs-` all → 0).
- Probe/remove/sync_state are all mainline icc-rpmh symbols.
- Header coverage: every `MASTER_*`/`SLAVE_*` ID used by the driver (169) is
  defined in `qcom,cliffs.h`.

**Not yet done:** compile against mainline 7.1.2. Register/topology values
trusted from vendor source (cross-checked against the G2 DT interconnect IDs,
`g2-cliffs-vendor-source-found-20260914.md`).

## Integration TODO (at holodor `make kernel` time)
1. `drivers/interconnect/qcom/Kconfig`:
   ```
   config INTERCONNECT_QCOM_SM8635
   	tristate "Qualcomm SM8635 interconnect driver"
   	depends on INTERCONNECT_QCOM_RPMH
   	select INTERCONNECT_QCOM_BCM_VOTER
   	help
   	  This is a driver for the Qualcomm Network-on-Chip on SM8635 (Cliffs).
   ```
2. `drivers/interconnect/qcom/Makefile`:
   ```
   icc-sm8635-objs := icc-sm8635.o
   obj-$(CONFIG_INTERCONNECT_QCOM_SM8635) += icc-sm8635.o
   ```
   (or `qnoc-sm8635-objs`; keep the single-file object name consistent.)
3. defconfig: `CONFIG_INTERCONNECT_QCOM_SM8635=y`, plus
   `CONFIG_INTERCONNECT_QCOM_RPMH=y`, `CONFIG_INTERCONNECT_QCOM_BCM_VOTER=y`.
4. DTS: one node per NoC provider (14), e.g.
   ```
   clk_virt: interconnect-0 {
       compatible = "qcom,sm8635-clk-virt";
       #interconnect-cells = <2>;
       qcom,bcm-voters = <&apps_bcm_voter>;
   };
   ```
   plus `&apps_bcm_voter` (rpmh) and the `interconnects`/`interconnect-names`
   on each consumer (SDCC2, UFS, USB, …). Only the NoCs a consumer touches are
   needed for a given tier — for Tier 2 storage, the ones on the SDCC2/UFS path.
5. Turn into a formal `.patch` once applied to a checked-out 7.1.2 tree.

## Status
- Tier 1: GCC ✓, TLMM pinctrl ✓ (C ports done; PDC/RPMh/cpufreq are DT-only).
- Tier 2: interconnect ✓ (this). Remaining Tier 2: the SDCC2 DT node (already
  characterised — see the SDCC2 work) + the PMXR2230 regulators, then wire the
  gcc/tlmm/icc providers into `dts/cliffs.dtsi` so SD storage probes.
