# This bootloader's fastboot cannot write

**Date:** 2026-09-15

```
.\fastboot flash boot_a g2-tier0-fastboot.img
Sending 'boot_a' (41144 KB)     OKAY [  0.932s]
Writing 'boot_a'                FAILED (remote: 'unknown command')
```

Same shape as the `boot` attempt: the 41 MB transfer succeeds, and the command
that would *do* something is refused.

So the command table looks like this:

| Command | State |
|---|---|
| `getvar` | works |
| `download:` | works — 41 MB accepted twice |
| `reboot` | works |
| `boot` | unknown command |
| `flash` | unknown command |

Both write paths in this session's plan went through `flash`. Step 1 (flash
`boot_a`) and step 2 (flash a custom `abl_a`) are blocked by the same missing
command, so the plan in `g2-fastboot-boot-unsupported-20260915.md` does not
survive contact and is superseded by this document.

## This sits oddly against what the bootloader reports

```
unlocked:yes
secure:no
parallel-download-flash:yes
```

A bootloader that advertises unlocked, unsigned-image-friendly and
parallel-download-flash, and then refuses `flash`, is not in a state any of
those three variables describe. The likeliest reading is that the vendor
stripped the write commands from ABL's table while leaving the reporting
untouched — vendors do this to keep their own factory tooling working over a
different channel while closing fastboot to everyone else.

Worth noting alongside: the Android dump has `sys.oem_unlock_allowed = 0` while
`ro.oem_unlock_supported = 1`. The OEM-unlocking toggle in developer options is
off, even though the bootloader reports itself unlocked. These are separate
mechanisms, but it is a second place where this device's unlock state is not the
straightforward thing `unlocked:yes` suggests.

## What has not been ruled out

**`fastbootd` — userspace fastboot.** `getvar all` reported `is-userspace:no`,
meaning the fastboot we have been talking to is the bootloader's. Android also
ships a second one, running from the recovery ramdisk, reached with
`fastboot reboot fastboot`. It is a different implementation with a different
command table, and on modern devices it is the one that handles flashing.

Earlier this document set said fastbootd "has fewer commands, not more" - that
was about logical-partition support and was the wrong thing to say here. It is a
separate implementation, and whether it can write when ABL's cannot is an open
question, answerable with one safe command.

**OEM commands.** `fastboot oem device-info` and
`fastboot flashing get_unlock_ability` are read-only and have not been tried.
Neither writes anything; both may explain the contradiction above.

## Probe results

```
.\fastboot oem device-info
(bootloader) Verity mode: true
(bootloader) Device unlocked: true
(bootloader) Device critical unlocked: true
(bootloader) Charger screen enabled: false

.\fastboot flashing get_unlock_ability
FAILED (remote: 'unknown command')

.\fastboot reboot fastboot
Rebooting into fastboot     OKAY [  0.003s]
< waiting for any device >
Finished. Total time: 20.265s
```

**`Device critical unlocked: true`.** That is the `flashing unlock_critical`
state - the level that permits writing bootloader partitions, not just the
Android ones. So the device is unlocked at *both* levels and still refuses
`flash`. Combined with the `flashing` command family also being absent, the
"vendor stripped the write commands" reading above is now the only one left
standing: there is no lock state this device could be in that would explain it,
because it is already in the most permissive one.

**`reboot fastboot` was accepted.** ABL answered OKAY and the device rebooted.
What did not happen is the device reappearing on USB - fastboot waited 20
seconds for any device and gave up.

That is very likely a driver problem rather than a missing mode. Userspace
fastboot presents a *different* USB interface from the bootloader's, so the
driver bound for bootloader mode does not carry over; Windows sees a new
unknown device and binds nothing. Exactly the same situation as the first time,
needing exactly the same fix, on a new Device Manager entry.

So the open question is unchanged and still open: the device may well be sitting
in fastbootd right now, invisible to the PC.

## Probes, in order, none of which write

```
.\fastboot oem device-info
.\fastboot flashing get_unlock_ability
.\fastboot reboot fastboot
```

After the third, `.\fastboot devices` should show the device as `fastbootd`
rather than `fastboot`, and `.\fastboot getvar is-userspace` should answer
`yes`. If it does, the flash attempt is worth repeating there. `fastboot reboot`
returns to Android from either mode.

## If fastbootd cannot write either

Then this device cannot be modified through fastboot at all, and the only
remaining channel is EDL with a firehose programmer — which is OEM-signed, which
we do not have, and which is the one place where a mistake is not recoverable
with the tools in this room.

That would be the end of the line for this approach, and the honest thing to
record rather than to work around.
