# G2 first kernel build — 2026-08-27

Task: `G2-B-0001-R1` — create and validate the first minimal Retroid Pocket G2
Linux kernel/DTS build candidate, build-side only.

Status: **PASS — first G2 kernel Image and G2 board DTB built and schema-validated.**

Safety: no device was modified. Nothing was flashed, erased, or written to any
Android/UFS/ABL/GPT/boot/vendor_boot/vbmeta/dtbo/firmware partition, and no
physical SD card was prepared or written. All work happened in a throwaway
Linux checkout. The physical objective remains microSD-only and
non-destructive.

## 1. Source revision

- Repository: `https://github.com/torvalds/linux.git`
- Revision (verified): `73e3f0710014fe6d4ed98cfc02292f6121db7558`
- Head subject: `Merge tag 'nfs-for-7.3-1' of git://git.linux-nfs.org/projects/trondmy/linux-nfs`
- `kernel.release`: `7.2.0-g73e3f0710014-dirty`
- Same revision already verified in `docs/deepseek-compile-result-20260827.md`
  (known-good `milos-fairphone-fp6.dtb` compiled there). The prior compile
  wrapper result was reused only as evidence; the Fairphone board DTS is not
  the final G2 board DTS.

## 2. Sources inspected

- SDHCI driver: `drivers/mmc/host/sdhci-msm.c` (revision 73e3f071...).
  Parses via `mmc_of_parse`; clocks `iface`/`core` required, `xo` optional
  (warn-only), `bus`/`cal`/`sleep` optional; interconnects via
  `dev_pm_opp_of_find_icc_paths`; OPP table optional
  (`devm_pm_opp_of_add_table`, `-ENODEV` tolerated); `qcom,dll-config` and
  `qcom,ddr-config` consumed; no power-domain requirement.
- DT binding: `Documentation/devicetree/bindings/mmc/qcom,sdhci-msm.yaml`.
  `qcom,milos-sdhci` is a valid first compatible (line 50). Required:
  `compatible`, `reg`, `clocks` (minItems 2), `clock-names`, `interrupts`.
  `clocks` allows 2 items (iface/core) — the `xo` clock is optional.
- Milos SoC DTS: `arch/arm64/boot/dts/qcom/milos.dtsi` (sdhc_2 `mmc@8804000`,
  line 1754) and `pm7550.dtsi`. Board reference: `milos-fairphone-fp6.dts`.
- Providers present and enabled: milos GCC (`qcom,milos-gcc`),
  milos RPMH clock, milos interconnect (`qcom,sm7635-*`), milos RPMHPD,
  milos TLMM, apps SMMU (`apps_smmu` at `0x15000000`), pm7550 RPMH regulators.

## 3. Files changed

Repository (this branch):

- `dts/g2/milos-retroid-g2.dts` — new G2 board DTS (the first G2 board DTS).
- `dts/g2/patches/0001-arm-qcom-register-retroid-g2-board.diff` — binding
  registration required by the kernel tree (`arm/qcom.yaml`).
- `scripts/build-g2-first-candidate.sh` — reproducible build harness.
- `docs/g2-first-kernel-build-20260827.md` — this report.

Kernel tree (throwaway build clone at the pinned revision):

- `arch/arm64/boot/dts/qcom/milos-retroid-g2.dts` — copy of the G2 board DTS.
- `arch/arm64/boot/dts/qcom/Makefile` — `dtb-$(CONFIG_ARCH_QCOM) += milos-retroid-g2.dtb`.
- `Documentation/devicetree/bindings/arm/qcom.yaml` — added `retroid,g2` to the
  `qcom,milos` family enum.

## 4. G2-confirmed values used (from this repository only)

Source: `dumps/g2/` (read-only ADB audits) and
`docs/g2-sdhci-linux-provider-map-20260827.md`. No value was invented.

| G2 physical fact | Value used in DTS |
|---|---|
| SDCC2 base / size | `reg = <0x0 0x08804000 0x0 0x1000>` |
| IRQs (hc_irq, pwr_irq) | `GIC_SPI 207`, `GIC_SPI 223` (LEVEL_HIGH) |
| Clocks (iface, core only) | `GCC_SDCC2_AHB_CLK` (121), `GCC_SDCC2_APPS_CLK` (122) |
| Reset | `GCC_SDCC2_BCR` (20) |
| SMMU stream | `<&apps_smmu 0x140 0>` (dump `00 00 01 40`) |
| Card detect | `<&tlmm 31 GPIO_ACTIVE_LOW>`, debounce 1500 ms |
| SD pins | CLK gpio62, CMD gpio51, DATA gpio38/39/48/49, CD gpio31 (drives/bias from dump) |
| VDD rail | PMXR2230 (Linux pm7550, pmic-id "b") LDO13, 2960000 µV fixed |
| VDD-IO rail | PMXR2230 LDO23, 1800000–2960000 µV |
| DLL/DDR config | `qcom,dll-config = <0x0007442c>`, `qcom,ddr-config = <0x80040868>` (from `qcom,dll-hsr-list`) |
| Bus width | 4 |
| Status | `okay` (physical `ok`) |

Interconnect topology follows the provider-map mainline mapping
(`aggre2_noc MASTER_SDCC_2 → mc_virt SLAVE_EBI1`,
`gem_noc MASTER_APPSS_PROC → cnoc_cfg SLAVE_SDCC_2`); see open items.

## 5. CONFIG requirements

The G2 SDHCI candidate only needs the drivers below, all enabled by the
`arm64 defconfig` (no `defconfig` change was required):

```
CONFIG_ARCH_QCOM=y
CONFIG_MMC=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_MSM=y
CONFIG_SM_GCC_MILOS=y              # milos GCC (SDCC2 clocks/reset)
CONFIG_QCOM_CLK_RPMH=y
CONFIG_QCOM_RPMH=y
CONFIG_QCOM_RPMHPD=y
CONFIG_REGULATOR_QCOM_RPMH=y       # pm7550 LDO13/LDO23
CONFIG_INTERCONNECT=y
CONFIG_INTERCONNECT_QCOM=y
CONFIG_INTERCONNECT_QCOM_MILOS=y
CONFIG_ARM_SMMU=y
CONFIG_ARM_SMMU_QCOM=y
CONFIG_PINCTRL_MSM=y
CONFIG_PINCTRL_MILOS=y
CONFIG_SERIAL_MSM=y                # console, for later SD boot
CONFIG_DEVTMPFS=y
```

## 6. Exact build commands

Build environment: GitHub Actions ubuntu-latest runner; deps installed with
`apt-get install bc bison flex libssl-dev libelf-dev device-tree-compiler
llvm lld`; DT schema tools via `pip3 install --user dtschema` (see section 8
for the `libfdt` wheel fix).

```text
git clone --filter=blob:none --no-checkout https://github.com/torvalds/linux.git linux
git -C linux fetch --depth 1 origin 73e3f0710014fe6d4ed98cfc02292f6121db7558
git -C linux checkout 73e3f0710014fe6d4ed98cfc02292f6121db7558

# copy dts/g2/milos-retroid-g2.dts -> linux/arch/arm64/boot/dts/qcom/
# add `dtb-$(CONFIG_ARCH_QCOM) += milos-retroid-g2.dtb` to that Makefile
# add `- retroid,g2` to arm/qcom.yaml (see patch file)

make -C linux ARCH=arm64 LLVM=1 defconfig
make -C linux ARCH=arm64 LLVM=1 -j4 Image
make -C linux ARCH=arm64 LLVM=1 -j4 qcom/milos-fairphone-fp6.dtb      # known-good baseline
make -C linux ARCH=arm64 LLVM=1 -j4 qcom/milos-retroid-g2.dtb          # G2 DTB
make -C linux ARCH=arm64 LLVM=1 W=1 -j4 qcom/milos-retroid-g2.dtb      # dtc warnings
PATH=$HOME/.local/bin:$PATH make -C linux ARCH=arm64 LLVM=1 CHECK_DTBS=y -j4 qcom/milos-retroid-g2.dtb
```

## 7. Artifacts — sizes and hashes (SHA256)

| Artifact | Size (bytes) | SHA256 |
|---|---|---|
| `arch/arm64/boot/Image` | 42113536 | `c9a6125f0576ac53704e49aa29923260c26251acead6393d038506ab36a95d4d` |
| `arch/arm64/boot/dts/qcom/milos-retroid-g2.dtb` | 52983 | `6b46bbf39284847405e146bc1536e6e5e7d294600f37494dda06ccc6a16bb297` |
| `arch/arm64/boot/dts/qcom/milos-fairphone-fp6.dtb` | 69126 | `c3908fe06eeb9e236923b9081639d7f7d18bb10d42848077750b2397c8f5ad6a` |

The baseline DTB size (69126 bytes) matches the already-verified compile
result exactly.

## 8. Validation results

- **dtc compile:** PASS. `milos-retroid-g2.dtb` generated with no errors.
- **dtc warnings (`W=1`):** only two warnings, both from `milos.dtsi`
  (identical on the known-good baseline), none from G2 nodes:
  - `avoid_unnecessary_addr_size` `display-subsystem@ae00000/dsi@ae94000`
  - `unique_unit_address_if_enabled` `/memory@0`
- **DT schema (`CHECK_DTBS=y`, dt-validate):** PASS after registering the
  board compatible in `arm/qcom.yaml`. `DTC [C]` for both G2 and baseline
  with no errors or warnings. (Before registration, dt-validate reported:
  `/: failed to match any schema with compatible: ['retroid,g2', 'qcom,milos']`.)
- **Verified DTB contents** (fdtdump): sdhc_2 interrupts 207/223, two clocks
  `iface`/`core`, `iommus <0x140 0>`, `cd-gpios` gpio31 active-low, debounce
  1500, LDO13 2960000 µV / LDO23 1800000–2960000 µV, G2 pinctrl states,
  `status = "okay"`, and the unconfirmed Milos `power-domains` /
  `operating-points-v2` / `opp-table` are removed.

Toolchain note: the `dtschema` PyPI package installed a `libfdt` wheel that
fails to import on Python 3.12 (`_libfdt.so: undefined symbol: PyInt_AsLong`).
Fixed by building `pylibfdt` from the bundled dtc source
(`git clone --branch v1.7.2 https://git.kernel.org/pub/scm/utils/dtc/dtc.git`
+ `make -C dtc pylibfdt`) and installing `_libfdt.so`/`libfdt.py`. After the
fix `dt-doc-validate --version` reports `2026.6`.

## 9. Exact first errors preserved

First compile attempt of the G2 DTB (dtc), verbatim:

```text
Error: arch/arm64/boot/dts/qcom/milos-retroid-g2.dts:155.2-18 Properties must precede subnodes
FATAL ERROR: Unable to parse input tree
make[3]: *** [scripts/Makefile.dtbs:140: arch/arm64/boot/dts/qcom/milos-retroid-g2.dtb] Error 1
```

Fix: dtc requires properties to precede subnode-producing directives; moved
`status` before the `/delete-*` directives and used node-name delete form.

Second dtc error (same build), verbatim:

```text
Error: arch/arm64/boot/dts/qcom/milos-retroid-g2.dts:155.16-32 syntax error
FATAL ERROR: Unable to parse input tree
```

Fix: the bundled dtc 1.7.2 does not accept `/delete-node/ &label;`; used
`/delete-node/ opp-table;` (node-name form).

Prior wrapper failure reused as evidence only (`docs/deepseek-compile-result-20260827.md`):
`vreg_l13b`/`vreg_l23b` labels were undefined in the wrapper include set; the
G2 board DTS resolves this by defining the PMXR2230 (pm7550 "b") LDO13/LDO23
regulators with G2-confirmed voltages.

## 10. Blockers and open items

None of these block this build-side candidate; they must be resolved before a
bootable G2 DTS/SD image.

1. **TLMM base mismatch.** G2 physical pinctrl is `pinctrl@f000000`
   (`qcom,cliffs-pinctrl`); mainline `milos.dtsi` defines `tlmm:
   pinctrl@f100000` (`qcom,milos-tlmm`). `&tlmm` (Milos base) is used here.
   Needs hardware confirmation of the correct Linux TLMM base for G2.
2. **SDCC2 interconnect endpoints.** G2 physical `sdhc-ddr` path is
   `aggre1_noc(0x2f) → mc_virt(0x200)`; mainline Milos uses
   `aggre2_noc MASTER_SDCC_2(8) → mc_virt SLAVE_EBI1(1)`. The mainline mapping
   (also the provider-map conclusion) is used; the physical A1NOC/ID values
   must be confirmed on hardware.
3. **SMMU stream ID.** G2 physical stream is `0x140` (dump `00 00 01 40`);
   `docs/g2-sdhci-linux-provider-map-20260827.md` and the static validator
   currently record `0x540` (copied from mainline Milos). The G2-confirmed
   value `0x140` is used here; the provider-map/validator should be corrected
   and re-validated.
4. **SDCC2 OPP table.** G2 physical table is a SoC-level node with
   `opp-avg-kBps`/`opp-peak-kBps` (100/202 MHz) and no `required-opps`; the
   mainline Milos child `opp-table` uses `required-opps`/RPMHPD levels. The
   G2 representation is not yet source-supported, so `operating-points-v2`
   and the Milos child table are omitted here.
5. **`qcom,dll-hsr-list` / downstream driver.** The upstream binding consumes
   `qcom,dll-config`/`qcom,ddr-config` (used, from G2 values). The pocknix
   downstream `sdhci-msm-downstream.c` driver path is a separate decision
   (`docs/g2-sdhci-driver-compatibility-20260827.md`).
6. **Board prerequisites.** No memory/reserved-memory nodes (values not
   confirmed in `dumps/`), so the DTB is intentionally not bootable.
7. **Fairphone-not-G2 guard.** IRQ numbers, cd GPIO, SD pins, regulator
   voltages and compatible are all G2-specific; nothing was copied from the
   Fairphone board except the standard Linux provider structure.

## 11. Next recommended single task

Register and correct the G2 SMMU stream ID: update
`docs/g2-sdhci-linux-provider-map-20260827.md` and
`scripts/validate-g2-sdhci-provider-map.py` to the G2-confirmed `0x140`
(and record the TLMM-base and A1NOC interconnect-endpoint discrepancies), then
re-run `scripts/validate-g2-sdhci-provider-map.py` and rebuild this candidate
in CI to confirm the corrected mapping is still consistent. After that, the
single highest-value next build task is resolving the G2 SDCC2 OPP-table
representation so `operating-points-v2` can be restored.
