# G2 Read-Only ADB Investigation Checklist

## Purpose

This checklist is for the first direct USB/ADB session with the Retroid Pocket G2 after the offline research phase.

The G2 is the only physical unit available. The checklist therefore intentionally limits the initial session to read-only inspection.

## Safety boundary

During this checklist, do NOT:

- flash or erase any partition
- run `fastboot flash`
- run `dd` with an internal block device as the output
- modify ABL/bootloader
- modify GPT or partition layout
- modify boot, vendor_boot, dtbo, vbmeta or recovery
- run unverified QFIL/EDL programmers
- unlock or relock the bootloader
- format internal storage

If a command could write to the device, stop and review it before execution.

## Session start: USB and ADB

1. Disconnect and reconnect the USB cable.
2. Check ADB enumeration:

```sh
termux-adb devices
```

3. Check basic read-only identity:

```sh
termux-adb shell 'getprop ro.product.model; echo; getprop ro.build.version.release; echo; getprop ro.build.version.incremental'
```

## Android build and firmware identification

Collect, read-only:

```sh
termux-adb shell 'getprop | grep -E "ro.product|ro.build|ro.boot"'
```

Purpose:
- identify exact G2 firmware/build
- correlate the device with any future recovery files
- identify bootloader-related properties without changing them

## Boot configuration

Read only:

```sh
termux-adb shell 'echo "=== cmdline ==="; cat /proc/cmdline; echo; echo "=== bootconfig ==="; cat /proc/bootconfig 2>/dev/null || true'
```

Purpose:
- identify boot arguments
- identify slot/boot configuration information
- identify hints about boot chain without writing anything

## Boot and partition discovery

Read only:

```sh
termux-adb shell 'echo "=== by-name ==="; ls -l /dev/block/by-name 2>/dev/null; echo; echo "=== partitions ==="; cat /proc/partitions'
```

Important: listing block devices is safe; do not write to any of them.

## Device Tree access

Confirm the previously observed paths:

```sh
termux-adb shell 'echo "=== DT ==="; ls -ld /sys/firmware/devicetree/base; echo; echo "=== SDHCI ==="; ls -ld /sys/firmware/devicetree/base/soc/sdhci@8804000 2>/dev/null; echo; echo "=== PINCTRL ==="; ls -ld /sys/firmware/devicetree/base/soc/pinctrl@f000000 2>/dev/null'
```

## MMC / SD discovery

Read only:

```sh
termux-adb shell 'echo "=== MMC host ==="; find /sys/devices/platform/soc/8804000.sdhci/mmc_host -maxdepth 3 -print 2>/dev/null; echo; echo "=== block devices ==="; ls -l /sys/block/mmc* 2>/dev/null'
```

Purpose:
- confirm the SD controller and current MMC device paths after USB reconnect
- detect whether the SD card is still visible under the expected host

## Bootloader / fastboot evidence, read-only first

Do not enter or modify fastboot yet. First collect Android-side evidence:

```sh
termux-adb shell 'getprop | grep -Ei "bootloader|slot|verifiedboot|avb|unlock|secure"'
```

This is only an information-gathering step.

## Recovery/firmware correlation

After collecting the build identity, compare it with the recovery research files before considering any recovery operation.

Required matches:
- exact G2 model
- exact SoC
- exact or compatible firmware/build generation
- matching GPT/partition layout
- G2-specific Firehose/programmer, if EDL is ever considered

## SD-only Linux testing principle

The preferred eventual architecture is:

```text
microSD present -> Linux/SteamOS on microSD
microSD removed -> original Android on internal UFS
```

The initial ADB investigation exists to determine whether this can be achieved without writing to the internal UFS or replacing the stock boot chain.

## After the checklist

1. Save all read-only outputs to the GitHub project.
2. Compare the exact G2 build and boot configuration against Armada/RP5/RP6 boot paths.
3. Determine whether a stock, non-destructive SD boot path exists.
4. Do not escalate to internal writes merely because SD boot has not yet been solved.
