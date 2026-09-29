# PMXR2230 regulator driver entry — 2026-09-29

Closes the one runtime gap on the SDCC2 (microSD) path
(`docs/g2-regulators-sdcc2-wiring-20260929.md`): mainline
`drivers/regulator/qcom-rpmh-regulator.c` has no PMXR2230 PMIC, so the
`qcom,pmxr2230-rpmh-regulators` node the DTS declares would never bind and
`sdhc_2` (whose vmmc/vqmmc are `vreg_l13b`/`vreg_l23b`) would probe-defer forever.

## Deliverable
`kernel/sm8635/patches/20-sm8635/drivers/regulator/qcom-rpmh-regulator-add-pmxr2230.patch`
— a small addition to the upstream driver (not a from-scratch port, so shipped as
a patch, not a staged source copy):
1. `pmxr2230_vreg_data[]` — the PMIC's regulator table.
2. `{ .compatible = "qcom,pmxr2230-rpmh-regulators", .data = pmxr2230_vreg_data }`
   in `rpmh_regulator_match_table[]`.

Generated against the CI-pinned upstream tree (torvalds/linux
`5225b8eec4c9bb21aecff6295fab6346a3c3738e`); **`git apply --check` is clean**.

## Why a driver entry was needed
The Xiaomi downstream (peridot-u-oss) models regulators the old per-node way
(`qcom,rpmh-vrm-regulator`, one DT node each), which mainline dropped in favour of
the grouped per-PMIC driver — so there was no downstream table to port. PMXR2230
is newer than the pinned upstream, which supports ~38 PMICs but not this one.

## The table (from the G2 /proc/device-tree dump, PMIC id "b")
24 regulators: 3 FTSMPS, LDOs l1–l5/l7–l13/l16–l23, BOB1 (l6/l14/l15 absent on
this PMIC). Each rail mapped to the mainline `pmic5` hardware-range struct whose
window covers its configured DT range:

| rails | hw_data | window | configured examples |
|---|---|---|---|
| smps1–3 | `pmic5_ftsmps525` | 0.3–1.3V + 1.376V+ | s1 1.86–2.04, s2 1.26–1.41, s3 0.97–1.04 |
| ldo1–5, 7–12 | `pmic5_nldo515` | 0.32–2.0V | 0.82–1.2V core rails + 1.8V (as pm8550 also maps 1.8V to nldo515) |
| ldo13, 16–23 | `pmic5_pldo` | 1.504–3.544V | **l13 2.7–3.3 = vmmc**, **l23 1.65–3.544 = vqmmc**, l16–l22 2.x–3.5 |
| bob1 | `pmic5_bob` | 3.0–3.99V | 3.008–3.96 |

All referenced symbols (`pmic5_ftsmps525`, `pmic5_nldo515`, `pmic5_pldo`,
`pmic5_bob`, `RPMH_VREG`, `SMPS`/`LDO`/`BOB`) exist in the driver; the table's
form is identical to the existing `pm8550_vreg_data[]`.

## Confidence / caveats
- **SD rails (l13 vmmc, l23 vqmmc) — high confidence:** exact voltages verified,
  clearly P-type LDOs, `pmic5_pldo` window fits.
- **Other rails — inferred:** the N-vs-P LDO choice and range struct are derived
  from the configured DT windows (which give the operating window, not the LDO's
  full hardware range) plus the pm8550 precedent. Datasheet-confirm before other
  consumers rely on them.
- **supply-name strings are per-rail placeholders** — the board DT declares no
  parent input supplies for this PMIC, so they are cosmetic here. Set real
  `vdd-*-supply` groupings when the PMIC input schematic is known.
- **Compile-verified (2026-09-29):** `qcom-rpmh-regulator.o` builds clean with the
  PMXR2230 patch against linux 7.1; see `docs/g2-build-verification-20260929.md`.
  (`git apply --check` was also clean; the DTB CI does not compile kernel C.)

## After this
The full SDCC2 path is now representable end-to-end: gcc clocks + apps_smmu +
icc + **PMXR2230 vmmc/vqmmc** + tlmm pins → `sdhc_2 status=okay`. Remaining before
a real SD mount on hardware: build the kernel (holodor `make kernel`) and, for
performance/PM, add rpmhpd + the sdhc OPP table.
