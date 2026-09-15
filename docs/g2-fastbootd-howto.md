# Getting into fastbootd, from the beginning

There are two fastboots on this device and they are different programs.

| | Bootloader fastboot | fastbootd |
|---|---|---|
| Runs in | ABL, before Android exists | Android's recovery ramdisk |
| Screen | green `START` bar, `SECURE BOOT`, `DEVICE STATE` | plain recovery-style list |
| Serial reported | `35a9dd4d` | `MC94528AQF092400414` |
| `getvar is-userspace` | `no` | `yes` |
| `flash` | **unknown command** | the open question |

Everything below is about reaching the second one. Nothing here writes to the
device; the flash step at the end is called out separately.

## Route 1 — from bootloader fastboot

This is the situation after a Volume Down + Power boot.

```
.\fastboot reboot fastboot
```

It answers `OKAY` immediately, then prints `< waiting for any device >` and
**gives up after about 20 seconds**. That timeout is not a failure. Booting the
recovery ramdisk takes longer than fastboot is willing to wait, and the device
appears after the command has already returned.

So ignore the timeout, wait about 30 seconds after the screen changes, and ask
again:

```
.\fastboot devices
.\fastboot getvar is-userspace
```

## Route 2 — buttons only, no PC

1. Power off completely.
2. **Volume Down + Power**, held, until the bootloader screen appears.
3. On that screen, **Volume keys** move between `START`, `Restart bootloader`,
   `Recovery mode`, `Power off`. Select **Recovery mode** and press **Power**.
4. Android recovery loads. If it shows a dead robot and `No command`, press
   **Power + Volume Up** briefly to get the menu.
5. In the recovery menu, choose **Enter fastboot** (Volume keys to move, Power
   to select).

That lands in fastbootd without the PC being involved at all.

## Route 3 — from Android

```
adb reboot fastboot
```

Listed for completeness. `adb` has not been made to work with this device on
this PC, so it is not the route to spend time on.

## Confirming you are actually in fastbootd

Three independent checks, any one of which is enough:

```
.\fastboot getvar is-userspace
```
`yes` means fastbootd. `no` means the bootloader.

```
.\fastboot devices
```
`MC94528AQF092400414` is Android's serial, so it is fastbootd.
`35a9dd4d` is the bootloader's.

The screen: fastbootd shows a plain list in Android's recovery font, with
entries like `Reboot system now`, `Enter recovery`, `Reboot to bootloader`,
`Power off`. It has **no** green `START` bar and **no** `SECURE BOOT` /
`DEVICE STATE` lines - those belong to ABL's screen.

## If the PC cannot see it

fastbootd presents a **different USB interface** from the bootloader's, so the
driver bound for bootloader mode does not carry over. Windows sees a new
unknown device and may bind nothing to it.

Same fix as before, on the new Device Manager entry: Update driver → Browse →
**Let me pick from a list** → **Show All Devices** → **Google, Inc.** →
**Android Bootloader Interface**. Or Zadig → **WinUSB** on that entry.

## Then, and only then, the flash

```
.\fastboot getvar is-userspace          ->  must say yes
.\fastboot flash boot_a g2-tier0-fastboot.img
```

`unknown command` here means this device cannot be written through fastboot at
all, and the approach ends (`g2-fastboot-write-commands-absent-20260915.md`).
`OKAY` means it can, and then:

```
.\fastboot set_active a
.\fastboot reboot
```

## Getting back, from anywhere

```
.\fastboot reboot
```

Or hold **Power for about 10 seconds** to force off, then power on normally.

If slot a has been made active and does not boot: Volume Down + Power into the
bootloader, then

```
.\fastboot set_active b
.\fastboot reboot
```

ABL also reverts to slot b on its own after slot a fails to boot several times.

## One thing to know about fastbootd

It is Android's recovery, so it stays until something reboots it. Selecting an
entry on its menu, or a `fastboot reboot`, leaves it - which is how the device
ended up back on the bootloader screen earlier in this session.
