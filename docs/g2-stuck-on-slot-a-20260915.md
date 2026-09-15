# Stuck on slot a, with no write channel

**Date:** 2026-09-15
**Status:** device does not boot Android; bootloader is healthy and reachable.

## What happened

`fastboot set_active a` succeeded — in **fastbootd**, during the window when
userspace fastboot was reachable. ABL's own fastboot has `set_active` stripped,
which is why the same command now fails.

The device was then left pointing at slot a, which holds no bootable Android.
That single change explains everything that followed:

- Android does not boot — nothing bootable in slot a
- recovery and fastbootd no longer load — their images come from the active
  slot too
- continuous reboots — ABL retrying slot a

Verified state in the bootloader:

```
current-slot: a
slot-unbootable:a: no        (was yes before the change)
slot-retry-count:a: 6        (does not decrease across real boot attempts)
slot-unbootable:b: no
slot-retry-count:b: 6
slot-successful:b: yes
```

**Slot b is untouched and healthy.** No partition was written: `flash`, `boot`
and `set_active` are all absent from ABL, and every attempt against them was
refused. The Android installation is intact and waiting.

## Why it does not recover itself

A/B is supposed to handle exactly this: ABL decrements `slot-retry-count` on
each failed boot and falls back once it reaches zero. On this device the count
stays at 6 across repeated real boot attempts, so **the automatic fallback is
not functioning**. That is consistent with the rest of what this bootloader
turned out to be — the write half of fastboot is gone, and the slot-retry
machinery appears to be as well.

## Why it cannot be fixed from the bootloader

On Qualcomm devices the A/B slot state lives in the **GPT partition attribute
bits**, not in `misc`. Changing it means writing the GPT, and the bootloader
offers no command that writes anything.

## What is left

**EDL (9008) with QFIL and a firehose programmer.** This is the established
recovery route for Retroid's Qualcomm handhelds — `TheGammaSqueeze/Retroid_Pocket_Stock_Firmware`
documents it for the Pocket Mini and Pocket 5, using `QFILHelper.exe` and
`prog_ufs_firehose_sm8250_lite_lp5.elf`, storage type UFS.

That specific programmer **will not work here.** It targets SM8250; the G2 is
Cliffs (`qcom,msm-id` 0x2bc, `SGP_LAMMA`). A firehose runs on the SoC it was
built for. The G2 needs its own.

Entry combination for Retroid devices: **Power + Volume Up + Volume Down**, held
together.

One thing in our favour: the device reports `SECURE BOOT - no` on its own
bootloader screen and `secure:no` over fastboot. If that reflects the fuses
rather than the unlock state, EDL's Sahara stage will accept an unsigned
programmer, which is the difference between "needs the OEM's file" and "needs
any correct file".

### Where the G2 firehose would come from

No public G2 firmware package was found. `wiki.retroidhandhelds.com` is blocked
by this environment's network egress policy and could not be checked from here;
it is the most likely place for it and should be checked directly.

Otherwise: Retroid support, or the Retroid Handhelds Discord. The device is
recent enough to be in warranty, and this is a request vendors field routinely.

## Untested surface in ABL

Two things, both cheap, neither yet tried:

- `fastboot oem help` / `fastboot oem ?` — `oem device-info` works, so the
  `oem` namespace exists. Whether it contains anything that writes is unknown.
  **No other `oem` command should be run blind**: vendor `oem` namespaces
  contain erase and format operations that are not distinguishable by name.
- The bootloader menu's full list of entries. Only `START` has been read off
  the screen so far.

## Lesson for this project

`set_active` was in a command sequence conditioned on the preceding `flash`
returning `OKAY`. The condition was stated but not enforced, and a conditional
buried in a list is not a safeguard. A step that changes which slot the device
boots from should have been given on its own, after its precondition was
confirmed, and never as line three of a block to paste.
