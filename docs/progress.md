# Retroid Pocket G2 Linux / SteamOS Porting Progress

## Project Goal

Retroid Pocket G2에 Linux/SteamOS 계열 OS를 microSD 카드로 부팅하는 것을 최종 목표로 한다.

핵심 목표:

- 내부 Android를 삭제하거나 덮어쓰지 않는다.
- microSD 카드에 Linux/SteamOS 환경을 구성한다.
- microSD가 삽입되어 있으면 Linux/SteamOS 부팅을 시도한다.
- microSD를 제거하면 기존 Android 환경을 그대로 사용할 수 있도록 한다.
- Armada 및 Retroid Pocket 5/6 등의 기존 Linux/SteamOS 포팅 사례를 참고한다.

## Project Repository

GitHub:
https://github.com/kaicia/retroid-g2-linux

Repository description:
Retroid Pocket G2 Linux porting research

## Development Environment

현재 Android 기기에서 Termux를 사용하여 G2 조사 작업을 수행하고 있다.

설치/확인된 도구:

- git
- GitHub CLI (gh)
- termux-adb
- fakeroot

GitHub CLI 인증 완료:

- GitHub account: kaicia
- Git protocol: HTTPS
- repository scope: repo
- workflow scope: workflow

## Armada Reference

Armada 원본 저장소를 조사하기 위해 다음 저장소를 Termux에 clone했다.

https://github.com/armada-os/armada

Local path:

~/armada

이 저장소는 G2 Linux/SteamOS 포팅 시 참고 자료로 사용한다.

## G2 SD Card / SDHCI Investigation

Android의 Device Tree를 직접 조사했다.

SDHCI node:

/sys/firmware/devicetree/base/soc/sdhci@8804000

SDHCI name:

sdhci

Compatible:

qcom,sdhci-msm-v5

Status:

ok

Register:

0x8804000

Bus width:

4-bit

## SD Card Controller / Pinctrl

SD 카드 관련 pinctrl state:

sdc2_on
sdc2_off

sdc2_on:

CLK  = gpio62
CMD  = gpio51
DATA = gpio38, gpio39, gpio48, gpio49
CD   = gpio31

sdc2_off:

CLK  = gpio62
CMD  = gpio51
DATA = gpio38, gpio39, gpio48, gpio49
CD   = gpio31

Drive strength:

sdc2_on:
- CLK: 0x10
- CMD: 0x0a
- DATA: 0x0a
- CD:  0x02

sdc2_off:
- CLK: 0x02
- CMD: 0x02
- DATA: 0x02
- CD:  0x02

## SD Card Detect

SDHCI cd-gpios property:

00 00 01 6c 00 00 00 1f 00 00 00 01

GPIO controller phandle:

0x16c

GPIO controller:

/sys/firmware/devicetree/base/soc/pinctrl@f000000

GPIO number:

31

CD debounce:

1500 ms

## SDHCI Pinctrl References

pinctrl-names:

default
sleep

pinctrl-0:

0x3ac -> sdc2_on

pinctrl-1:

0x3ad -> sdc2_off

## SDHCI Power Supplies

vdd-supply phandle:

0x352

Resolved regulator:

/sys/firmware/devicetree/base/soc/rsc@17a00000/drv@2/rpmh-regulator-ldob13/regulator-pmxr2230-l13

vdd-io-supply phandle:

0x359

Resolved regulator:

/sys/firmware/devicetree/base/soc/rsc@17a00000/drv@2/rpmh-regulator-ldob23/regulator-pmxr2230-l23

## MMC Host

Observed MMC host:

/sys/devices/platform/soc/8804000.sdhci/mmc_host/mmc1

An MMC device was also observed below mmc1.

## Debugging Findings

/sys/kernel/debug/gpio does not exist on the running Android kernel/environment.

The legacy gpio debug interface therefore cannot currently be used for this investigation.

The Device Tree exposed through:

/sys/firmware/devicetree/base

is being used instead.

## Important Raw Dump

The complete SDHCI Device Tree property dump is stored at:

dumps/g2/g2_sdhci_dt_dump.txt

## Current Status

Completed:

1. GitHub CLI installed.
2. GitHub CLI authenticated as kaicia.
3. G2 project repository identified.
4. Armada repository cloned locally.
5. G2 SDHCI Device Tree node identified.
6. SD card pinctrl states identified.
7. SD card GPIO assignments identified.
8. SD card detect GPIO identified.
9. SDHCI power regulator phandles resolved.
10. Raw SDHCI Device Tree dump saved.

Next investigation targets:

- Decode complete SDHCI Device Tree properties.
- Identify bootloader / firmware boot path.
- Determine whether the G2 boot chain can boot an external microSD Linux image.
- Compare G2 Device Tree with supported Armada/RP5/RP6 devices.
- Identify required kernel, DTB, firmware and boot image modifications.
- Determine the exact SD boot mechanism before attempting any modification to the device.
