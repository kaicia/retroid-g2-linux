# Tier 0 via fastboot — Windows walkthrough

Nothing here writes to the G2. `fastboot boot` loads into RAM and jumps; the
device's storage is not touched. Power-cycle and Android is back exactly as it
was.

**The command to never type is `fastboot flash`.** It is not used anywhere
below.

## 1. Get the tools

Download **SDK Platform-Tools for Windows** from
<https://developer.android.com/tools/releases/platform-tools>. Unzip it
somewhere simple, e.g. `C:\platform-tools`.

Open Command Prompt there:

```
cd C:\platform-tools
```

## 2. Get the image

Download **[`g2-tier0-fastboot.zip`](https://raw.githubusercontent.com/kaicia/retroid-g2-linux/refs/heads/claude/content-analysis-04z778/release/tier0-fastboot/g2-tier0-fastboot.zip)** (15 MB).

Check it, then extract `g2-tier0-fastboot.img` (42 MB) into `C:\platform-tools`:

```
certutil -hashfile g2-tier0-fastboot.zip SHA256
```

```
5d666d5b66b350ec7f50c400cad24d14eda9647fc903bf366f8f9c9a8fd29427
```

## 3. Enable USB debugging on the G2 (optional — see 4b)

Settings → About → tap **Build number** seven times → back → **Developer
options** → **USB debugging** on. Plug the G2 into the PC and accept the
"Allow USB debugging?" prompt on the device.

```
.\adb devices
```

One device, listed as `device`. If it says `unauthorized`, accept the prompt on
the G2.

## 4. Into the bootloader

Two ways in. The second one needs no `adb` at all, so if step 3 gave you any
trouble, go straight to it.

### 4a. From Android

```
.\adb reboot bootloader
```

### 4b. With the buttons — no adb, no USB debugging

1. Power the G2 off completely. Not sleep — hold power, choose **Power off**,
   wait for the screen to go dark.
2. Hold **Volume Down**, keep holding it, and press **Power**.
3. Keep Volume Down held until the bootloader screen appears.
4. Now plug it into the PC.

If Volume Down does nothing, repeat with **Volume Up** — vendors differ on
which one they wire to fastboot.

> **Do not hold Volume Up and Volume Down together while plugging in USB.**
> That is the combination for Qualcomm's emergency download mode (EDL, "9008"),
> a much lower-level state that is not part of this project. It does nothing
> harmful on its own, but you would have to force a reboot to get out of it.

### Either way, then

```
.\fastboot devices
```

One line with a serial number means you are in.

If it prints nothing, Windows has not bound a driver to the device *in
bootloader mode* — this is a separate driver from the one Android uses, so adb
working is no guarantee. Device Manager → the unknown device (often "Android"
with a warning triangle) → Update driver → Browse → the `usb_driver` folder
inside platform-tools. If that folder is not there, install "Google USB Driver"
from Android Studio's SDK Manager, or use a third-party universal ADB driver.

## Troubleshooting `adb`: `no devices/emulators found`

Only relevant if you want route 4a. Route 4b does not need any of this.

```
.\adb devices
```

| Output | Fix |
|---|---|
| Empty list | USB debugging is off, or Windows has no driver, or the cable is charge-only |
| `unauthorized` | Unlock the G2 and accept the "Allow USB debugging?" dialog. Tick "Always allow" |
| `offline` | `.\adb kill-server`, unplug, replug, `.\adb devices` |

Working through the empty-list case, in order of how often it is the answer:

1. **USB debugging really is on?** Settings → About → tap **Build number**
   seven times → back out → **System** → **Developer options** → **USB
   debugging**. The Developer options entry does not exist until those seven
   taps.
2. **The cable carries data?** A great many USB-C cables are charge-only and
   look identical to the ones that are not. Try the cable the device came with,
   or any cable you have successfully moved files with.
3. **The port.** Straight into the PC, not through a hub or a monitor. On a
   desktop, a port on the back.
4. **The driver.** Device Manager with the G2 plugged in: it should appear
   under "Android Device" or similar. A warning triangle means the driver is
   missing — same fix as above.
5. **Restart the server.** `.\adb kill-server` then `.\adb devices`.

## 5. Capture the bootloader's own information

Do this **before** the boot attempt. It is read-only and it tells us things we
currently have no other way to learn.

fastboot writes this to stderr, not stdout, and PowerShell mangles native
stderr redirection. Hand the whole thing to `cmd` and it behaves:

```
cmd /c ".\fastboot getvar all > getvar-all.txt 2>&1"
```

Send me `getvar-all.txt`.

## 6. The attempt

```
.\fastboot boot g2-tier0-fastboot.img
```

It uploads 42 MB — a few seconds — then the screen changes.

### Watch the screen and tell me which of these happened

| What you see | What it means |
|---|---|
| A wall of white-on-black kernel log text (sideways) | **It worked.** Photograph it, especially the last lines |
| Coloured stripes or noise | The kernel ran and drew into the framebuffer, just in the wrong pixel format. Also a win — photograph it |
| Splash stays frozen, device reboots itself after ~60 seconds | The kernel started and panicked, but never got a console. Tell me this happened |
| Black screen, nothing, no reboot | Hold power ~10 s to force off, then power on normally. Android returns |
| `FAILED (remote: 'unknown command')` on the PC | This bootloader has no `fastboot boot`. Send me the exact line |

The log comes out rotated 90°, because the panel is portrait and the device is
held landscape. Tilt your head or the camera.

The log ends in a **panic** — `No working init found`, or a root-filesystem
panic. **That is the goal**, not a failure. There is no operating system on this
image; the whole point is to see the kernel get all the way to the end of its
own startup on this hardware. `panic=60` reboots the device a minute later on
its own.

## 7. Back to normal

If the device is sitting at the bootloader screen:

```
.\fastboot reboot
```

If it is showing a kernel log, wait for the automatic reboot, or hold power for
about 10 seconds.

Either way Android comes back. Nothing was written.
