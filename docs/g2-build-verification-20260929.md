# Real build verification — SM8635 drivers compile, link & modpost — 2026-09-29

Compiled every ported Cliffs driver + the PMXR2230 regulator patch against a real
kernel tree, catching the API/struct mismatches the offline structural checks
could not. **Result: all four objects build clean; vmlinux links; modpost passes;
all four `.ko` modules build with correct OF device-table aliases.**

## Full-build result (vmlinux + modules)
A complete `make -j4 vmlinux && make -j4 modules` on linux 7.1 (arm64):
- **`make vmlinux` → exit 0** (179 MB vmlinux; `MODPOST vmlinux.symvers`). Every
  built-in (`=y`) framework symbol resolves.
- **`make modules` → exit 0** (`MODPOST Module.symvers`). No undefined-symbol
  warnings for any of our modules — every `EXPORT_SYMBOL` they reference is
  actually exported by the built kernel (the check a per-`.o` compile cannot do).
- Modules built: `gcc-sm8635.ko` (132 KB), `pinctrl-sm8635.ko` (206 KB),
  `icc-sm8635.ko` (380 KB), `qcom-rpmh-regulator.ko` (183 KB).
- **modpost generated the OF aliases that match our DTS compatibles**, so the DTS
  nodes will bind: `qcom,gcc-sm8635`, `qcom,sm8635-tlmm`, the 14
  `qcom,sm8635-*-noc`/`-virt` (28 aliases), and **`qcom,pmxr2230-rpmh-regulators`**
  (so the SDCC2 vmmc/vqmmc rails resolve).

## Target kernel
Built against **linux 7.1** (`v7.1` tag from torvalds, VERSION 7 PATCHLEVEL 1) —
this is holodor's pinned kernel (`KERNEL_VERSION=7.1.2`; a stable point release has
the same struct layout as the `.0` tag). Cross-compiled `ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-`, drivers built as modules against
`arm64 defconfig` + the relevant frameworks.

> Note: the `g2-sdhci-linux-dtc` CI pins a *different* tree (torvalds
> `5225b8e` = **7.3.0-rc2**) only to validate the **DTB**; it does not compile
> kernel C. The drivers target 7.1. The same refactors (below) are present in
> both 7.1 and 7.3-rc2, so the adaptations hold for both.

## Objects built
| object | size | from |
|---|---|---|
| `drivers/clk/qcom/gcc-sm8635.o` | 109 KB | gcc-sm8635.c |
| `drivers/pinctrl/qcom/pinctrl-sm8635.o` | 183 KB | pinctrl-sm8635.c |
| `drivers/interconnect/qcom/icc-sm8635.o` | 352 KB | icc-sm8635.c |
| `drivers/regulator/qcom-rpmh-regulator.o` | 147 KB | + PMXR2230 patch |

## What the compile caught (and the fixes, now in the ports + transform scripts)

The offline ports were written against the **downstream msm-6.1** APIs; mainline
has since refactored several of them. Each fix below is reproducible — folded into
`port_gcc.py` / `port_pinctrl.py` / `port_icc.py`, verified to regenerate the
committed `.c` byte-for-byte.

### gcc-sm8635.c
1. `qcom_cc_really_probe(pdev, …)` → `qcom_cc_really_probe(&pdev->dev, …)`
   (mainline takes `struct device *`).
2. Dropped `gcc_cliffs_sync_state()` + `.sync_state` — `qcom_cc_sync_state` does
   not exist upstream.
3. `clk_branch2_hw_ctl_ops` → `clk_branch2_ops` (×5) — the hw_ctl ops are
   downstream-only; mainline gcc-sm8650 uses `clk_branch2_ops` for the
   `*_hw_ctl_clk` branches.

### pinctrl-sm8635.c
Mainline refactored `struct msm_pingroup` to embed `struct pingroup grp` and
replaced `struct msm_function` with `struct pinfunction` + `MSM_PIN_FUNCTION()`:
1. Dropped the in-file `FUNCTION` macro; call sites → `MSM_PIN_FUNCTION()`.
2. `struct msm_function cliffs_functions[]` → `struct pinfunction`.
3. `PINGROUP`/`UFS_RESET` macros: `.name/.pins/.npins` → `.grp =
   PINCTRL_PINGROUP(...)`.
4. Dropped `.wake_reg`/`.wake_bit` (not in mainline `msm_pingroup`).
5. Dropped `.remove = msm_pinctrl_remove` — not exported upstream; mainline msm
   pinctrl drivers set no `.remove`.

### icc-sm8635.c
Mainline refactored `struct qcom_icc_node`: no `.id` (the id is the provider
array index), and links are **node pointers** in a `link_nodes[]` flexible array,
not numeric ids:
1. Removed every `.id = …`.
2. Converted `.links = { NUMERIC_ID, … }` → `.link_nodes = { &node, … }` using
   the provider arrays' `[ID] = &node` map (169 ids; all resolved).
3. Added forward declarations for all 169 nodes (pointers reference later defs).
4. Removed the 6 downstream PCIe-CRM bcm structs (`bcm_*_pcie_crm_hw_0`, they
   carry the downstream `.crm_node`) and their `&…,` refs in the bcms[] arrays.
5. Removed `.keepalive_early` (not a mainline bcm field).
6. `qcom_icc_rpmh_sync_state` → `icc_sync_state` (framework-generic, as sm8650).

### qcom-rpmh-regulator (PMXR2230 patch)
Compiled clean as written — no changes needed.

## Meaning / limits
- **Proven:** every translation unit compiles against the real 7.1 headers; the
  built-in kernel **links** (vmlinux); and **modpost** resolves every symbol our
  four modules import against the built kernel, with the OF aliases matching the
  DTS compatibles. This is the full build pipeline short of a device.
- **Not proven:** runtime correctness on hardware — register values, the inferred
  non-SD regulator ranges, and an actual SD mount. Those need the device.
- The build tree lives under `.build/` (gitignored); only the verified sources +
  the reproducible transform scripts are committed.

## Reproduce
```
# fetch v7.1, install the 4 drivers + 2 dt-bindings headers, apply the reg patch,
# add Kconfig/Makefile entries, arm64 defconfig + framework configs, then:
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     drivers/clk/qcom/gcc-sm8635.o \
     drivers/pinctrl/qcom/pinctrl-sm8635.o \
     drivers/interconnect/qcom/icc-sm8635.o \
     drivers/regulator/qcom-rpmh-regulator.o
```
