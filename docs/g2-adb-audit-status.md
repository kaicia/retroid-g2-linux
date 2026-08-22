# G2 ADB Audit Status — 2026-08-22

The authoritative ADB evidence has been reviewed. G2 is identified by its own Cliffs/pineapple DT and boot properties. The SDCC2, pinctrl, PMXR2230, interconnect, OPP and SMMU evidence is retained as G2-specific evidence.

Previous SM8550/SM8650 assumptions are invalidated. Future source mapping must start from exact Cliffs/pineapple strings and hardware blocks.

Next task: exact Cliffs vendor-kernel/source lineage identification, followed by minimum SDCC2 Linux dependency mapping. No bootable DTS or device writes before that verification.
