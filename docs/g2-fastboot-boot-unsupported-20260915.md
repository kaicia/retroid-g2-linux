# `fastboot boot` is not implemented on this bootloader

**Date:** 2026-09-15

```
.\fastboot devices
35a9dd4d         fastboot

.\fastboot boot g2-tier0-fastboot.img
Sending 'boot.img' (41144 KB)          OKAY [  0.895s]
Booting                                FAILED (remote: 'unknown command')
```

Unambiguous, and worth reading carefully: **the transfer succeeded.** ABL
implements `download:`, accepted all 41 MB, and only then rejected `boot`. This
is not a malformed image, a size limit, or a protocol mismatch — the command
simply is not in this bootloader's table. Qualcomm ships ABL with `boot`
removed on plenty of recent targets.

So the image itself remains untested. Nothing is known to be wrong with it.

## Where this leaves the project

Every route that does not write to internal storage is now closed:

| Route | Status |
|---|---|
| SD card, EFI removable-media fallback (Path A) | Closed. Firmware does not enumerate removable media — `g2-path-a-closed-20260915.md` |
| `fastboot boot` | Closed. Command not implemented |

The remaining routes all involve writing to a partition, which crosses the rule
this project has held since the beginning and which is the user's to decide, not
ours. They are recorded here rather than acted on.

### Option 1 — flash the inactive slot

The device is A/B, and Android is currently running from slot **b**
(`ro.boot.slot_suffix = _b`). Slot **a** is the idle copy.

Writing our image to `boot_a` and then `fastboot set_active a` would boot it
without touching anything slot b uses. Recovery is `fastboot set_active b` from
the bootloader — and ABL's own retry logic already does this automatically after
a slot fails to boot several times.

What it costs honestly: slot a stops being a bootable Android until it is
reflashed. It is a spare, not a live system, but it is a real safety net being
spent. And it is a write to internal storage, which is the line this project
drew.

The image would need to keep header v2, since that is what puts our device tree
in front of the kernel; a v4 image in `boot_a` would be paired with the stock
`vendor_boot_a` device tree instead. Whether this ABL will accept a v2 image on
a GKI device is unknown. If it refuses, slot a simply fails to boot and ABL
falls back to slot b — a safe failure.

### Option 2 — Path B, replace ABL

Still the only route to a real SD-card distro, still blocked on the absence of a
Cliffs ABL. `ROCKNIX/abl` publishes no buildable source and Armada's is built
for other silicon. This is a research problem, not a build problem, and it is
larger than everything attempted so far.

## What to collect first, regardless

`fastboot getvar all` is read-only and has still not been captured. It reports
slot state, partition sizes, `has-slot` flags and the bootloader's own version
string — all of which Option 1 needs and none of which we currently have.

```
cmd /c ".\fastboot getvar all > getvar-all.txt 2>&1"
```
