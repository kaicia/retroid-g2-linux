# `fastboot erase boot_a` — proposed, then disproved

> **RETRACTED 2026-09-16, before anyone acted on it.** The command-table
> registration settles it: `erase` is compiled out of this build alongside the
> commands we already confirmed absent. The mechanism below is real and
> correctly read; it is simply not reachable here. Kept because the reasoning
> is what led to the findings in `g2-abl-source-findings.md`, and because a
> retraction is worth more than a deleted file.


Found by reading Qualcomm's ABL source — `QcomModulePkg`, the bootloader this
device runs. Every quote below is from that source.

## Why the device is stuck, exactly

`FindBootableSlot()` in `PartitionTableUpdate.c`:

```c
if (Unbootable == 0 && BootSuccess == 1) {
    /* Active Slot is bootable */                    <-- slot a lands here
} else if (Unbootable == 0 && BootSuccess == 0 && RetryCount > 0) {
    RetryCount--;                                    /* count down */
    UpdatePartitionAttributes (PARTITION_ATTRIBUTES);
} else {
    GUARD_OUT (HandleActiveSlotUnbootable ());       <-- the escape hatch
}
```

Slot a is `Unbootable=0, Success=1`, so it takes the **first** branch forever.
No countdown, no fallback. That is why waiting does nothing.

`HandleActiveSlotUnbootable()` is what we need to reach:

```c
/* Mark current Slot as unbootable */
BootEntry->PartEntry.Attributes |= (PART_ATT_UNBOOTABLE_VAL) & (~PART_ATT_SUCCESSFUL_VAL);
UpdatePartitionAttributes (PARTITION_ATTRIBUTES);
...
/* Validate Alternate Slot is bootable */
if (Unbootable == 0 && BootSuccess == 1) {
    GUARD (SetActiveSlot (AlternateSlot, FALSE));
    gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
}
```

It marks slot a bad, checks the alternate slot, switches, and cold-resets. Slot
b is `slot-unbootable:b: no` and `slot-successful:b: yes` — **it passes that
check exactly.** Reach this function and the device repairs itself and boots
Android.

## The reachable trigger

`CmdErase()` in `FastbootCmds.c`, after erasing:

```c
if (MultiSlotBoot && HasSlot &&
    !(StrnCmp (PartitionName, L"boot", StrLen (L"boot"))))
  FastbootUpdateAttr (SlotSuffix);
```

Erasing a partition whose name begins with `boot`, on a multi-slot device,
calls `FastbootUpdateAttr()`:

```c
Ptn_Entries_Ptr->PartEntry.Attributes &=
    (~PART_ATT_SUCCESSFUL_VAL & ~PART_ATT_UNBOOTABLE_VAL);
Ptn_Entries_Ptr->PartEntry.Attributes |=
    (PART_ATT_PRIORITY_VAL | PART_ATT_MAX_RETRY_COUNT_VAL);
UpdatePartitionAttributes (PARTITION_ATTRIBUTES);
```

That clears `SUCCESSFUL` on slot a and sets its retry count to the maximum.
Slot a then satisfies `Unbootable == 0 && BootSuccess == 0 && RetryCount > 0` —
the **second** branch — so every subsequent boot decrements the counter. When it
reaches zero, the `else` branch runs, and the bootloader fixes itself.

`has-slot:boot:yes` on this device, so `MultiSlotBoot` holds. `boot_a` begins
with `boot` and carries a slot suffix, so both other conditions hold.

## The procedure

**`erase` has never been tested on this bootloader.** `flash`, `boot`,
`set_active` and `flashing` were all removed; `erase` is a separate table entry
(`{"erase:", CmdErase}`) and may have survived. One command settles it.

In bootloader fastboot:

```
.\fastboot erase boot_a
```

> **Never `boot_b`.** `boot_b` is the working Android. Erasing it destroys the
> one intact copy on the device and there is no way back from that here. Check
> the letter before pressing Enter.

Erasing `boot_a` costs nothing: slot a already cannot boot, and destroying it is
precisely what arms the fallback.

Then, repeatedly:

```
.\fastboot reboot
```

Each boot decrements the counter and lands back in fastboot (with `boot_a`
erased, `LoadImageAndAuth` fails and `LinuxLoader.c` does `goto fastboot`
rather than rebooting). Watch it fall:

```
.\fastboot getvar slot-retry-count:a
```

`6 → 5 → 4 → 3 → 2 → 1 → 0`. At zero the next boot takes the `else` branch,
switches to slot b, cold-resets, and **Android comes back**.

Confirm at any point with:

```
.\fastboot getvar current-slot
```

## If `erase` is also absent

Then ABL has no write path at all and this route closes with nothing lost —
`unknown command` changes nothing on the device. EDL with a programmer remains,
and the code above still pays off: it tells us the minimal write is a single
GPT attribute bit on `boot_a`'s partition entry, not a firmware flash.
