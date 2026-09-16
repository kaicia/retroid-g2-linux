# What the ABL source settles

Read from `QcomModulePkg` — the bootloader this device runs. Four findings, one
of which retracts yesterday's proposal and one of which materially changes the
EDL problem.

## 1. `erase` is compiled out. The proposal is dead.

The command table is not a flat list; it is guarded:

```c
struct FastbootCmdDesc cmd_list[] = {
    {"", NULL},
#ifdef ENABLE_UPDATE_PARTITIONS_CMDS
    {"flash:", CmdFlash},
    {"erase:", CmdErase},
    {"set_active", CmdSetActive},
    {"flashing get_unlock_ability", CmdFlashingGetUnlockAbility},
#endif
#ifdef ENABLE_BOOT_CMD
    {"boot", CmdBoot},
#endif
    {"oem enable-charger-screen", ...},
    ...
#ifdef DYNAMIC_PARTITION_SUPPORT
    {"reboot-recovery", CmdRebootRecovery},
    {"reboot-fastboot", CmdRebootFastboot},
#endif
    {"reboot-bootloader", ...}, {"getvar:", ...}, {"download:", ...},
};
```

`flash`, `set_active` and `flashing get_unlock_ability` were each tested and
each answered `unknown command`. All three live inside
`ENABLE_UPDATE_PARTITIONS_CMDS`. **`erase` is the fourth entry in that same
block**, so it is absent for the same reason. `g2-erase-boot-a-fix.md` is
retracted.

Retroid did not strip commands one by one. They built without that flag.

Trying it costs nothing — `unknown command` changes nothing on the device — but
it should be expected to fail, not hoped to succeed.

## 2. The surviving commands write exactly one thing

What remains: the five `oem` commands, `continue`, `reboot`,
`reboot-recovery`, `reboot-fastboot`, `reboot-bootloader`, `getvar:`,
`download:`.

Of those, the only one that touches storage is `WriteRecoveryMessage()`, called
by `CmdRebootRecovery` and `CmdRebootFastboot`, which writes the bootloader
control block in `misc`. It writes one of two fixed strings. Nothing in the
surviving set can touch a GPT attribute.

## 3. The bootloop has a second cause we had not found

`CmdRebootFastboot` writes `boot-fastboot` into the BCB and reboots.
`RecoveryInit()` in `Recovery.c` then **reads it and does not clear it**:

```c
if (!AsciiStrnCmp (Msg->command, RECOVERY_BOOT_RECOVERY, ...))
    *BootIntoRecovery = TRUE;

if (IsDynamicPartitionSupport () &&
    !AsciiStrnCmp (Msg->command, RECOVERY_BOOT_FASTBOOT, ...))
    *BootIntoRecovery = TRUE;

FreePool (PartitionData);
```

Reads, sets a flag, frees the buffer. No write-back. Clearing the BCB is
Android's job, and Android has not run since.

So every boot since that command has been forced down the recovery path. On a
dynamic-partition device the recovery ramdisk comes from the **active slot's**
boot and init_boot — slot a's — which is the broken pair. `CmdReboot`, the plain
`fastboot reboot`, does not write the BCB at all, so it cannot clear it either.

This is why recovery and fastbootd "stopped working" the moment the slot
changed, and why the device loops instead of landing in fastboot. Fixing the
slot fixes this too: slot b's recovery boots, and recovery clears the BCB.

## 4. Secure boot is genuinely off — and that is the useful one

```c
FastbootPublishVar ("secure", IsSecureBootEnabled () ? "yes" : "no");
```

`secure:no` is not a restatement of the unlock flag. It is
`IsSecureBootEnabled()` — the actual secure-boot state. This device reports
`no`, and the bootloader's own screen says `SECURE BOOT - no`.

**The PBL will accept an unsigned firehose programmer.**

That was previously recorded as promising-but-unconfirmed, with the caveat that
some bootloaders report `secure` from the unlock state. The source removes the
caveat.

It changes the shape of the remaining problem. The requirement was never
"Retroid's signed file" — it is "code that runs on this SoC". Nothing has to be
signed, by anyone.
