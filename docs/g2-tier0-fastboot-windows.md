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

## 3. Enable USB debugging on the G2

Settings → About → tap **Build number** seven times → back → **Developer
options** → **USB debugging** on. Plug the G2 into the PC and accept the
"Allow USB debugging?" prompt on the device.

```
adb devices
```

One device, listed as `device`. If it says `unauthorized`, accept the prompt on
the G2.

## 4. Into the bootloader

```
adb reboot bootloader
```

The screen goes to a fastboot/bootloader screen. Then:

```
fastboot devices
```

If this prints nothing, Windows has not bound a driver to the device in
bootloader mode. Device Manager → the unknown device → Update driver → the
`usb_driver` folder inside platform-tools, or install "Google USB Driver" from
the SDK Manager.

## 5. Capture the bootloader's own information

Do this **before** the boot attempt. It is read-only and it tells us things we
currently have no other way to learn.

```
fastboot getvar all 2> getvar-all.txt
```

The `2>` is not a mistake — fastboot writes this to stderr. Send me
`getvar-all.txt`.

## 6. The attempt

```
fastboot boot g2-tier0-fastboot.img
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
fastboot reboot
```

If it is showing a kernel log, wait for the automatic reboot, or hold power for
about 10 seconds.

Either way Android comes back. Nothing was written.
