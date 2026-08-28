/* SPDX-License-Identifier: (GPL-2.0-only OR BSD-2-Clause) */
/*
 * Retroid Pocket G2 (Cliffs) interconnect endpoint IDs.
 *
 * This is the minimum, source-verified subset of the public Qualcomm
 * `qcom,cliffs.h` interconnect binding required by the G2 SDCC2 (microSD)
 * node. The values below are the Cliffs vendor flat-namespace IDs, NOT the
 * SM7635/Milos mainline per-NoC IDs and NOT SM8550/SM8650 values.
 *
 * Source lineage (see docs/g2-cliffs-provider-mapping-progress-20260822.md):
 *   - MASTER_SDCC_2      = 47   (G2 raw tuple 0x2f on aggre1_noc)
 *   - SLAVE_EBI1         = 512  (G2 raw tuple 0x200 on mc_virt)
 *   - MASTER_APPSS_PROC  = 2    (G2 raw tuple 0x2 on gem_noc)
 *   - SLAVE_SDCC_2       = 542  (G2 raw tuple 0x21e on cnoc_cfg)
 *
 * Only these four endpoints are proven for the G2 SDCC2 interconnect paths
 * (sdhc-ddr, cpu-sdhc). Remaining Cliffs endpoints are intentionally not
 * invented here; add them only when source- or hardware-verified.
 *
 * Kernel location: include/dt-bindings/interconnect/qcom,cliffs.h
 */

#ifndef __DT_BINDINGS_INTERCONNECT_QCOM_CLIFFS_H
#define __DT_BINDINGS_INTERCONNECT_QCOM_CLIFFS_H

#define MASTER_APPSS_PROC			2
#define MASTER_SDCC_2				47
#define SLAVE_EBI1				512
#define SLAVE_SDCC_2				542

#endif
