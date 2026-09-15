# What `fastboot getvar all` told us

**Date:** 2026-09-15
**Raw output:** `dumps/g2/g2-fastboot-getvar-20260915.txt`

Five things in here matter. Two of them change decisions already made.

## 1. Slot a is already marked unbootable

```
current-slot:b
slot-count:2
slot-retry-count:b:6   slot-unbootable:b:no    slot-successful:b:yes
slot-retry-count:a:6   slot-unbootable:a:yes   slot-successful:a:yes
```

`g2-fastboot-boot-unsupported-20260915.md` described flashing slot a as
spending "a real safety net". **That was wrong, and it was my framing, so it
gets corrected here rather than quietly.** The bootloader already refuses to
boot slot a — `unbootable:yes` is priority 0 in the slot metadata, and ABL will
not select it. Whatever is in those partitions, it is not a fallback the device
would ever fall back to today.

What this does *not* establish is whether slot a holds a working Android image
at all. `unbootable` is metadata, not content, and fastboot has no read command
to check with. So: flashing `boot_a` costs a slot the device already will not
boot. It does not cost a working backup, because there is no evidence one is
there — and no evidence there is not.

`fastboot set_active a` clears the unbootable flag and resets the retry count,
so the flag itself is not an obstacle.

## 2. `secure:no`

```
secure:no
unlocked:yes
```

Per the fastboot protocol, `secure` reports whether the bootloader requires a
signature before it will install or boot an image. `no` means unsigned images
are accepted.

This matters for **Path B**, not for anything nearer. The recorded blocker on
replacing `abl` has been that no Cliffs ABL exists to build — `ROCKNIX/abl`
publishes no buildable source and Armada's targets other silicon. That blocker
is unchanged. But the *other* thing one would expect to block Path B on a
production device — needing an OEM signature the bootloader will accept — looks
like it is not in the way. Worth knowing before that research starts.

Treat this as promising rather than settled: some bootloaders report `secure`
from the unlock state rather than from the fuses.

## 3. The UEFI is real, and separate from `abl`

```
kernel:uefi
partition-size:uefi_a: 0x500000        (5 MiB)
partition-size:abl_a:  0x100000        (1 MiB)
partition-size:uefivarstore: 0x80000
```

`uefi` and `abl` are distinct partitions: the UEFI firmware proper, and the
Android boot application that runs on top of it. There is even a persistent
UEFI variable store.

So Path A did not fail because "there is no UEFI". There is a full one. It
failed because its boot manager goes straight to `abl` and never enumerates
removable media — and there is no ESP anywhere in this partition table for it to
enumerate on internal storage either. Nothing here reopens Path A: setting a
`Boot####` variable requires already executing inside UEFI, which is the thing
we cannot do.

## 4. Sizes, for whenever an image does get flashed

| Partition | Size | Our image |
|---|---|---|
| `boot_a` / `boot_b` | `0x6000000` = 100 MiB | 42,131,456 B — fits with room over |
| `init_boot_a` | `0x800000` = 8 MiB | |
| `vendor_boot_a` | `0x6000000` = 100 MiB | |
| `dtbo_a` | `0x2000000` = 32 MiB | |
| `abl_a` | `0x100000` = 1 MiB | |

`max-download-size:805306368` — 768 MiB, so transfer size is not a constraint
on anything we would send.

## 5. Board identity, confirmed again

```
product:pineapple
variant:SGP UFS
hw-revision:10000
```

`hw-revision` `0x10000` is the second cell of `qcom,msm-id = <0x2bc 0x10000>`
in `dts/cliffs-g2.dts`, and `SGP` is the `SGP_LAMMA` chip_id from the device
dump. The board identification in our device tree is consistent with what the
bootloader itself reports.

## Unchanged

No `boot` command. `is-userspace:no`, so this is bootloader fastboot rather than
fastbootd; fastbootd would not have helped, it has fewer commands, not more.
`version-bootloader` is empty, so there is still no ABL version string to
match against anything.
