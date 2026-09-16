# Driving the bricked G2 from an Android host over USB-OTG (Termux)

This removes Windows and its fastbootd driver problem from the loop entirely.
The earlier hardware dumps were collected exactly this way, so it is known to
reach this device.

## What this route can do

| Target | Reachable over OTG? | Useful for |
|---|---|---|
| Bootloader fastboot (green START) | yes | reading state only — ABL has no `set_active` |
| **fastbootd** (userspace fastboot) | **if it boots** | **`set_active b` — fixes the brick, no firehose** |
| EDL / 9008 | **no** | needs a firehose + a different tool, not this |

The prize is fastbootd. `set_active` exists there (it is what caused the brick,
so it can reverse it). If fastbootd comes up over OTG, this ends today with one
command and no firehose. If it does not come up, we have learned that cleanly,
without fighting a Windows driver.

## Hardware

- A **second Android phone** as host (any recent one; this is the phone that ran
  the dumps).
- A **USB-C male-to-male cable**, or an OTG adapter + cable. The same cable that
  collected the dumps works.
- The **G2** on its fastboot screen.

## One-time setup on the host phone

Already done if you collected the dumps from this phone — `termux-adb` and
`termux-fastboot` are installed. To install fresh:

1. Install **Termux** and **Termux:API** from **F-Droid** (not the Play Store
   builds — they are too old).
2. In Termux:
   ```
   pkg install -y curl
   curl -s https://raw.githubusercontent.com/nohajc/termux-adb/master/install.sh | bash
   ```
3. Close and reopen Termux so `termux-adb` / `termux-fastboot` are on PATH.

This patches adb and fastboot to reach USB through Android's own USB API, so
**no root** is needed.

## Run it

```
pkg install -y curl
curl -fsSL -o g2rec.sh https://raw.githubusercontent.com/kaicia/retroid-g2-linux/refs/heads/claude/content-analysis-04z778/scripts/termux-g2-recovery.sh
bash g2rec.sh
```

The script:
1. lists the device (you grant the USB permission popup on the host phone),
2. reads `is-userspace` and `current-slot` to say which fastboot you are in,
3. if in the bootloader, sends `reboot fastboot` and waits for fastbootd,
4. in fastbootd, shows slot b is healthy and asks before running
   `set_active b`.

It never writes on its own — the only write is `set_active b`, and it asks
first.

## Doing it by hand instead

```
# device on the fastboot screen, cable in
termux-fastboot devices
termux-fastboot getvar is-userspace          # no = bootloader, yes = fastbootd

# from the bootloader, reach fastbootd:
termux-fastboot reboot fastboot
#   wait ~40s; the command may say "waiting for device" and give up — normal
termux-fastboot getvar is-userspace          # want: yes

# in fastbootd (is-userspace: yes):
termux-fastboot getvar current-slot          # shows a
termux-fastboot set_active b
termux-fastboot getvar current-slot          # want: b
termux-fastboot reboot
```

If `termux-fastboot` needs `fakeroot` on your setup (as the dump script used):
```
ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-fastboot <args>
```

## Why fastbootd might not come up — and what it means

fastbootd runs from the recovery ramdisk, which is loaded from the **active
slot** — slot a, the broken one. If slot a's kernel is what fails (the bootloop
never reached USB, which points that way), fastbootd will not start over OTG
either, and the script will say so and stop. That is not a failure of this
method; it is the same slot-a breakage, and it means the firehose/EDL route is
the one that is left.

But it costs one cable and a few commands to find out, it needs no Windows
driver, and if it works it is over.

---

## Result 2026-09-16: fastbootd does not come up

`termux-fastboot reboot fastboot` over OTG left the device cycling — vendor logo,
then reboot, repeating — and never presented fastbootd. This is the failure mode
flagged above: the recovery ramdisk is loaded from the active slot (a), slot a is
broken, so fastbootd cannot start any more than Android can.

That closes the last self-service route. Every path to changing the slot goes
through the active slot, which is broken:

- ABL fastboot: no `set_active` (confirmed from source)
- fastbootd `set_active b`: fastbootd will not boot (confirmed here)
- A/B auto-fallback: never fires (`slot-successful:a`)
- recovery: loads from slot a, will not boot

The only remaining channel that writes storage independently of the boot slot is
**EDL + a firehose**, because EDL is a different protocol handled by the PBL in
mask ROM, not by anything on the broken slot. That is now the sole route, and it
needs an SM8635/palawan `prog_firehose_ddr.elf`.

To stop the loop: hold power ~15s, then Volume Down + Power into the bootloader,
which is stable. Nothing is damaged; only the slot pointer is wrong.
