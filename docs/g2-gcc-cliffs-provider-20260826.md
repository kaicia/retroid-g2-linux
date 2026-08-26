# G2-C-0001 — Minimum Cliffs GCC clock/reset provider (patch step 0003)

Date: 2026-08-26

## Scope

Implement the minimum Cliffs GCC clock/reset provider required by the current
G2 SD DTS (`kernel/g2/dts/qcom/g2-cliffs-sd.dts`), delivered as kernel patch
step `0003` under `kernel/g2/patches/`. Scope is limited to the GCC
clock/reset provider only. Interconnect, pinctrl, PMXR2230, downstream SDHCI
and boot-chain work are explicitly **not** part of this step.

No physical G2 was accessed. No block device was written. No Android/UFS/boot
storage was modified. All work is build-side only (Linux 7.1.5 Image + DTBs).

## Source lineage verification (before any code change)

Cliffs GCC source lineage was verified against the exact sources already
referenced by the project docs (`docs/g2-cliffs-linux-source-mapping-20260822.md`,
`docs/g2-cliffs-provider-mapping-progress-20260822.md`):

| Source | Commit | File used |
|---|---|---|
| OnePlusOSS `android_kernel_oneplus_sm8650` | `e39bf7032e38c547d588372a11a5dd55eb714860` | `drivers/clk/qcom/gcc-cliffs.c` |
| OnePlusOSS `android_kernel_oneplus_sm8650` | `e39bf7032e38c547d588372a11a5dd55eb714860` | `include/dt-bindings/clock/qcom,gcc-cliffs.h` |
| LineageOS `android_kernel_qcom_sm8650-devicetrees` | `4e146886d41b4de80f17ae1f5e19ed0839012136` | `qcom/cliffs.dtsi` |

The raw vendor files are stored in-repo for provenance under
`docs/g2-cliffs-source/`.

Key verified facts:

- G2 DTS references `qcom,cliffs-gcc` at `0x100000`, `GCC_SDCC2_AHB_CLK` (108),
  `GCC_SDCC2_APPS_CLK` (109) and `GCC_SDCC2_BCR` (17). These IDs match the
  vendor binding header exactly.
- Vendor `gcc-cliffs.c` defines the SDCC2 clock/reset hardware values used in
  this patch (all taken verbatim, none guessed):
  - `gcc_sdcc2_apps_clk_src`: `cmd_rcgr = 0x14018`, `mnd_width = 8`,
    `hid_width = 5`, freq table 400 kHz / 25 / 37.5 / 50 / 100 / 202 MHz,
    parents `bi_tcxo`, `gcc_gpll0`, `gcc_gpll9`, `gcc_gpll4`,
    `gcc_gpll0_out_even` (parent_map_8 cfg 0/1/2/5/6).
  - `gcc_sdcc2_ahb_clk`: `halt_reg/enable_reg = 0x14010`, `BIT(0)`.
  - `gcc_sdcc2_apps_clk`: `halt_reg/enable_reg = 0x14004`, `BIT(0)`, parent is
    the SDCC2 apps source, `CLK_SET_RATE_PARENT`.
  - GPLL0 (offset 0x0), GPLL0_OUT_EVEN (offset 0x0, post_div_shift 10, width 4,
    div table {0x1, 2}), GPLL4 (offset 0x4000), GPLL9 (offset 0x9000); all
    Lucid-OLE with enable vote register `0x52020` and `bi_tcxo` parent.
  - Reset `GCC_SDCC2_BCR` = `{ 0x14000 }`.
- Vendor `cliffs.dtsi` gcc node confirms the `bi_tcxo` clock input name. The
  SDCC2 RCG freq entry `F(400000, P_BI_TCXO, 12, 1, 4)` source-supports
  bi_tcxo = 19.2 MHz (`19200000/12 * 1/4 = 400000`), so the 19.2 MHz board
  fixed-clock added to the G2 DTS is evidence-backed, not guessed.

## Upstream (Linux 7.1.5) framework adaptation

Linux 7.1.5 (stock kernel.org) has **zero** `cliffs` references, so the vendor
driver cannot be copied verbatim: it uses Qualcomm downstream framework
extensions that do not exist upstream (`vdd_data`/`DEFINE_VDD_REGULATORS`,
`flags = HW_CLK_CTRL_MODE`, `enable_safe_config`, `qcom_cc_sync_state`,
`qcom_cc_register_rcg_dfs` for DFS RCGs). Each was mapped to the equivalent
upstream 7.1.5 API (verified against the 7.1.5 source in this build):

| Vendor (downstream) | Upstream 7.1.5 equivalent |
|---|---|
| `clk_rcg2_floor_ops` + `HW_CLK_CTRL_MODE` + `enable_safe_config` | `clk_rcg2_shared_floor_ops` |
| `vdd_data` / `gcc_cliffs_regulators` | omitted (upstream clk framework has no clock-voltage coupling here) |
| DFS registration for QUP clocks | omitted (not needed for SDCC2; SDCC2 is not a DFS RCG) |
| `qcom_cc_sync_state` | omitted (not present in upstream) |

Register values (offsets, halt/CFG regs, enable vote regs, parent_map cfg,
freq table) are identical to the vendor source.

## Changed files

| File | Change |
|---|---|
| `kernel/g2/patches/0003-cliffs-gcc.patch` | **new** — kernel patch step 0003: adds `include/dt-bindings/clock/qcom,gcc-cliffs.h` (188 lines, verbatim vendor binding) and `drivers/clk/qcom/gcc-cliffs.c` (minimal SDCC2 + GPLL parents + SDCC2 BCR, compatible `qcom,cliffs-gcc`), plus Kconfig (`CONFIG_SM_GCC_CLIFFS`) and Makefile wiring |
| `kernel/g2/dts/qcom/g2-cliffs-sd.dts` | add `bi_tcxo` 19.2 MHz fixed-clock node; wire `clocks`/`clock-names = "bi_tcxo"` into the gcc node (needed for the SDCC2 RCG to resolve its `bi_tcxo` parent); updated header comment |
| `kernel/g2/config/linux.aarch64.conf` | enable `CONFIG_SM_GCC_CLIFFS=y` |
| `scripts/build-g2-kernel.sh` | apply `kernel/g2/patches/*.patch` after extraction (`patch -p1 --forward`); properly merge the config fragment with `scripts/kconfig/merge_config.sh` (the previous copy+olddefconfig did not actually apply it) |
| `scripts/validate-g2-sd-artifacts.sh` | add GCC-provider validation step (DTB gcc node, bi_tcxo, `CONFIG_SM_GCC_CLIFFS=y`, `gcc-cliffs` string in Image) |
| `kernel/g2/README.md` | document the patch stack |
| `docs/g2-cliffs-source/` | **new** — raw vendor source evidence (`OnePlusOSS-gcc-cliffs.c`, `OnePlusOSS-gcc-cliffs.h`, `LineageOS-cliffs.dtsi`) |

## Build + validation (non-destructive)

Linux 7.1.5 kernel source SHA-256 verified (`22a0196b…e3041e7`) before build.
Full pipeline run with `scripts/build-g2-kernel.sh`:

- Kernel `Image`: 52,488,704 bytes, `kernelrelease 7.1.5`.
- G2 DTB `g2-cliffs-sd.dtb`: 4,051 bytes.
- `CONFIG_SM_GCC_CLIFFS=y` in `.config`; `drivers/clk/qcom/gcc-cliffs.o`
  built and `gcc-cliffs` present in the final Image.

`scripts/validate-g2-sd-artifacts.sh` result: **PASS (static/build validation)**.

- FDT magic `d00dfeed` PASS; DTB→DTS round-trip PASS.
- SDHCI spot-checks PASS (SDCC2 clocks 0x6c/0x6d, reset 0x11, SMMU 0x140, CD GPIO31).
- GCC provider checks PASS: `qcom,cliffs-gcc` in DTB, `bi-tcxo-clk` node,
  `clock-frequency = 0x124f800` (19.2 MHz), `CONFIG_SM_GCC_CLIFFS=y`,
  `gcc-cliffs` in Image.
- dtc warnings are structural only (pre-existing `unit_address_vs_reg` /
  `simple_bus_reg` from the WIP DTS shape); no errors.
- `dtbs_check` not run (`dtschema` not installed) — documented limitation.

Checksums:
- DTB `0cfb2865655619d426c2cc16d4d51dc8e815ca78b4b58910d8db75a40b6655ac`
- Image `03728833083557c459979201dfdb41745dd577c579ef852e3ee4ddf2751b21c1`

## Blockers / not done (by design)

- Interconnect (`qcom,cliffs-aggre1_noc/gem_noc/mc_virt/cnoc_cfg`), Cliffs
  pinctrl, PMXR2230 regulators, apps-SMMU instance, and downstream SDHCI
  driver work remain unimplemented — out of scope for this step.
- The G2 DTS still lacks an RPMh clock provider; `bi_tcxo` is supplied by a
  board fixed-clock (19.2 MHz) instead of `rpmhcc RPMH_CXO_CLK`.
- No runtime/boot validation was possible (no physical G2, build-only step by
  design).

## Readiness for first physical G2 microSD testing

**Not yet.** This step adds the minimum GCC clock/reset provider (SDCC2 clocks
+ reset) and it builds and validates, but the G2 DTS still references
interconnect/pinctrl/PMXR2230/SMMU providers that are not yet implemented in
this kernel. SDCC2 clock/reset resolution should work once the DTB is loaded;
the remaining blockers are the other provider groups and the unproven early
boot path (stock ABL vs UEFI/GRUB vs ROCKNIX ABL). See the Phase B report
(`docs/g2-phase-b-sd-boot-candidate-20260824.md`) blocker list.

## Safety statement

microSD/removable-media only. No block device was written, no physical device
was connected, and internal Android/UFS/ABL/vbmeta/dtbo/GPT storage was not
modified.
