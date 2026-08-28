/* SPDX-License-Identifier: (GPL-2.0-only OR BSD-2-Clause) */
/*
 * Retroid Pocket G2 (Cliffs) interconnect endpoint IDs — minimum subset.
 *
 * This header carries the source-verified Cliffs vendor flat-namespace
 * interconnect endpoint IDs required by the G2 SDCC2 (microSD) node. These
 * are NOT the SM7635/Milos mainline per-NoC IDs and NOT SM8550/SM8650 values.
 *
 * Source lineage (see docs/g2-cliffs-linux-source-mapping-20260822.md and
 * docs/g2-cliffs-provider-mapping-progress-20260822.md):
 *   - MASTER_SDCC_2     = 47   (0x2f)  -> G2 raw tuple 0x1a2 0x2f (aggre1_noc)
 *   - SLAVE_EBI1        = 512  (0x200) -> G2 raw tuple 0x189 0x200 (mc_virt)
 *   - MASTER_APPSS_PROC = 2    (0x2)   -> G2 raw tuple 0x1a3 0x2   (gem_noc)
 *   - SLAVE_SDCC_2      = 542  (0x21e) -> G2 raw tuple 0x1a4 0x21e (cnoc_cfg)
 *
 * Only these four endpoints are proven for the two G2 SDCC2 interconnect
 * paths ("sdhc-ddr", "cpu-sdhc"). Remaining Cliffs endpoints are intentionally
 * not invented here; add them only when source- or hardware-verified.
 *
 * Kernel install location: include/dt-bindings/interconnect/qcom,cliffs.h
 */

#ifndef __DT_BINDINGS_INTERCONNECT_QCOM_CLIFFS_H
#define __DT_BINDINGS_INTERCONNECT_QCOM_CLIFFS_H

#define MASTER_APPSS_PROC		2
#define MASTER_SDCC_2			47
#define SLAVE_EBI1			512
#define SLAVE_SDCC_2			542

#endif /* __DT_BINDINGS_INTERCONNECT_QCOM_CLIFFS_H */
