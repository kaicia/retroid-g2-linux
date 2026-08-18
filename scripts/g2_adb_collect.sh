#!/usr/bin/env bash

# G2 ADB Collection Script
# Safe, read-only Android diagnostic collector for Retroid Pocket G2
# Created: 2026-08-18
# Author: Codex (OpenCode)

# Safety statement included in each dump
# This script collects only non-destructive diagnostic information
# It does NOT modify the device, unlock bootloader, flash, remount, use adb root,
# alter partitions, pull private user data, or otherwise change device state

# Exit on any error to prevent partial/incomplete collections
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DUMP_BASE="${SCRIPT_DIR}/dumps/g2"
DUMP_DIR="${DUMP_BASE}/${TIMESTAMP}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Error handling
error_exit() {
    log "ERROR: $*"
    log "Script failed. Clean exit." >&2
    exit 1
}

# Check if ADB is available
check_adb() {
    if ! command -v adb &> /dev/null; then
        error_exit "ADB not found in PATH. Please install Android platform-tools."
    fi
    log "ADB found: $(adb version 2>/dev/null | head -n1 || echo "ADB version unknown")"
}

# Check for exactly one authorized device
check_device() {
    local device_count=$(adb devices | grep -c "device$")
    
    if [ "$device_count" -eq 0 ]; then
        error_exit "No authorized ADB devices found. Please connect and authorize your G2."
    elif [ "$device_count" -gt 1 ]; then
        error_exit "Multiple ADB devices found ($device_count). Please connect only your G2."
    else
        local device_id=$(adb devices | grep "device$" | cut -f1)
        log "G2 device found: $device_id"
        echo "$device_id" > "${DUMP_DIR}/adb_device_id.txt"
    fi
}

# Create dump directory
create_dump_dir() {
    log "Creating dump directory: $DUMP_DIR"
    mkdir -p "${DUMP_DIR}"
    
    # Write safety statement
    cat > "${DUMP_DIR}/safety_statement.txt" << 'EOF'
SAFETY STATEMENT:
This dump was collected by the g2_adb_collect.sh script.
The script follows strict safety rules:
1. NO device modification (no flashing, remounting, partitioning)
2. NO private user data collection (/data/data/* paths excluded)
3. NO adb root or privilege escalation
4. NO bootloader unlock or fastboot operations
5. ONLY read-only diagnostic information collection
6. FAIL safe if device access becomes unavailable

The script is designed to be non-destructive and safe for research purposes.
EOF
}

# Collect Android properties
collect_properties() {
    log "Collecting Android properties..."
    
    # Save all properties to a file
    if adb shell getprop > "${DUMP_DIR}/android_properties.txt"; then
        log "✓ Android properties collected"
    else
        log "WARNING: Failed to collect Android properties"
    fi
}

# Collect kernel information
collect_kernel_info() {
    log "Collecting kernel information..."
    
    # uname -a
    if adb shell uname -a > "${DUMP_DIR}/kernel_uname.txt"; then
        log "✓ Kernel uname collected"
    else
        log "WARNING: Failed to collect kernel uname"
    fi
    
    # /proc/version
    if adb shell cat /proc/version > "${DUMP_DIR}/proc_version.txt"; then
        log "✓ /proc/version collected"
    else
        log "WARNING: Failed to collect /proc/version"
    fi
    
    # /proc/cmdline
    if adb shell cat /proc/cmdline > "${DUMP_DIR}/proc_cmdline.txt"; then
        log "✓ /proc/cmdline collected"
    else
        log "WARNING: Failed to collect /proc/cmdline"
    fi
}

# Collect CPU/SoC information
collect_cpu_info() {
    log "Collecting CPU/SoC information..."
    
    # /proc/cpuinfo
    if adb shell cat /proc/cpuinfo > "${DUMP_DIR}/proc_cpuinfo.txt"; then
        log "✓ /proc/cpuinfo collected"
    else
        log "WARNING: Failed to collect /proc/cpuinfo"
    fi
    
    # SoC information from /sys/devices/soc0
    if adb shell [ -d /sys/devices/soc0 ] && adb shell ls /sys/devices/soc0/ > "${DUMP_DIR}/sys_soc0_dirs.txt"; then
        log "✓ SoC directories collected"
    else
        log "INFO: /sys/devices/soc0 not accessible or empty"
    fi
    
    # devfreq information
    if adb shell find /sys/class/devfreq -type f -name "*/curr_freq" > "${DUMP_DIR}/devfreq_freqs.txt" 2>/dev/null; then
        log "✓ Devfreq frequencies collected"
    else
        log "INFO: Devfreq not accessible"
    fi
    
    # KGSL/Adreno sysfs (if available)
    if adb shell [ -d /sys/class/kgsl/kgsl-3d0 ] && adb shell ls /sys/class/kgsl/kgsl-3d0/ > "${DUMP_DIR}/kgsl_adreno_dirs.txt"; then
        log "✓ Adreno KGSL directories collected"
    else
        log "INFO: KGSL/Adreno sysfs not accessible"
    fi
}

# Collect memory and storage information
collect_memory_storage() {
    log "Collecting memory and storage information..."
    
    # /proc/meminfo
    if adb shell cat /proc/meminfo > "${DUMP_DIR}/proc_meminfo.txt"; then
        log "✓ /proc/meminfo collected"
    else
        log "WARNING: Failed to collect /proc/meminfo"
    fi
    
    # df -h
    if adb shell df -h > "${DUMP_DIR}/df_h.txt"; then
        log "✓ df -h collected"
    else
        log "WARNING: Failed to collect df -h"
    fi
    
    # /proc/partitions
    if adb shell cat /proc/partitions > "${DUMP_DIR}/proc_partitions.txt"; then
        log "✓ /proc/partitions collected"
    else
        log "WARNING: Failed to collect /proc/partitions"
    fi
    
    # Block devices
    if adb shell ls -1 /dev/block/ > "${DUMP_DIR}/block_devices.txt"; then
        log "✓ Block devices collected"
    else
        log "WARNING: Failed to collect block devices"
    fi
}

# Collect mount points
collect_mounts() {
    log "Collecting mount points..."
    
    if adb shell mount > "${DUMP_DIR}/mounts.txt"; then
        log "✓ Mount points collected"
    else
        log "WARNING: Failed to collect mount points"
    fi
}

# Collect boot information
collect_boot_info() {
    log "Collecting boot information..."
    
    # Get slot suffix
    if adb shell grep "ro.boot.slot_suffix" /proc/cmdline > "${DUMP_DIR}/boot_slot_suffix.txt" 2>/dev/null || \
       adb shell getprop | grep "ro.boot.slot_suffix" > "${DUMP_DIR}/boot_slot_suffix.txt" 2>/dev/null; then
        log "✓ Boot slot suffix collected"
    else
        log "INFO: Boot slot suffix not found"
    fi
    
    # VBMeta hash (if accessible)
    if adb shell getprop | grep "ro.boot.vbmeta.digest" > "${DUMP_DIR}/vbmeta_digest.txt" 2>/dev/null; then
        log "✓ VBMeta digest collected"
    else
        log "INFO: VBMeta digest not accessible"
    fi
}

# Collect Device Tree information
collect_device_tree() {
    log "Collecting Device Tree information..."
    
    # Check for exposed Device Tree
    if adb shell [ -d /proc/device-tree ]; then
        log "Device Tree /proc/device-tree accessible"
        
        # Save model/compatible strings
        if adb shell cat /proc/device-tree/model > "${DUMP_DIR}/dt_model.txt" 2>/dev/null; then
            log "✓ Device Tree model collected"
        else
            log "INFO: Device Tree model not accessible"
        fi
        
        if adb shell cat /proc/device-tree/compatible > "${DUMP_DIR}/dt_compatible.txt" 2>/dev/null; then
            log "✓ Device Tree compatible collected"
        else
            log "INFO: Device Tree compatible not accessible"
        fi
    else
        log "INFO: /proc/device-tree not accessible"
    fi
    
    # sysfs firmware devicetree
    if adb shell [ -d /sys/firmware/devicetree/base ]; then
        log "sysfs /sys/firmware/devicetree/base accessible"
        if adb shell ls /sys/firmware/devicetree/base/ > "${DUMP_DIR}/sysdt_base_dirs.txt" 2>/dev/null; then
            log "✓ sysfs Device Tree directories collected"
        else
            log "WARNING: Failed to collect sysfs Device Tree directories"
        fi
    else
n        log "INFO: /sys/firmware/devicetree/base not accessible"
    fi
}

# Collect display and touch information
collect_display_touch() {
    log "Collecting display and touch information..."
    
    # Display panel info from DMI (if accessible)
    if adb shell cat /sys/class/dmi/id/product_name > "${DUMP_DIR}/dmi_product_name.txt" 2>/dev/null; then
        log "✓ DMI product name collected"
    else
        log "INFO: DMI product name not accessible"
    fi
    
    # Touch screen devices from /dev/input/
    if adb shell ls /dev/input/ > "${DUMP_DIR}/input_devices.txt"; then
        log "✓ Input devices collected"
    else
        log "WARNING: Failed to collect input devices"
    fi
    
    # Check for touch device properties
    if adb shell getprop | grep -i touch > "${DUMP_DIR}/touch_properties.txt" 2>/dev/null; then
        log "✓ Touch properties collected"
    else
        log "INFO: Touch properties not found"
    fi
}

# Collect audio information
collect_audio_info() {
    log "Collecting audio information..."
    
    # Sound card list
    if command -v aplay &> /dev/null && adb shell aplay -l > "${DUMP_DIR}/aplay_list.txt"; then
        log "✓ ALSA sound card list collected"
    else
        log "INFO: aplay not available or failed"
    fi
    
    # Audio codec info (if accessible)
    if adb shell find /sys/class/sound -type f -name "index" > "${DUMP_DIR}/sound_indexes.txt" 2>/dev/null; then
        log "✓ Sound indexes collected"
    else
        log "INFO: Sound device info not accessible"
    fi
}

# Collect wireless information
collect_wireless_info() {
    log "Collecting wireless information..."
    
    # Wi-Fi driver info
    if adb shell ls /sys/class/net/wlan0/ > "${DUMP_DIR}/wlan0_info.txt" 2>/dev/null; then
        log "✓ WLAN0 info collected"
    else
        log "INFO: WLAN0 not available"
    fi
    
    # Bluetooth info
    if adb shell ls /sys/class/net/hci0/ > "${DUMP_DIR}/hci0_info.txt" 2>/dev/null; then
        log "✓ HCI0 info collected"
    else
        log "INFO: HCI0 not available"
    fi
    
    # Firmware listings
    if adb shell find /firmware /system/etc/firmware /vendor/etc/firmware -type f -name "*.fw" -o -name "*.bin" > "${DUMP_DIR}/firmware_files.txt" 2>/dev/null; then
        log "✓ Firmware files collected"
    else
        log "INFO: Firmware listings not accessible"
    fi
}

# Collect USB and power information
collect_usb_power_info() {
    log "Collecting USB and power information..."
    
    # USB controller info
    if adb shell ls /sys/class/usb/ > "${DUMP_DIR}/usb_controllers.txt" 2>/dev/null; then
        log "✓ USB controllers collected"
    else
        log "INFO: USB controllers not accessible"
    fi
    
    # Power supply info
    if adb shell ls /sys/class/power_supply/ > "${DUMP_DIR}/power_supply_types.txt" 2>/dev/null; then
        log "✓ Power supply types collected"
    else
        log "INFO: Power supply info not accessible"
    fi
    
    # Battery info
    if adb shell cat /sys/class/power_supply/battery/capacity > "${DUMP_DIR}/battery_capacity.txt" 2>/dev/null; then
        log "✓ Battery capacity collected"
    else
        log "INFO: Battery info not accessible"
    fi
}

# Collect thermal information
collect_thermal_info() {
    log "Collecting thermal information..."
    
    # Thermal zones
    if adb shell ls /sys/class/thermal/ > "${DUMP_DIR}/thermal_zones.txt" 2>/dev/null; then
        log "✓ Thermal zones collected"
    else
        log "INFO: Thermal zones not accessible"
    fi
    
    # Temperature readings
    if adb shell cat /sys/class/thermal/thermal_zone*/temp > "${DUMP_DIR}/thermal_temps.txt" 2>/dev/null; then
        log "✓ Thermal temperatures collected"
    else
        log "INFO: Thermal temperatures not accessible"
    fi
}

# Collect diagnostics
collect_diagnostics() {
    log "Collecting diagnostics..."
    
    # dmesg (if permitted)
    if adb shell dmesg > "${DUMP_DIR}/dmesg.txt" 2>/dev/null; then
        log "✓ dmesg collected"
    else
n        log "INFO: dmesg not accessible"
    fi
    
    # Kernel modules (if accessible)
    if adb shell ls /proc/modules > "${DUMP_DIR}/kernel_modules.txt" 2>/dev/null; then
        log "✓ Kernel modules collected"
    else
        log "INFO: Kernel modules not accessible"
    fi
}

# Collect Android system files
collect_android_files() {
    log "Collecting Android system files..."
    
    # Build files (public information only)
    if adb shell cat /system/build.prop > "${DUMP_DIR}/system_build.prop" 2>/dev/null; then
        log "✓ System build.prop collected"
    else
        log "INFO: System build.prop not accessible"
    fi
    
    if adb shell cat /vendor/build.prop > "${DUMP_DIR}/vendor_build.prop" 2>/dev/null; then
        log "✓ Vendor build.prop collected"
    else
        log "INFO: Vendor build.prop not accessible"
    fi
    
    # Public fstab (without passwords)
    if adb shell cat /system/etc/fstab > "${DUMP_DIR}/fstab.txt" 2>/dev/null; then
        log "✓ FSTAB collected"
    else
        log "INFO: FSTAB not accessible"
    fi
}

# Cleanup function
cleanup() {
    log "Script completed successfully."
    log "Dump directory: $DUMP_DIR"
    log "Files collected under: $DUMP_DIR"
}

# Main execution
main() {
    log "Starting G2 ADB collection script..."
    
    # Pre-checks
    check_adb
    create_dump_dir
    check_device
    
    # Collection steps
    collect_properties
    collect_kernel_info
    collect_cpu_info
    collect_memory_storage
    collect_mounts
    collect_boot_info
    collect_device_tree
    collect_display_touch
    collect_audio_info
    collect_wireless_info
    collect_usb_power_info
    collect_thermal_info
    collect_diagnostics
    collect_android_files
    
    # Finalize
    cleanup
}

# Run main function
main
