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

Not a bug in this bootloader after all. **`slot-successful:a: yes`.**

In the A/B scheme, `successful_boot` means a slot has already been validated by
a userspace that booted from it and called `markBootSuccessful`. A bootloader
does not run down the retry counter on a slot flagged that way — it has been
told the slot is known-good, so it keeps booting it rather than counting
failures toward a fallback. The retry counter is for slots that are *being
tried*, not for slots already proven.

So `slot-retry-count:a` staying at 6 across repeated real boot attempts is the
specified behaviour, not a missing feature. **Waiting will never fix this**, no
matter how many times the device loops.

It also means slot a is not blank. A slot only carries `successful_boot` if
something once booted from it and reached userspace — almost certainly the
factory image, before an OTA moved the device to slot b.

### Which points at recovery

`super` is **not slotted** on this device (`has-slot:system: no`) - one shared
`super` holding the current system. So slot a's older `boot_a` / `init_boot_a` /
`vendor_boot_a` are paired with a `super` they do not match, and Android cannot
come up. That is a complete explanation of the bootloop that does not require
slot a to be empty.

**Recovery does not mount `super`.** It is self-contained: kernel plus recovery
ramdisk. `recovery_a` is a real partition here, 0x6400000 = 100 MiB, and the
device is A/B with dedicated recovery partitions rather than the GKI
recovery-in-boot arrangement.

So an older-but-intact `recovery_a` should still boot even though Android from
the same slot cannot. If it does, its menu offers **Enter fastboot** -> fastbootd
-> `set_active b`, and this ends.

Two traps worth naming, because either one reads as "recovery is broken" when
it is not:

- The **dead Android robot with `No command`** *is* recovery, waiting. The menu
  appears on **Power + Volume Up**.
- Recovery takes considerably longer to appear than the bootloader does.

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

### Searched, and closed

| Source | Result |
|---|---|
| Another device with the same SoC | **The Retroid Pocket G2 is the only handheld using the Snapdragon G2 Gen 2.** There is no sibling device to take a programmer from |
| Public firehose collections (bkerler/edl, Samsung EDL loader sets, Hovatek) | Nothing for this SoC |
| ROCKNIX | No G2 device page. `rocknix.org` is blocked by this environment's egress policy, so this rests on search results rather than a direct read |
| GammaOS / GammaOS Next | Covers RP4 Pro, RP Classic, AYANEO Pocket Micro. No G2 |
| `TheGammaSqueeze/Retroid_Pocket_Stock_Firmware` | Pocket Mini and Pocket 5 only, SM8250 programmer |

Loading a programmer built for a different SoC is not a fallback. A firehose
initialises that SoC's DDR and UFS controllers; on the wrong silicon it cannot
work, and it is not a harmless failure to attempt.

### Where the G2 firehose would come from

Nowhere public. The Retroid Handhelds wiki's Firmware page - the most likely
location, and the one this environment's egress policy blocked us from reading -
was checked directly and **has no G2 entry.** Nor does anything else searched:
no reposted Drive or MEGA link, no Reddit thread, no Chinese 9008 community
collection.

That leaves Retroid themselves, through support or the Discord. It is a request
vendors field routinely, and the device is recent enough to be in warranty.

Only the programmer is strictly needed - not a full firmware package. With a
working `prog_*firehose*.elf`, fixing the GPT slot attributes back to b is
enough; the Android in slot b is intact and would boot.

## Where this stands

Two things remain, and they are not equivalent.

**Recovery.** Untested, free, and the only route that needs nobody's
cooperation. `recovery_a` is an independent 100 MiB partition that does not
depend on `super`, so ABL failing to boot slot a's Android says nothing about
whether it can boot slot a's recovery. If recovery starts, its menu reaches
fastbootd, where `set_active` works.

The USB silence during the bootloop turned out to be the useful instrument
here. No enumeration across the whole loop means the kernel never reaches the
USB gadget - so Android from slot a genuinely does not start, and no amount of
polling for adb will catch it. But recovery runs adbd, so **if recovery boots,
the PC enumerates and chimes.** That converts an ambiguous screen-watching
exercise into a yes/no signal.

**The firehose.** Everything else. Exhausted as above.

## Exhausted

| Route | Outcome |
|---|---|
| SD card, EFI removable-media fallback | Firmware does not enumerate removable media |
| `fastboot boot` | Command absent |
| `fastboot flash` / `set_active` / `flashing` | Commands absent; ABL's fastboot is read-only |
| `oem` namespace | Only `device-info`; `oem help` and `oem ?` both absent |
| Waiting for A/B fallback | Will never fire - `slot-successful:a: yes` |
| adb during the bootloop | Kernel never reaches USB; nothing to catch |
| A sibling device's firehose | The G2 is the only handheld with this SoC |
| Public firehose collections | Nothing for this silicon |
| ROCKNIX / GammaOS / community firmware / the Retroid wiki | No G2 |

## The SoC has a public name after all

Worth recording separately, because this project has carried it as an open
unknown since `g2-cliffs-port-estimate-20260914.md` and once had a wrong answer
in it.

The Retroid Pocket G2's chip is the **Snapdragon G2 Gen 2**, a part built for
gaming handhelds rather than a rebadged phone SoC. Its published CPU
configuration is 1x prime at 2.8 GHz, 4x performance at 2.57 GHz, 3x efficiency
at 1.9 GHz.

That is exactly the topology in `dts/cliffs.dtsi`: one Cortex-X4, four
Cortex-A720, three Cortex-A520, in three clusters. It also matches
`ro.boot.hardware.revision = "Qualcomm G2 Gen 2"` from the device dump, which we
had read as a marketing string rather than as the part name.

So: `qcom,msm-id` 0x2bc / SoC ID 700 / `SGP_LAMMA` / Cliffs-derivative **is**
the Snapdragon G2 Gen 2. The earlier SM7675 / Snapdragon 7+ Gen 3 guess stays
retracted; this replaces it.

The practical consequence here is narrow: the G2 Gen 2 ships in very few
devices, so a firehose programmer for it is unlikely to be circulating outside
Retroid.

## Untested surface in ABL

Two things, both cheap, neither yet tried:

- ~~`fastboot oem help` / `fastboot oem ?`~~ — both answer `unknown command`.
  Only `oem device-info` exists. ABL's surface is now fully mapped and contains
  nothing that writes.
- The bootloader menu's full list of entries. Only `START` has been read off
  the screen so far.
- `fastboot reboot fastboot` on the current state. This is the one command ABL
  is *known* to accept and act on — it is how fastbootd was reached the first
  time. Whether it still gets there now that slot a is active depends on
  whether ABL takes the recovery image from the active slot, which we have
  assumed but not established. It costs nothing and, if it works even once,
  `set_active b` ends this immediately.

## Lesson for this project

`set_active` was in a command sequence conditioned on the preceding `flash`
returning `OKAY`. The condition was stated but not enforced, and a conditional
buried in a list is not a safeguard. A step that changes which slot the device
boots from should have been given on its own, after its precondition was
confirmed, and never as line three of a block to paste.
