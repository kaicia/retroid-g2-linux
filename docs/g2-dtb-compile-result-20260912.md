# G2 DTB compile result — 2026-09-12

First successful compilation of a G2 device tree. This closes the task that had
sat unexecuted since 2026-08-27 (originally
`docs/archive/automation/deepseek-compile-task-20260827.md`).

Build-side only. No G2 device, microSD card, bootloader or partition was
touched.

## Result

| | |
|---|---|
| Linux revision | `5225b8eec4c9bb21aecff6295fab6346a3c3738e` |
| Baseline DTB | `qcom/milos-fairphone-fp6.dtb`, 69126 bytes, sha256 `c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a` |
| G2 candidate | `qcom/g2-sdhci-compile-test.dtb`, 52804 bytes, sha256 `c0343b0df8d4a9b6783d5aef758dab2f7e9d9dfc494327bb9f2f35212cbf955c` |
| Source | `dts/g2-sdhci-compile-test.dts` |
| Reproduce | `scripts/build-g2-dtb-compile-candidate.sh` |

The baseline is built first on purpose: if the untouched upstream board DTB
fails, the toolchain is at fault and a G2 failure would be misattributed.

## What the compile does and does not prove

Proved: the DTS is syntactically valid, every referenced label resolves, and
the G2 hardware values survive into the binary. Verified by decompiling the
DTB:

```
interrupts = <0x00 0xcf 0x04 0x00 0x00 0xdf 0x04 0x00>   /* GIC_SPI 207, 223 */
iommus     = <0x2c 0x140 0x00>                           /* apps_smmu 0x140  */
cd-gpios   = <0x57 0x1f 0x01>                            /* tlmm GPIO 31, active low */
pins       = "gpio62", function "sdc2_clk", drive-strength 0x10
```

Not proved: that the G2 boots, that SDCC2 probes, or that the card is usable.
Three known risks below each compile cleanly and only fail on hardware.

## Attempt 1 — the originally specified combination failed

The 2026-08-27 task specified `milos.dtsi` + `pm7550.dtsi` + the G2 merge
fragment. That combination cannot build:

```
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references):
  /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l13b"
  also defined at arch/arm64/boot/dts/qcom/g2-sdhci-milos-merge.dtsi:9.9-53.3
arch/arm64/boot/dts/qcom/milos.dtsi:1754.23-1806.5: ERROR (phandle_references):
  /soc@0/mmc@8804000: Reference to non-existent node or label "vreg_l23b"
```

`vreg_l13b` / `vreg_l23b` are defined in `milos-fairphone-fp6.dts`, the board
file — not in `pm7550.dtsi`. The specified include set can therefore never
resolve them. This is a defect in the task specification, not in the fragment.

The task also specified the target as
`arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb`. Current kernels resolve DTB
targets relative to `arch/arm64/boot/dts`, so that path doubles and fails with
"No rule to make target". The working form is `qcom/milos-fairphone-fp6.dtb`.

## Attempt 2 — evidence-only candidate, builds clean

`dts/g2-sdhci-compile-test.dts` includes `milos.dtsi` + `pm7550.dtsi` and adds
only G2 values taken from `dumps/g2/`:

- SDCC2 interrupts GIC_SPI 207 / 223
- SMMU stream `<&apps_smmu 0x140 0>`
- `cd-gpios = <&tlmm 31 GPIO_ACTIVE_LOW>`
- G2 `sdc2` pin states: clk gpio62 ds16; cmd gpio51 pull-up ds10;
  data gpio38/39/48/49 pull-up ds10; card-detect gpio31 pull-up ds2

Nothing is copied from `milos-fairphone-fp6.dts`.

`vmmc-supply` / `vqmmc-supply` are deliberately **absent**. The G2 rails are
PMXR2230 LDO13 / LDO23; upstream has no PMXR2230 definition, and reusing the
Fairphone `pm7550` voltage windows would be exactly the board-value copying this
project forbids. Consequence: as built, the card is not powered. This is an
explicit gap, not an oversight.

## DT schema validation

`make ARCH=arm64 CHECK_DTBS=1 qcom/g2-sdhci-compile-test.dtb` produces exactly
one finding for the candidate:

```
g2-sdhci-compile-test.dtb: /: failed to match any schema with compatible:
  ['retroid,g2', 'qcom,milos']
```

That is the root board compatible not being registered in
`Documentation/devicetree/bindings/arm/qcom.yaml` — expected for an out-of-tree
board, and it would be fixed by a binding patch when the port is upstreamed.

Nothing else was reported. The `mmc@8804000` node, its `iommus`, `cd-gpios`,
`interrupts` and the three `g2-sdc2-*` pin states all pass schema validation.
Schema validation checks property shapes against the bindings; it does not
check that a pin can actually take the function assigned to it, which is why
risk 1 below survives a clean run.

## Known runtime risks

Ranked by how likely they are to stop the card working. All three are recorded
in `docs/g2-provider-domain-decision-20260912.md` §4.

1. **Pin map.** `drivers/pinctrl/qcom/pinctrl-milos.c` offers `sdc2_cmd` only on
   gpio61 and `sdc2_data` only on gpio34/35/57/58. The G2's gpio51 and
   gpio38/39/48/49 are QUP pins there. `dtc` does not validate pin/function
   pairs, so this compiles and is expected to be **rejected at probe**. Upstream
   has no Cliffs pinctrl driver, so there is currently nothing that describes
   the G2's TLMM correctly.
2. **SMMU stream ID.** G2 says `0x140`, upstream milos says `0x540`. A wrong ID
   faults on the first SDCC2 DMA.
3. **Interrupts.** G2 says SPI 207/223, upstream milos says 204/125. A wrong IRQ
   means the controller never completes a command.
4. **No card power**, as described above.

## Next steps

1. Settle risk 2 from the consolidated hardware dump, section B5
   (`docs/g2-hardware-dump-plan-20260912.md`).
2. Decide how to describe the G2 TLMM: verify whether the milos pinctrl driver
   can drive the G2 pins, or write a Cliffs pin map. This is now the largest
   piece of real driver work the SD path needs.
3. Describe the PMXR2230 rails so the card can be powered, from G2 regulator
   evidence rather than the Fairphone values.
4. Only then is a boot attempt meaningful.
