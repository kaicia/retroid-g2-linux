# Next Session Resume Procedure

## Current stopping point

2026-08-19 작업을 여기서 중단한다.

G2 SDHCI / Device Tree 조사 결과와 원본 dump는 GitHub `main` 브랜치에 저장되어 있다.

관련 파일:
- `docs/progress.md`
- `docs/device-tree.md`
- `docs/hardware.md`
- `dumps/g2/g2_sdhci_dt_dump.txt`

## Next session: reconnect ADB first

다음 작업은 Android 기기와 USB 연결을 다시 구성한 뒤 Termux에서 ADB 연결부터 재확인한다.

### 1. USB 연결 재설정

- USB 케이블을 기기에서 분리한다.
- 다시 연결한다.
- 필요한 경우 USB 연결/ADB 권한 팝업을 다시 승인한다.

### 2. Termux에서 ADB 연결 확인

먼저 현재 연결 상태를 확인한다.

```sh
termux-adb devices
```

정상적으로 기기가 보이는지 확인한 후 shell 연결을 확인한다.

```sh
termux-adb shell 'getprop ro.product.model; echo; getprop ro.build.version.release'
```

### 3. 다시 마운트된 위치 확인

USB 연결을 다시 한 뒤 Android 쪽에서 조사에 사용할 경로와 Device Tree가 정상적으로 보이는지 확인한다.

```sh
termux-adb shell 'echo "=== DT ==="; ls -ld /sys/firmware/devicetree/base; echo "=== SDHCI ==="; ls -ld /sys/firmware/devicetree/base/soc/sdhci@8804000 2>/dev/null; echo "=== MMC ==="; ls -l /sys/devices/platform/soc/8804000.sdhci/mmc_host 2>/dev/null'
```

### 4. 중요

현재 조사 결과를 다시 만들 필요는 없다. GitHub에 이미 원본 dump와 정리 문서가 저장되어 있으므로, 먼저 ADB/경로가 정상인지 확인하고 그 다음 단계부터 이어간다.

## Last confirmed Git commit

`c705fd3 docs: save G2 SDHCI investigation results`

## Next technical investigation

ADB 연결이 복구되면 다음 순서로 진행한다.

1. SDHCI/Device Tree 접근 경로 재확인
2. 필요한 DT property 추가 해석
3. G2의 SD boot/bootloader 경로 조사
4. Armada 및 RP5/RP6 지원 Device Tree와 비교
5. 외부 microSD Linux/SteamOS 부팅 가능성을 판단

절대로 아직 bootloader나 Android 파티션을 수정하지 않는다. 먼저 현재 boot chain과 SD boot mechanism을 확인한다.
