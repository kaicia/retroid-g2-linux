# The complete recovery sequence, verified against both sources

Two sources read directly, not quoted from forums: Qualcomm's ABL
(`QcomModulePkg`) and `bkerler/edl`'s `edl.py`.

## The device needs two things changed, not one

`ValidateSlotGuids()` in `PartitionTableUpdate.c` — called by `FindBootableSlot`
on every boot — checks the **UFS boot LUN against the slot**:

```c
GetRootDeviceType (BootDeviceType, BOOT_DEV_NAME_SIZE_MAX);
if (!AsciiStrnCmp (BootDeviceType, "UFS", AsciiStrLen ("UFS"))) {
    GUARD (UfsGetSetBootLun (&UfsBootLun, TRUE));
    if (UfsBootLun == 0x1 && !StrCmp (BootableSlot->Suffix, L"_a")) {
    } else if (UfsBootLun == 0x2 && !StrCmp (BootableSlot->Suffix, L"_b")) {
    } else {
      DEBUG ((EFI_D_ERROR, "Boot lun: %x and BootableSlot: %s do not match\n", ...));
      return EFI_DEVICE_ERROR;
    }
}
```

**LUN 1 ↔ slot a. LUN 2 ↔ slot b.** This device is `variant:SGP UFS`, so the
check applies.

The boot LUN is a **UFS device configuration attribute**, not a GPT field. So
the slot state this device carries lives in two places, and a fix that changes
only the GPT can leave them disagreeing — at which point `ValidateSlotGuids`
returns `EFI_DEVICE_ERROR`, `FindBootableSlot` clears the slot,
`LoadImageAndAuth` fails, and `LinuxLoader.c` does `goto fastboot`.

The device would land in fastboot instead of Android, and it would look like the
fix had failed when it had half worked. **Worth knowing before, not after.**

## `edl.py` has all three commands

From the source, not from a forum post — an earlier note cited `setactiveslot`
from a third-party tips page, and the official README does not list it, so it
needed checking:

```
edl.py getactiveslot [--memory=memtype] [--loader=filename] ...
edl.py setactiveslot <slot> [--loader=filename] ...
edl.py setbootablestoragedrive <lun> [--loader=filename] ...
```

- **`getactiveslot`** — reads the active slot. A better read-only gate than
  `printgpt`: it proves the tool can not only reach the flash but parse this
  device's slot state, which is precisely what the fix depends on.
- **`setactiveslot b`** — rewrites the GPT attribute bits.
- **`setbootablestoragedrive 2`** — sets the UFS boot LUN, the second half.

## The sequence

Everything up to step 3 writes nothing.

```
# 1. read-only: does the loader work on this silicon at all?
python edl.py --loader=<candidate.elf> printgpt --memory=ufs

# 2. read-only: can it parse the slot state?
python edl.py --loader=<candidate.elf> getactiveslot --memory=ufs
#    expect: slot a active — matching what fastboot getvar reports

# 3. the fix
python edl.py --loader=<candidate.elf> setactiveslot b

# 4. confirm, still read-only
python edl.py --loader=<candidate.elf> getactiveslot --memory=ufs

# 5. only if step 4 shows b but the device still lands in fastboot
#    rather than Android — the boot LUN did not follow
python edl.py --loader=<candidate.elf> setbootablestoragedrive 2
```

Step 5 is conditional on purpose. `setactiveslot` may well set the LUN itself;
issuing `setbootablestoragedrive` blindly is a write that may not be needed.
Steps 1, 2 and 4 cost nothing and are the difference between knowing and hoping.

## Still missing

`<candidate.elf>`. Everything else is now established from source on both sides.
