# G2 SDHCI driver compatibility assessment

Date: 2026-08-27

## Scope

Determine whether the G2 SDHCI should use the pocknix downstream Qualcomm SDHCI driver, the upstream SM7635/Milos SDHCI driver, or a hybrid kernel that carries both provider support and the downstream SDHCI implementation.

No G2 bootloader, internal storage, Android partition, or firmware was modified.

## Hardware facts already established

The physical G2 Android Device Tree captured in this repository shows:

- SDHCI base: `0x08804000`
- interrupts: `207`, `223`
- 4-bit bus
- clocks: `iface`, `core`
- reset: `core_reset`
- SDHCI interconnect names: `sdhc-ddr`, `cpu-sdhc`
- OPP frequencies: `100 MHz`, `202 MHz`
- G2 card-detect: Cliffs pinctrl GPIO `31`
- VDD: PMXR2230 LDO13
- VDD-IO: PMXR2230 LDO23
- apps SMMU: `0x15000000`

## Upstream Milos/SM7635 path

Current Linux contains a dedicated Milos SDHCI compatible:

```dts
compatible = "qcom,milos-sdhci", "qcom,sdhci-msm-v5";
```

The upstream Milos SoC node uses the same SDCC2 register block at `0x08804000` and the same SDCC2 GCC clocks and reset names. It also uses the same two interconnect path names and the same SMMU stream tuple used in the provider mapping work.

Important difference: the upstream Milos reference board has board/SoC-specific IRQ values and also declares an XO clock. Those values must not be copied to G2. The G2 physical IRQs `207/223` remain authoritative for the G2 board, and the G2 clock inventory currently contains only `iface/core`.

## pocknix downstream path

The inspected pocknix revision `3592553f79d737b9c9e4781dbeb5bce97b7be893` adds a separate driver, `sdhci-msm-downstream.c`, selected by `MMC_SDHCI_MSM_DOWNSTREAM` and built as `sdhci-msm-downstream.o`.

Its reference DT uses:

```dts
compatible = "qcom,sdhci-msm-v5-downstream";
```

and depends on the downstream-specific representation of DLL/HSR settings, OPPs, regulators, interconnects and QoS. This is intentionally not a textual drop-in replacement for the upstream `qcom,milos-sdhci` node.

## Compatibility result

### Option A — upstream Milos SDHCI

Pros:

- Uses the mainline SM7635/Milos provider implementations directly.
- Avoids carrying the very large downstream SDHCI patch solely to obtain an SDCC2 driver.
- Mainline already has a Milos-specific SDHCI compatible and DT description.
- Best fit for a new G2 kernel if upstream SDHCI functionality is sufficient.

Open items:

- Verify the upstream driver's tuning/performance behavior on the actual G2 hardware.
- Resolve the final G2 card-detect pinctrl state and regulator representation.
- Preserve the G2 IRQs and other board-specific properties instead of copying the Milos reference board values.

### Option B — pocknix downstream SDHCI

Pros:

- Existing RP6/Odin2 reference demonstrates the intended downstream DLL/HSR path and SDHCI behavior on Qualcomm handhelds.
- Closely matches the G2 physical DT structure.

Open items:

- The downstream driver must be carried into the selected G2 kernel tree.
- Its property expectations must be reconciled with the SM7635 provider implementation.
- Downstream QoS and voltage/current properties must be mapped without copying SM8550 numeric values.
- A compile test is required to prove the driver and SM7635 provider stack coexist in the same kernel configuration.

### Option C — hybrid kernel

A hybrid kernel is technically plausible: retain the SM7635/Milos GCC, interconnect, pinctrl, regulator and SMMU providers while also building the pocknix downstream SDHCI host driver.

However, this is not proven until the exact downstream driver source is applied to the same kernel version containing the required SM7635 providers and the resulting kernel/DTS is compiled.

This should therefore be treated as an integration experiment, not as an assumed architecture.

## Current decision

Do not modify the WIP DTS to a bootable state yet.

The preferred investigation order is now:

1. Build a minimal upstream-Milos SDHCI compile candidate using the G2 physical IRQs, G2 interconnect topology, G2 SMMU tuple and G2 regulator rails.
2. In parallel, make a hybrid compile candidate that adds the pocknix downstream SDHCI driver without changing the G2 hardware-derived provider values.
3. Compare compile-time DT binding compatibility and kernel configuration requirements.
4. Only after both candidates pass static compilation should a bootable G2 DTS be considered.

## Non-negotiable constraints

- Do not copy RP6/Odin2 IRQs, GPIOs, regulator IDs, interconnect IDs, or QoS masks into G2.
- Do not erase, repartition, reformat, or otherwise modify internal Android storage.
- Do not perform a G2 boot experiment until the DTS and kernel integration pass static validation.

## Source anchors

- pocknix source baseline: `shuuri-labs/pocknix-os` revision `3592553f79d737b9c9e4781dbeb5bce97b7be893`
- G2 physical-DT evidence: repository `dumps/g2/` and `docs/g2-project-progress-20260822.md`
- G2 Linux provider mapping: `docs/g2-sdhci-linux-provider-map-20260827.md`
