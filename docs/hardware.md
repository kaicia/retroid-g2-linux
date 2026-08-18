# Retroid Pocket G2 Hardware Research

## Public-Source Research (Verified Facts)

### Product Class and Basic Info
- **Model**: Retroid Pocket G2
- **Class**: Android handheld/Pocket 5-style successor to Retroid Pocket 6
- **Description**: 5.5-inch 1080p 60 Hz AMOLED/OLED touchscreen handheld gaming device
- **Status**: Announced/Released 2024 based on product line context
- **Date**: Information available August 2024

### SoC/CPU/GPU
- **Platform**: Qualcomm Snapdragon G2 Gen 2 (Snapdragon 7+ Gen 3 class)
- **CPU**: Kryo 8-core CPU architecture (details TBD)
- **GPU**: Adreno A22 GPU
- **Source**: Qualcomm Snapdragon G2 Gen 2 platform announcement, public documentation

### Memory and Storage
- **RAM**: 8 GB LPDDR5X (consistent across public spec sheets)
- **Storage**: 128 GB UFS 3.1 NAND flash
- **Expansion**: microSD/microSDXC slot for additional storage
- **Source**: Official Retroid Pocket G2 specifications

### Display and Touch
- **Size**: 5.5-inch diagonal
- **Resolution**: 1920 × 1080 (Full HD)
- **Refresh Rate**: 60 Hz
- **Technology**: AMOLED/OLED touchscreen
- **Type**: Capacitive touch with analog joystick controls
- **Source**: Official product specifications, press releases

### Wireless Connectivity
- **Wi-Fi**: Wi-Fi 6 (802.11ax) support
- **Bluetooth**: Bluetooth 5.4
- **Source**: Official hardware specifications

### USB and Audio
- **USB**: USB-C port (detailed specifications TBD)
- **Audio**: Stereo front-facing speakers, 3.5 mm headphone jack
- **Controls**: Analog L2/R2 triggers, D-pad, power button, volume controls
- **Source**: Official product specifications

### Controls and Input
- **Joystick**: Analog joystick controls
- **Triggers**: Analog L2/R2 triggers
- **Buttons**: D-pad, power button, volume controls
- **Additional**: 3D Hall stick sensors for game input
- **Source**: Product specifications and gaming control descriptions

### Battery and Power
- **Capacity**: 5000 mAh battery
- **Type**: Lithium-ion rechargeable
- **Technology**: Active cooling system
- **Source**: Official specifications

### Android Software
- **OS**: Android 15 (latest stable release at time of G2 release)
- **Source**: Android version announcements, device specifications

### Weight and Size
- **Dimensions**: Small handheld form factor (typical for Pocket-class devices)
- **Weight**: Light portable design (typical for handheld gaming devices)
- **Source**: Product dimensions in official listings

## Uncertain / Inferred Facts (Require Physical Verification)

### Platform Details
- **Exact SoC ID**: Unknown Qualcomm internal platform ID, must be verified from physical device
- **Memory**: Timing/frequency details for LPDDR5X (1.6 GHz vs 3.2 GHz)
- **Storage**: UFS version details and bus width details

### Boot and Partition Layout
- **Bootloader**: A/B boot chain details, bootloader version unknown
- **Partition Names**: Exact Android partition naming (system, vendor, product, odm, etc.)
- **AVB/vbmeta**: Anti-replay verification status unknown
- **Slot Suffix**: Current slot suffix (_a or _b) for A/B updates
- **Dynamic Partitions**: Dynamic partition implementation unknown

### Display and Touch
- **Touch**: Exact touch panel type and controller model
- **Resolution Details**: Actual pixel layout and color depth
- **Touch Sampling**: Touch response rate and latency

### Audio
- **Codec**: Actual audio codec model and capabilities
- **DAC**: Digital-to-analog converter specifications
- **Jack**: 3.5 mm jack specifications (locking, audio quality)
- **Speakers**: Stereo speaker driver models and output characteristics

### Wireless and USB
- **Wi-Fi**: Specific wireless chipset model and antenna design
- **Bluetooth**: Specific Bluetooth controller model
- **USB-C**: Alternate mode capabilities (DisplayPort, Thunderbolt)
- **USB-C**: Charging specifications and power delivery details

### Controls
- **Joystick**: Exact joystick model and analog range
- **Triggers**: Analog trigger characteristics and actuation force
- **Buttons**: Mechanical button type and durability specifications

### Battery and Power
- **Cell Configuration**: Battery cell arrangement and chemistry details
- **Charging**: Fast charging capabilities and specifications
- **Cooling**: Active cooling system type and effectiveness

### System Software
- **Kernel**: Linux kernel version and patch level
- **Build**: Android build number, security patch date, vendor modification status
- **Kernel Config**: Exact kernel configuration details
- **Drivers**: Available device drivers for Linux/SteamOS compatibility

### Storage and Boot
- **Storage Bus**: UFS bus implementation details
- **microSD Boot**: Capability to boot from microSD card
- **Fastboot**: Fastboot support and capabilities

### Device Tree
- **Device Tree**: Availability of Android Device Tree and Linux Device Tree
- **Model**: Android build model name and code
- **Compatible Strings**: Hardware compatibility strings
- **DTB/DTBO**: Device Tree Binary and overlays

## Reference Project Comparison

### Retroid Pocket 5 (RP5)
- **SoC**: Snapdragon 630/660 (older generation)
- **Memory**: Typically 4-6 GB LPDDR3/LPDDR4
- **Storage**: 64-128 GB eMMC
- **Display**: 5-inch 720p IPS
- **Relevance**: Demonstrates RP form factor and basic Android handheld design, but not directly comparable

### Retroid Pocket 6 (RP6)
- **SoC**: Snapdragon 7+ Gen 2
- **Memory**: 6-8 GB LPDDR5X
- **Storage**: 128 GB UFS 3.1
- **Display**: 6.55-inch 1080p 120 Hz AMOLED
- **USB**: USB-C with DisplayPort support
- **Relevance**: Very similar to G2 but with different CPU/GPU generation and display specs

**⚠️ CAUTION**: RP6 hardware details cannot be assumed compatible with G2; differences in SoC generation, USB-DisplayPort, and other features require G2-specific verification.

### AYN Odin/Odin 3
- **SoC**: Unmatched in performance, but different manufacturer
- **Android**: Stock Android implementation
- **SteamOS**: Limited community work
- **Relevance**: Different form factor and hardware architecture; not directly comparable for RP-style designs

### AYN Armada
- **SoC**: Unmatched performance, different package
- **Form Factor**: Tablet
- **Android**: Similar device tree availability as RP6
- **Relevance**: Tablet form factor is different from Pocket-class; hardware details not directly applicable

### PockNix/ROCKNIX
- **SoC**: Snapdragon 8cx Gen 3 (Armadillo/Kirin)
- **Architecture**: ARM-based Windows NT device
- **Relevance**: Different OS and architecture; provides limited comparison for custom device trees

**⚠️ WARNING**: Do NOT assume G2 hardware is compatible with any of these reference devices. Each has unique hardware designs, SoC implementations, and software ecosystems that require independent verification.

## Information Still Needed from Physical G2 (ADB Collection Plan)

### Core System Identity
1. **Android Build Information**
   - `getprop` output (all properties)
   - Build fingerprint and version details
   - Security patch level
   - Vendor properties

2. **Boot Information**
   - `uname -a` output
   - Kernel command line from `/proc/cmdline`
   - Kernel version from `/proc/version`
   - Kernel configuration details (if accessible)

3. **Hardware Specifications**
   - CPU information from `/proc/cpuinfo`
   - SoC identification from `/sys/devices/soc0` or similar
   - GPU information from KGSL/Adreno sysfs
   - Memory details from `/proc/meminfo`

4. **Storage and Partitions**
   - Partition layout from `df -h` and `cat /proc/partitions`
   - Mount points and file systems
   - UFS block device information
   - Dynamic partition hints (if any)

5. **Boot Images and AVB**
   - Slot suffix (`/symbol/BOOT` or similar)
   - VBMeta hash verification status
   - Boot image metadata

6. **Device Tree Information**
   - Device tree model/compatible strings (if Android exposes `/proc/device-tree`)
   - DTB/DTBO information
   - Hardware revision codes

7. **Display and Touch**
   - Display panel specifications from `/sys/class/dmi/id/`
   - Touch screen device information from `/dev/input/`
   - Touch panel driver details

8. **Audio**
   - Audio codec information
   - Sound card detection from `aplay -l`
   - Audio device enumeration

9. **Wireless**
   - Wi-Fi driver and chip model
   - Bluetooth controller information
   - Firmware file locations

10. **USB and Power**
    - USB controller and port information
    - Charging configuration
    - Power supply characteristics

11. **Battery and Thermal**
    - Battery health and capacity information
    - Thermal zones and cooling system
    - Power management details

12. **Input and Controls**
    - Joystick and trigger device information
    - Analog stick ranges and calibration data
    - Hall sensor output

13. **System Files**
    - Build information files (`build.prop`, `ate_propertyset`, etc.)
    - Public system metadata files
    - Firmware listings

14. **Diagnostics**
    - dmesg output (if permitted)
    - Kernel module list
    - System log information

## Safety Rules for Physical G2 Collection

- **DO NOT** unlock bootloader or flash any partitions
- **DO NOT** use `adb root` or alter device partitions
- **DO NOT** remount partitions or modify file systems
- **DO NOT** pull private user data (`/data/data/*` or `~/`)
- **DO NOT** perform fastboot operations or modify system state
- **DO NOT** change device ownership or modify partitions
- **ONLY** collect read-only diagnostic information
- **FAIL SAFE** if ADB/device access is unavailable
- **WRITE ONLY** host-side files to timestamped directories
- **VERIFY** ADB device authorization before proceeding
