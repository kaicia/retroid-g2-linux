# Retroid Pocket G2 Linux / SteamOS Project Progress Snapshot

Date: 2026-08-22

## Final project goal

Run a SteamOS/Armada-style Linux environment on Retroid Pocket G2 from microSD without deleting or replacing the internal Android installation. When the microSD is removed, the original Android system should remain usable. The project is currently in hardware/DT/kernel research; no boot or storage modification has been attempted.

## Workflow decision

Use GitHub as the project source of truth. Investigation scripts should be automated so the normal flow is:

GitHub -> Termux -> ADB -> physical G2 read-only audit -> result file -> GitHub commit/push.

Do not manually reconstruct long scripts in Termux when an automated repository script can perform the complete operation.

## Repository

`kaicia/retroid-g2-linux`

Current branch: `main`

## Completed physical-G2 investigation

The following SDHCI information has been read directly from the physical G2 Android Device Tree and saved in `dumps/g2/`:

- SDHCI node: `soc/sdhci@8804000`
- compatible: `qcom,sdhci-msm-v5`
- base: `0x08804000`
- bus width: 4
- interrupts: 207 and 223
- clocks: `iface`, `core`
- reset: `core_reset`
- interconnect names: `sdhc-ddr`, `cpu-sdhc`
- OPP frequencies: 100 MHz and 202 MHz
- `vdd-supply` -> PMXR2230 LDO13
- `vdd-io-supply` -> PMXR2230 LDO23
- IOMMU -> `apps-smmu@15000000`
- pinctrl states: `sdc2_on`, `sdc2_off`
- card detect raw GPIO tuple: `<0x16c 0x1f 0x1>`
- GPIO controller phandle `0x16c` -> `/soc/pinctrl@f000000`, compatible `qti,cliffs-pinctrl`
- CD GPIO number: 31
- CD debounce: 1500 ms
- `sdc2_on`: clk gpio62, cmd gpio51, data gpio38/39/48/49, CD gpio31
- `sdc2_on` drive strengths: clk 16, cmd/data 10, CD 2; pull-ups on cmd/data/CD
- `sdc2_off` state also captured
- vendor QoS nodes: `qos0` mask `0xf8`, vote `0x2c`; `qos1` mask `0x07`, vote `0x2c`
- G2 raw interconnect tuples:
  - `0x1a2 0x2f`
  - `0x189 0x200`
  - `0x1a3 0x2`
  - `0x1a4 0x21e`
- resolved G2 providers:
  - `cliffs-aggre1_noc`
  - `cliffs-mc_virt`
  - `cliffs-gem_noc`
  - `cliffs-cnoc_cfg`
- G2 DLL HSR list captured from the physical DT
- `qcom,restore-after-cx-collapse` captured

## Important reference projects

Armada and pocknix/ROCKNIX-style projects are being used as structural references for an ARM64 SteamOS-like port. pocknix contains RP6 support and a dedicated downstream Qualcomm SDHCI implementation.

The pocknix SM8550 kernel tree is pinned in its project structure and contains separate DTS, config and patch layers. Its SD implementation includes a downstream SDHCI driver and a dedicated SD DTSI.

## RP6/pocknix comparison findings

Strong structural similarities exist between G2 and the RP6/pocknix SD implementation, including the SDHCI address/interrupt structure, 4-bit operation, `iface/core`, reset, DLL configuration/HSR concepts, OPP frequencies, interconnect naming, regulators, pinctrl and card detect concepts.

However, G2-specific numeric values must not be copied from RP6/SM8550. In particular:

- G2 interconnect provider/endpoint IDs are different.
- G2 regulator providers are different.
- G2 GPIO controller is Cliffs pinctrl.
- G2 SMMU details must be resolved independently.
- G2 QoS values differ from the pocknix reference.
- Android/vendor properties must only be carried into Linux DTS when the selected Linux driver/binding actually consumes them.

## Kernel/driver direction

The current preferred path is to evaluate the pocknix/ROCKNIX downstream Qualcomm SDHCI implementation first rather than assuming upstream SDHCI alone will provide the required G2 functionality.

The downstream driver is known to interact with OPP, interconnect, regulators, pinctrl and reset. Exact G2 provider support in the selected kernel tree is still the critical blocker.

## WIP DTS

`dts/g2-sdhci-wip.dtsi` exists as a NON-BOOT hardware mapping skeleton.

It deliberately contains G2-derived values while leaving unresolved Linux provider references commented out. It is not claimed to compile or boot.

Blocked items include:

1. exact Linux GCC clock/reset labels and IDs;
2. exact Linux Cliffs interconnect provider labels and endpoint IDs;
3. PMXR2230 Linux regulator labels/binding;
4. exact Linux SMMU cells/stream IDs;
5. final Linux pinctrl labels and CD GPIO representation;
6. final OPP provider representation;
7. final upstream-vs-downstream SDHCI compatible/driver choice.

## Current phase

### Phase 1 — Hardware investigation: essentially complete

Physical G2 SDHCI and dependency data has been captured and committed.

### Phase 2 — Linux kernel/provider mapping: current phase

Need to inspect the exact selected ROCKNIX/pocknix kernel source and patches and map every blocked provider reference against actual Linux bindings/driver code.

### Phase 3 — Static DTS validation

After provider mapping, convert the WIP skeleton into a compilable DTS/DTSI and run `dtc` and relevant DT schema checks. No boot yet.

### Phase 4 — SD-card test

Only after static validation. Use a separate test microSD. Do not modify internal Android, AVB, UFS, bootloader or partitions as part of the initial test.

## Safety boundary

All G2 investigations completed so far are read-only Device Tree inspection. No block-device write, erase, format, repartition, slot change, AVB modification, firmware flashing, or internal Android modification has been performed.

## Key repository documents

- `docs/g2-sdhci-dependency-gap-audit-20260822.md`
- `docs/g2-sdhci-dts-preflight-mapping-20260822.md`
- `docs/g2-sdhci-pre-dts-status-20260822.md`
- `docs/g2-sdhci-provider-targeted-analysis-20260822.md`
- `docs/g2-sdhci-dts-wip-status-20260822.md`
- `dts/g2-sdhci-wip.dtsi`

## Next concrete task

Inspect the exact pocknix/ROCKNIX kernel source and patchset used by the intended build, then resolve the G2 Cliffs GCC, interconnect, PMXR2230 regulator, SMMU and pinctrl references against actual Linux code. Update the WIP DTS only with values that are source-supported. Then perform static DTS/schema validation before any boot experiment.
---

## Update 2026-08-24 — Phase B first microSD boot-test candidate (build-validated)

See `docs/g2-phase-b-sd-boot-candidate-20260824.md` for the full report.

Delivered in this phase (all build-validated, all SD-only):

- Real kernel build integration: Linux 7.1.5 (pocknix/Armada pin) + the G2
  Cliffs SD-only DTS integrated into `arch/arm64/boot/dts/qcom/` as a real
  kernel DT build target. Kernel Image (52,488,704 B) and G2 DTB (3,891 B)
  built by the kernel's own Kbuild.
- Minimal busybox rootfs (static aarch64, ~2.2 MiB) for the first boot test.
- MicroSD image (`build/g2/g2-cliffs-sd.img`, GPT `G2-BOOT` + `G2-ROOTFS`)
  with kernel, DTB, extlinux.conf and rootfs.
- Reproducible recipe committed as scripts:
  `scripts/build-g2-kernel.sh`, `scripts/build-g2-rootfs.sh`,
  `scripts/prepare-g2-sd-image.sh`, `scripts/validate-g2-sd-artifacts.sh`,
  plus `kernel/g2/kernel.conf`, `kernel/g2/dts/qcom/g2-cliffs-sd.dts`,
  `kernel/g2/config/linux.aarch64.conf`, `config/g2-sd/extlinux.conf`.
- Validation: FDT magic PASS, DTB round-trip PASS, all source-verified G2
  SDHCI values spot-checked PASS, checksums recorded. `dtbs_check` not run
  (dtschema not installed) — documented limitation.

Critical finding: mainline Linux 7.1.5 has ZERO `cliffs` references. The G2
DTB compiles but the `qcom,cliffs-*` GCC/interconnect/pinctrl and PMXR2230
providers it references do not yet exist as drivers in this kernel. The next
concrete step is to port the minimum Cliffs provider set from the verified
vendor source (LineageOS/OnePlusOSS cliffs commits) as patches under
`kernel/g2/patches/`, and to establish the exact G2 early-boot path.
