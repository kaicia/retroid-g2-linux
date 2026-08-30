# G2 Stage B — First microSD Image Preparation (SD-only)

Date: 2026-08-23
Status: COMPLETE to the extent supported by repository evidence

## Scope

Stage B of `docs/development-roadmap-20260822.md` produces the first microSD
image structure containing kernel, G2 DTB, minimal rootfs and boot
configuration. Because the repository does not yet contain a kernel source
tree, a rootfs, or a kernel build harness, this run implemented every part
of the image pipeline that the current evidence supports:

1. a first **compile-verified G2 SD-only DTS target** (`dts/g2/g2-cliffs-sd.dts`);
2. a non-destructive **DTS validation script** (`scripts/validate-g2-cliffs-dts.sh`);
3. a non-destructive **microSD image preparation harness**
   (`scripts/prepare-g2-sd-image.sh`) with strict removable-media guards;
4. a **boot configuration skeleton** (`config/g2-sd/extlinux.conf`);
5. validation results and documented limitations/blockers (this document).

No kernel binary or rootfs exists in the repository yet; the image harness
therefore validates those inputs and requires them to be supplied by a later
bring-up build. This run did not build, flash, or write any block device.

## Safety status

- microSD/removable-media only. All image work writes only to a **file**.
- Internal Android/UFS/ABL/vbmeta/dtbo/GPT storage: NOT modified.
- Removing the microSD must preserve the stock Android boot path.
- The image harness refuses internal-storage device names (`/dev/sda`,
  `/dev/sdb`, `/dev/nvme*`, `/dev/mmcblk0`) and only permits a removable
  `/dev/mmcblk[1-9]*` device with explicit user confirmation.
- Compiling the DTS does NOT make the G2 bootable.

## Files created

| File | Purpose |
|---|---|
| `dts/g2/g2-cliffs-sd.dts` | First compile-verified G2 SD-only DTS target |
| `scripts/validate-g2-cliffs-dts.sh` | Non-destructive cpp+dtc compile + round-trip validation |
| `scripts/prepare-g2-sd-image.sh` | Non-destructive microSD image builder with storage guards |
| `config/g2-sd/extlinux.conf` | Boot configuration skeleton for the SD boot path |
| `.gitignore` | Prevents committing generated `build/`, `*.img`, `*.dtb`, `*.pp.dts` |

## Source verification used

Every DTS value was taken either from the physical G2 Android DT dumps
(`dumps/g2/`) or from the exact Cliffs Linux source referenced by the project:

- LineageOS `android_kernel_qcom_sm8650-devicetrees` commit
  `4e146886d41b4de80f17ae1f5e19ed0839012136` (`qcom/cliffs.dtsi`,
  `qcom/cliffs-mtp.dtsi`, `qcom/cliffs-pinctrl.dtsi`).
- OnePlusOSS `android_kernel_oneplus_sm8650` commit
  `e39bf7032e38c547d588372a11a5dd55eb714860`
  (`include/dt-bindings/clock/qcom,gcc-cliffs.h`,
   `include/dt-bindings/interconnect/qcom,cliffs.h`).

Confirmed matches with the G2 physical DT:

- `sdhci@8804000`, `qcom,sdhci-msm-v5`, IRQs `GIC_SPI 207/223`.
- Clocks: `GCC_SDCC2_AHB_CLK = 108`, `GCC_SDCC2_APPS_CLK = 109`.
- Reset: `GCC_SDCC2_BCR = 17`.
- Interconnects: `MASTER_SDCC_2 = 47`, `SLAVE_EBI1 = 512`,
  `MASTER_APPSS_PROC = 2`, `SLAVE_SDCC_2 = 542` (matches G2 tuple
  `<0x1a2 0x2f 0x189 0x200 0x1a3 0x2 0x1a4 0x21e>`).
- IOMMU: `apps_smmu@15000000`, stream `0x140` (G2 `iommus` raw).
- CD GPIO: Cliffs pinctrl GPIO31, active-low; debounce 1500 ms.
- Pinctrl `sdc2_on`/`sdc2_off` exactly as the physical G2 pads.
- DLL HSR list matches the G2 dump.
- OPP: 100 MHz and 202 MHz.
- qos0/qos1 masks `0xf8`/`0x07`, vote `44`.

## Validation results (non-destructive)

Command:

```sh
scripts/validate-g2-cliffs-dts.sh
```

Result: **PASS** (exit 0).

- cpp preprocessing: OK (174 lines).
- dtc compile to DTB: OK, 3891 bytes.
- DTB → DTS round-trip: OK.
- Remaining `dtc` warnings are structural (`simple-bus` children without a
  `reg`, unit-name case, opp-table without `reg`) and mirror the Qualcomm
  downstream source layout; none are errors.

DTB content spot-check confirms the exact G2 values survived compilation:

```text
sdhci@8804000 { compatible = "qcom,sdhci-msm-v5"; ... }
clocks      = <0x02 0x6c 0x02 0x6d>;   # GCC_SDCC2_AHB_CLK / APPS_CLK
resets      = <0x02 0x11>;             # GCC_SDCC2_BCR
iommus      = <0x03 0x140 0x00>;       # apps_smmu stream 0x140
interconnects = <... 0x2f ... 0x200 ... 0x02 ... 0x21e>;
cd-gpios    = <0x0b 0x1f 0x01>;        # tlmm GPIO31 active-low
```

Image harness validation (dry-run, no writes):

```sh
scripts/prepare-g2-sd-image.sh --kernel <Image> --dtb <dtb> \
  --rootfs <rootfs> --dry-run
```

Result: plan printed, exit 0, nothing written.

Storage guard tests:

- `/dev/sda` (internal UFS) → REFUSED.
- `/dev/mmcblk0` (internal) → REFUSED.
- `/dev/nvme0` → REFUSED.
- `/dev/mmcblk1` (removable microSD per G2 evidence `mmc1 -> mmcblk1`)
  → passes pattern guard, then requires presence + confirmation.

Full image-file build was exercised end-to-end on a throwaway file in
`/tmp` (512 MiB). Verified GPT layout `G2-BOOT` (EFI) + `G2-ROOTFS` (Linux),
boot partition containing `boot/Image`, `boot/g2-cliffs-sd.dtb`,
`extlinux/extlinux.conf`, and rootfs partition populated. This validated the
pipeline without touching any real device.

## Limitations and blockers

1. **Kernel**: no kernel source tree or kernel Image exists in the repo.
   The pocknix/ROCKNIX kernel recipe (Linux `7.1.5`, see
   `docs/kernel-lineage-selection-20260822.md`) is the candidate input set but
   is not present here. The image harness requires `--kernel` to be supplied
   by a later bring-up build.
2. **Rootfs**: no minimal rootfs exists in the repo. `--rootfs` (tarball or
   directory) must be supplied later.
3. **PMXR2230 regulators**: G2 supplies resolve to PMXR2230 LDO13/LDO23, and
   the referenced Cliffs board overlay uses `L13B`/`L23B`, but the exact
   Linux-side regulator nodes in the selected kernel tree are not yet
   verified. `vdd-supply`/`vdd-io-supply` are therefore intentionally left as
   commented `UNRESOLVED` rather than guessed.
4. **Boot path**: the exact G2 early-boot path (stock ABL vs UEFI vs ROCKNIX
   ABL) is not yet established from device evidence
   (`docs/boot-chain-comparison.md`). `extlinux.conf` is a draft and does not
   claim bootability.
5. **This run performed no hardware test** and no storage write of any kind.

## Model tier

Default DeepSeek V4-Flash (`deepseek/deepseek-v4-flash`) was used for this
run. Pro escalation was not required; the DTS values were already
source-verified and the compile validation completed on the first attempt.

## Next step

Stage B continues when a kernel input set and minimal rootfs are added to
the repository (or supplied to the harness), followed by offline validation
of the complete image before any microSD device test.
