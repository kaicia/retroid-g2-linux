# G2 Hardware Research Task

This file records the initial research task for the Retroid Pocket G2 SteamOS/Linux porting project.

The task is to research public information about the G2 and prepare a safe ADB collection procedure. Do not modify kernel, bootloader, Device Tree, or other implementation code yet.

Required outputs:

1. Public-source research with verified facts clearly separated from assumptions.
2. A practical ADB information-collection plan for a physical G2.
3. `scripts/g2_adb_collect.sh` that safely collects non-private diagnostic information into a timestamped directory under `dumps/g2/` without changing device state.
4. `docs/hardware.md` documenting the research, uncertainties, and the exact information still required from the physical G2.
5. Relevant comparisons with Retroid Pocket 5, Retroid Pocket 6, Odin 3, Armada, and PockNix.

The physical G2 must NOT be connected or modified during this task. No bootloader unlock, flashing, destructive operation, or private user-data collection is allowed.

Before and after changes, check `git status` and `git diff`. Only task-related files may be changed or committed.
