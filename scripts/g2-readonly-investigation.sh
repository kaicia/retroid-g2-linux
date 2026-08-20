#!/system/bin/sh
# Retroid Pocket G2 read-only investigation
# SAFETY: This script must not modify UFS, bootloader, partitions, filesystems, or boot configuration.

OUT="${1:-/sdcard/g2-readonly-investigation.txt}"
exec >"$OUT" 2>&1

section() { echo; echo "===== $1 ====="; }

section "IDENTITY"
getprop ro.product.model
getprop ro.product.device
getprop ro.build.fingerprint
getprop ro.build.id
getprop ro.build.version.incremental
getprop ro.build.version.release
uname -a

section "BOOT PROPERTIES"
getprop | grep -E '^\[ro.boot\.|^\[ro.bootloader|^\[ro.bootimage|^\[ro.build.version' || true

section "CMDLINE / BOOTCONFIG"
cat /proc/cmdline 2>&1 || true
if [ -r /proc/bootconfig ]; then cat /proc/bootconfig; else echo "bootconfig unavailable"; fi

section "CURRENT SLOT"
getprop ro.boot.slot_suffix
getprop ro.boot.slot

section "BY-NAME BLOCK DEVICES"
ls -l /dev/block/by-name 2>&1 || true

section "BLOCK DEVICE SIZES"
for d in /sys/class/block/*; do
  [ -e "$d" ] || continue
  n=$(basename "$d")
  s=$(cat "$d/size" 2>/dev/null)
  [ -n "$s" ] && echo "$n $s sectors"
done

section "MMC AND SD DEVICE IDENTITY"
for d in /sys/class/block/mmcblk* /sys/class/block/sd[a-z]; do
  [ -e "$d" ] || continue
  n=$(basename "$d")
  echo "--- $n ---"
  echo -n "size: "; cat "$d/size" 2>/dev/null
  echo -n "removable: "; cat "$d/removable" 2>/dev/null
  echo -n "type: "; cat "$d/device/type" 2>/dev/null
  echo -n "name: "; cat "$d/device/name" 2>/dev/null
  echo -n "model: "; cat "$d/device/model" 2>/dev/null
  echo -n "vendor: "; cat "$d/device/vendor" 2>/dev/null
done

section "SD PARTITIONS"
ls -l /dev/block/mmcblk1* 2>&1 || true

section "SD MOUNT"
mount | grep -E 'mmcblk1|/storage|/mnt/media_rw' 2>&1 || true

section "MMC SYSFS AND DRIVER"
readlink -f /sys/class/block/mmcblk1/device 2>&1 || true
readlink -f /sys/class/block/mmcblk1/device/driver 2>&1 || true

section "SDHCI SYSFS"
ls -la /sys/devices/platform/soc/8804000.sdhci 2>&1 || true
find /sys/devices/platform/soc/8804000.sdhci -maxdepth 4 -type f -print 2>/dev/null | sort

section "DEVICE TREE SDHCI"
DT=/sys/firmware/devicetree/base/soc/sdhci@8804000
if [ -d "$DT" ]; then
  echo "DT=$DT"
  find "$DT" -maxdepth 2 -type f -print 2>/dev/null | sort
  for p in bus-width cd-debounce-delay-ms cd-gpios clock-names clocks compatible interconnect-names interconnects interrupt-names interrupts iommus name no-mmc no-sdio operating-points-v2 phandle pinctrl-0 pinctrl-1 pinctrl-names qcom,dll-hsr-list qcom,iommu-dma qcom,iommu-dma-addr-pool qcom,iommu-geometry qcom,restore-after-cx-collapse qcom,vdd-current-level qcom,vdd-io-current-level qcom,vdd-io-voltage-level qcom,vdd-voltage-level reg reg-names reset-names resets status vdd-io-supply vdd-supply; do
    if [ -f "$DT/$p" ]; then echo "--- $p ---"; od -An -tx1 "$DT/$p" 2>/dev/null; fi
  done
else
  echo "SDHCI DT node unavailable"
fi

section "SD PINCTRL"
PIN=/sys/firmware/devicetree/base/soc/pinctrl@f000000
for st in sdc2_on sdc2_off; do
  echo "--- $st ---"
  if [ -d "$PIN/$st" ]; then
    find "$PIN/$st" -maxdepth 2 -type f -print 2>/dev/null | sort
    for sub in clk cmd data sd-cd; do
      if [ -d "$PIN/$st/$sub" ]; then
        echo "[$sub]"
        for p in name pins drive-strength bias-pull-up; do
          [ -f "$PIN/$st/$sub/$p" ] && { echo -n "$p: "; od -An -tx1 "$PIN/$st/$sub/$p" 2>/dev/null; }
        done
      fi
    done
  fi
done

section "REGULATOR PHANDLES"
for X in 00000352 00000359; do
  echo "--- phandle $X ---"
  find /sys/firmware/devicetree/base -type f -name phandle 2>/dev/null | while read f; do
    v=$(od -An -tx1 "$f" 2>/dev/null | tr -d ' \n')
    [ "$v" = "$X" ] && dirname "$f"
  done
done

section "BOOT PARTITION NODES"
for p in uefi_a uefi_b uefisecapp_a uefisecapp_b boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b abl_a abl_b xbl_a xbl_b recovery_a recovery_b; do
  echo "--- $p ---"
  ls -l "/dev/block/by-name/$p" 2>&1 || true
done

section "FILESYSTEM / STORAGE SUMMARY"
df -h 2>&1 || true

section "MOUNT TABLE"
mount 2>&1 || true

section "KERNEL MMC / SD LOGS"
dmesg 2>&1 | grep -Ei 'mmc|sdhci|sd card|mmcblk1' | tail -n 500 2>&1 || true

echo
echo "===== END: READ-ONLY INVESTIGATION ====="
echo "Output: $OUT"
