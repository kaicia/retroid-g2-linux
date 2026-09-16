# The official G2 loader: xbl_s_devprg_ns.melf

**Date:** 2026-09-16
**Source:** Retroid Pocket G2 Discord, #retroid-pocket-g2-tech-support,
user moustafa.nl (2026-08-30), who hit this exact failure and was helped by
Retroid support.

## The file

`xbl_s_devprg_ns.melf` — the Qualcomm EDL programmer for the G2, shipped inside
the firmware package Retroid support sends on request.

- `xbl_s_devprg` = XBL secondary dev programmer (the firehose)
- **`_ns` = no-sign** — matches this device's `secure:no` exactly
- `.melf` = multi-segment ELF (QFIL / edl.py `--loader`)

This is the **native G2 loader (SoC ID 700)**, not a cross-SoC substitute. It
removes the derivative-mismatch risk (DDR/UFS/PMIC) that the Moto SM8635 route
carried. It is the correct file to use, and it is obtainable.

## How it is obtained

- **Retroid support sends the firmware package on email request.** moustafa got
  it this way. Name the file when asking.
- **Community members share it by DM.** moustafa DM'd it to another user (e1000)
  in the same thread. Server rules forbid posting copyrighted files in-channel,
  so it moves by DM.

## Our position is better than moustafa's

moustafa flashed a wrong bootloader and was stuck in **900E memory-dump mode**,
which cannot flash, and could not reach **9008**. He had to open the device and
bridge two EDL test points on the mainboard to force 9008.

This device flashed nothing — only `set_active a` in fastbootd. XBL is intact,
so **"Emergency mode" reaches EDL 9008 directly** (`QUSB_BULK_CID:045B`). The
disassembly / test-point step is **not needed here.**

(Worth a quick confirm that our enumeration is 9008 and not 900E; moustafa's
thread describes telling them apart. The QUSB_BULK descriptor with a CID is the
pre-driver 9008 enumeration, so this is very likely already 9008.)

## The plan, updated

1. Obtain `xbl_s_devprg_ns.melf` (Retroid email, or moustafa/community DM).
2. Put it in this repo for verification: it should be an AArch64 ELF whose
   strings name palawan/cliffs/SM8635 and the G2, unsigned.
3. Already in EDL, run the read-only gates then the fix:
   ```
   python edl.py --loader=xbl_s_devprg_ns.melf printgpt --memory=ufs
   python edl.py --loader=xbl_s_devprg_ns.melf getactiveslot --memory=ufs
   python edl.py --loader=xbl_s_devprg_ns.melf setactiveslot b
   ```
   (QFIL works too — it is the tool Retroid's own instructions use with this
   .melf.)
4. If the package also carries `rawprogram*.xml` and the boot images, a full
   flash of the active slot is possible, but is not needed: slot b is intact and
   only the slot pointer is wrong.

This supersedes the Moto/realme substitute route in
`docs/g2-obtainable-firehose-sources.md`, which stays on file as the fallback if
the official package cannot be obtained.
