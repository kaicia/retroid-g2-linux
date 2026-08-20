# Retroid Pocket G2 Read-Only Investigation

## Safety rule

This investigation is intentionally read-only. Do not flash, erase, format, repartition, mount internal partitions read-write, change boot configuration, or modify UFS/bootloader contents.

The script is designed to collect Android properties, block-device metadata, SD/MMC information, Device Tree SDHCI information, pinctrl information, boot partition node presence, filesystem/mount information, and permitted kernel logs.

## Run from Termux

From the cloned repository:

```sh
cd ~/retroid-g2-linux
git pull --ff-only
```

Confirm the G2 is connected:

```sh
ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb devices
```

Push the script to the G2's temporary writable area:

```sh
ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb push scripts/g2-readonly-investigation.sh /data/local/tmp/g2-readonly-investigation.sh
```

Run it through ADB. The output is written to `/sdcard/g2-readonly-investigation.txt` on the G2:

```sh
ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb shell 'sh /data/local/tmp/g2-readonly-investigation.sh /sdcard/g2-readonly-investigation.txt'
```

Pull the result into the repository:

```sh
ANDROID_NO_USE_FWMARK_CLIENT=1 fakeroot termux-adb pull /sdcard/g2-readonly-investigation.txt dumps/g2/g2-readonly-investigation.txt
```

Review only if needed:

```sh
sed -n '1,240p' dumps/g2/g2-readonly-investigation.txt
```

Commit and push:

```sh
git add scripts/g2-readonly-investigation.sh docs/g2-readonly-investigation.md dumps/g2/g2-readonly-investigation.txt
git commit -m "data: save G2 read-only investigation results"
git push origin main
```

## What the script collects

- G2 model, device, Android build and kernel
- `ro.boot.*` and build properties
- `/proc/cmdline` and `/proc/bootconfig` availability
- current A/B slot
- `/dev/block/by-name` metadata
- block-device sizes
- MMC/SD identity and partition nodes
- SD mount points and MMC driver paths
- SDHCI sysfs information
- SDHCI Device Tree properties for `sdhci@8804000`
- `sdc2_on` and `sdc2_off` pinctrl state information
- regulator phandle resolution for the known SDHCI supplies
- presence of boot/UEFI/DTBO/VBMETA/ABL/XBL/recovery partition nodes
- filesystem and mount summaries
- permitted MMC/SDHCI kernel log lines

## Explicitly excluded

The script does not intentionally perform any of the following:

- `dd` writes
- partition flashing
- partition erasure
- filesystem formatting
- repartitioning
- `fastboot flash`
- `fastboot erase`
- modification of A/B slot state
- modification of AVB/vbmeta state
- modification of bootloader configuration
- writes to UFS or bootloader partitions

If a later investigation requires reading the contents of a sensitive partition, that must be a separate, explicitly reviewed step.
