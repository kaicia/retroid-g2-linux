# G2 vs public Cliffs DTS comparison

Date: 2026-08-20

## Scope

This is a source-based comparison between the Retroid Pocket G2 Android Device Tree collected from the device and the public Qualcomm/Cliffs DTS source `LineageOS/android_kernel_qcom_sm8650-devicetrees`, specifically `qcom/cliffs-mtp.dtsi` at commit `4e146886d41b4de80f17ae1f5e19ed0839012136`.

This document does **not** claim that the reference board is the Retroid Pocket G2. Matching properties are treated only as evidence that the Linux-side structure may be reusable.

## Direct matches / strong correspondence

| Item | G2 Android DT evidence | Public Cliffs DTS | Assessment |
|---|---|---|---|
| Platform identity | DT root compatible contains `qcom,cliffs-mtp`, `qcom,cliffs`, `qcom,cliffsp-mtp`, `qcom,cliffsp`, `qcom,mtp` | File is named `cliffs-mtp.dtsi` and targets Cliffs MTP | STRONG MATCH, but not proof of same board |
| SD controller | `/soc/sdhci@8804000` | `&sdhc_2` overlay target | MATCH by controller instance/address context |
| SDHCI compatible | `qcom,sdhci-msm-v5` | Cliffs DTS uses the same SDHCI block through `&sdhc_2` | MATCH with G2 evidence and public Pineapple-family references |
| SD bus | `bus-width = 4` | Cliffs overlay leaves controller bus configuration to base DTS; no conflicting value shown here | COMPATIBLE, not independently proven identical |
| SD status | G2 status is `ok` | `status = "ok"` | DIRECT MATCH |
| SD regulators | G2 resolves `vdd` to PMXR2230 LDO13 and `vdd-io` to LDO23 | `vdd-supply = <&L13B>` and `vdd-io-supply = <&L23B>` | STRONG MATCH at regulator-role level; exact PMIC phandle mapping must still be checked |
| Pinctrl states | G2 has `sdc2_on` / `sdc2_off`, referenced by `pinctrl-0/1` | `pinctrl-names = "default", "sleep"`; `pinctrl-0 = <&sdc2_on>`; `pinctrl-1 = <&sdc2_off>` | DIRECT STRUCTURAL MATCH |
| SD detect | G2 CD GPIO is GPIO31 | `cd-gpios = <&tlmm 31 GPIO_ACTIVE_LOW>` | STRONG MATCH, including GPIO number; polarity is now supported by public source |

## G2 values that need exact Linux-side translation

The G2 DT exposes the following SDHCI properties:

- `clock-names`
- `clocks`
- `interrupt-names`
- `interrupts`
- `iommus`
- `interconnect-names`
- `interconnects`
- `operating-points-v2`
- `qcom,dll-hsr-list`
- `qcom,iommu-dma`
- `qcom,iommu-dma-addr-pool`
- `qcom,iommu-geometry`
- `qcom,restore-after-cx-collapse`
- `qcom,vdd-current-level`
- `qcom,vdd-io-current-level`
- `qcom,vdd-io-voltage-level`
- `qcom,vdd-voltage-level`
- `resets` / `reset-names`

These must be mapped against the actual Linux kernel version and binding used for the G2 target. They must not be copied blindly from another device.

## Important public-source observation

The public `cliffs-mtp.dtsi` contains an SDHCI overlay with:

```dts
&sdhc_2 {
    status = "ok";
    vdd-supply = <&L13B>;
    qcom,vdd-voltage-level = <2960000 2960000>;
    qcom,vdd-current-level = <0 800000>;
    vdd-io-supply = <&L23B>;
    qcom,vdd-io-voltage-level = <1800000 2960000>;
    qcom,vdd-io-current-level = <0 22000>;
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <&sdc2_on>;
    pinctrl-1 = <&sdc2_off>;
    cd-gpios = <&tlmm 31 GPIO_ACTIVE_LOW>;
};
```

This is unusually close to the G2 Android DT evidence already collected: same SD controller role, same `sdc2_on/off` naming, same CD GPIO number, and the same L13/L23 regulator roles.

However, the public file also contains many board-specific nodes (UFS, touchscreen, PMIC, LEDs, charger, etc.). Those are **not** to be imported into the G2 DT without independent evidence.

## Current conclusion

The evidence has moved the G2 DT effort from "generic Qualcomm guess" to a **Cliffs-specific Linux DTS adaptation**. The SDHCI portion has several strong correspondences with public Cliffs source.

This still does **not** establish that a bootable G2 DTB can be produced yet. Remaining blockers include:

1. Identify the exact Linux kernel tree/version compatible with G2's `6.1.115-android14-11` Qualcomm platform.
2. Resolve the base `sdhc_2` node and all required clock/reset/interrupt/IOMMU/interconnect phandles.
3. Confirm the G2 PMXR2230 regulator mapping in Linux DTS.
4. Determine the correct G2 memory/CPU/chosen/firmware nodes needed for a Linux boot.
5. Build and validate the DTS/DTB completely offline before any SD boot attempt.

## Safety rule

No G2 UFS/boot partition is to be modified as part of this comparison. The comparison and DTS drafting are analysis-only.
