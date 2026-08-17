# Retroid Pocket G2 SteamOS Porting Project

## 1. 최종 목표

Retroid Pocket G2에서 SteamOS를 실행하는 것이 최종 목표다. Android를 삭제하는 방식은 최종 목표가 아니다.

- 내부 저장장치: 기존 Android 유지
- SD 카드: SteamOS
- SD 카드 장착: SteamOS 부팅
- SD 카드 제거: 기존 Android 정상 부팅

이 구조가 실제 G2에서 가능한지는 **미확인**이다. 부트로더, 부트 체인, SD 카드 부팅 지원 여부를 조사해야 한다.

## 2. 현재 프로젝트 상태

현재 repository는 실제 포팅 코드가 완성된 상태가 아니라 초기 조사 및 기록 단계다. G2의 hardware/software 조사는 아직 시작되지 않았다고 기존 진행 문서에 기록되어 있다 (`docs/progress.md`).

현재 확인된 구성은 다음과 같다.

- `README.md`: 프로젝트를 "Retroid Pocket G2 Linux porting research"로 간단히 설명한다.
- `docs/`: 진행 현황, 결정사항, 대화 맥락 및 향후 조사용 문서가 있다.
- `dts/g2/`: 존재하지만 현재 DTS/DTB 파일은 없다.
- `scripts/`: 존재하지만 현재 파일은 없다.
- `dumps/g2/`: Codespace의 ADB 설치 및 과거 상태 기록이 있다.

`docs/boot.md`, `docs/device-tree.md`, `docs/hardware.md`, `docs/rp5.md`, `docs/rp6.md`는 현재 빈 파일이다. 따라서 이 문서들은 조사 주제를 나타내지만 해당 주제의 확인된 결과를 제공하지 않는다.

## 3. 현재까지 확인된 G2 정보

### 확인된 사실

- 프로젝트 문서에는 G2가 Snapdragon G2 Gen 2 기반이라고 기록되어 있다 (`docs/conversation.md`).
- G2는 아직 Galaxy S20 FE에 연결되지 않았으며, 실제 기기 ADB 시험은 아직 수행되지 않았다 (`docs/conversation.md`, `docs/decisions.md`).
- Codespace에는 ADB 34.0.4-debian가 설치되어 있음이 기록되어 있다 (`dumps/g2/adb-install-result.txt`). 이는 Codespace 환경 정보이며 G2의 Android 또는 kernel 정보는 아니다.

### 미확인 / 조사 필요

- 화면, 메모리, 내부 저장장치, SD 카드 컨트롤러, USB, 오디오, 무선, 컨트롤러, 배터리 등 세부 hardware 구성
- Android build 정보, board 식별자, kernel version/configuration, vendor 구성
- bootloader 상태, boot mode, recovery/fastboot 접근, partition 구성 및 슬롯 구조
- G2의 실제 Device Tree, DTB, DTS 및 공개 kernel source

## 4. Android 및 실제 기기 조사 계획

현재 계획은 Galaxy S20 FE를 USB/ADB 중계 기기로 사용하고 Termux에서 G2를 조사하는 것이다. 모바일 Chrome에서 사용하는 Codespace는 S20 FE에 USB로 연결된 G2를 자동으로 인식하지 못하는 것으로 기록되어 있다 (`docs/conversation.md`, `docs/decisions.md`).

계획된 순서:

```text
G2
→ Galaxy S20 FE 연결
→ Termux
→ ADB 확인
→ Android build 정보
→ SoC/board 정보
→ kernel 정보
→ boot properties
→ partition 정보
→ 추가 hardware 정보
```

ADB 34.0.4는 Codespace에 설치되었고, S20 FE에는 Termux 및 ADB tools를 설치/시험한 것으로 기록되어 있다. 그러나 G2 연결 및 `adb devices`의 성공 결과는 아직 없다. 위 정보 수집 명령과 결과는 실제 연결 후에 기록해야 한다.

## 5. Device Tree 조사

### 현재까지 확인된 내용

- G2용 Device Tree 및 kernel source 식별은 향후 작업으로 기록되어 있다 (`docs/progress.md`).
- `docs/device-tree.md`와 `dts/g2/`에는 현재 조사 결과 또는 DTS/DTB 파일이 없다.

### 앞으로 수행할 작업

- G2 DTB 확보
- DTB 분석
- DTS 변환
- hardware node 확인
- 기존 Linux DTS 비교
- RP5/RP6/Odin 3 관련 자료와 비교

G2 DTB/DTS의 존재 위치, 추출 가능 여부, 변환 가능 여부는 모두 **미확인**이다. 비교 대상의 자료가 실제로 재사용 가능한지도 조사 전에는 확정하지 않는다.

## 6. Kernel 조사

### 현재까지 확인된 내용

G2 kernel version, kernel configuration, kernel source 및 build 가능성은 현재 문서에 확인된 내용이 없다. 기존 문서에는 Snapdragon G2 Gen 2 device-tree와 kernel source 식별이 다음 단계로만 기록되어 있다 (`docs/progress.md`).

### 앞으로 조사할 내용

- G2 Kernel source
- Qualcomm Kernel source
- Kernel version
- 필요한 patch
- Device Tree 적용
- driver 구성
- Kernel build 가능성

공개 source의 존재나 특정 patch 필요 여부는 현재 **미확인**이다.

## 7. Driver 조사

다음 항목별로 G2에서 사용되는 hardware와 Android vendor driver 구성을 먼저 식별하고, Linux에서 필요한 driver 또는 지원 상태를 조사한다.

| 항목 | 현재 확인된 사실 | 앞으로 조사할 내용 |
| --- | --- | --- |
| Adreno GPU | GPU 모델 및 driver 상태 미확인 | GPU 식별, acceleration 경로, Mesa/커널 지원 |
| Display | 패널 및 display pipeline 미확인 | panel, controller, display node, 출력 지원 |
| Touchscreen | controller 및 driver 미확인 | 입력 device, DT node, Linux driver |
| Audio | codec 및 routing 미확인 | ALSA/SoC audio 구성, speaker/headphone/mic |
| Wi-Fi | chipset 및 firmware 미확인 | chipset, firmware, Linux 지원 |
| Bluetooth | chipset 및 transport 미확인 | chipset, firmware, Linux 지원 |
| USB | controller 및 mode 미확인 | host/device/charging 동작과 driver |
| Storage | controller 및 partition 구성 미확인 | internal/SD storage controller와 boot 관련 동작 |
| Power Management | battery/charger/thermal 구성 미확인 | suspend, charging, thermal, regulator driver |
| Controller/Gamepad | 입력 device 구성 미확인 | input mapping, driver, Steam 입력 연동 |

## 8. 기존 프로젝트 활용

다음은 참고 대상으로 기록한다. 이들은 비교 및 조사 대상이며, source 또는 설정을 재사용할 수 있다는 뜻은 아니다.

- Retroid Pocket 5
- Retroid Pocket 6
- Odin 3
- Armada
- PockNix
- 기타 관련 Snapdragon/Adreno Linux 프로젝트

각 대상에서 다음을 조사한다.

- Kernel source와 적용 가능한 patch
- Device Tree 및 hardware node 구성
- display, GPU, audio, wireless, input 등 driver 구성
- bootloader, boot chain, UEFI 사용 여부
- SD card boot 방식과 partition layout
- SteamOS 또는 Linux userspace 구성 및 기기별 조정

현재 repository에는 RP5/RP6 조사 내용이 없으며 (`docs/rp5.md`, `docs/rp6.md`는 빈 파일), Odin 3, Armada, PockNix 관련 조사 결과도 없다.

## 9. Boot 구조

목표는 내부 Android를 유지하면서 SD 카드의 SteamOS를 우선 부팅하는 구조를 조사하는 것이다. 실제 G2의 지원 여부는 **미확인**이다.

검토 대상:

- Bootloader
- Boot chain
- UEFI
- Kernel
- Device Tree
- Initramfs
- Root filesystem
- SD card partition

목표 부팅 흐름:

```text
Bootloader
→ Kernel
→ Device Tree
→ Initramfs
→ Root filesystem
→ SteamOS
```

이 흐름은 목표 모델이며, G2의 실제 bootloader가 SD 카드를 선택할 수 있는지, UEFI가 필요한지 또는 사용할 수 있는지, kernel/DTB/initramfs/root filesystem을 어떤 매체에서 로드할 수 있는지는 모두 조사 필요하다. `docs/boot.md`에는 현재 확인된 boot 결과가 없다.

## 10. SteamOS

Linux 부팅이 가능해진 이후 다음을 검토한다.

- SteamOS userspace
- GPU acceleration
- Display
- Audio
- Wi-Fi
- Bluetooth
- Controller
- Suspend/Resume
- Performance
- Game compatibility

현재 repository에는 G2에서 SteamOS 또는 다른 Linux userspace를 부팅한 기록이 없다. 위 항목의 지원 가능성 및 구현 방식은 미확인이다.

## 11. GitHub 프로젝트 관리

GitHub는 단순 코드 저장소가 아니라 프로젝트 전체 기록으로 사용한다. 기존 결정 문서에는 terminal 결과를 가능한 한 파일로 저장해 GitHub에 기록하고, 중요한 이력과 결정사항을 `docs/`에 보관하는 workflow가 기록되어 있다 (`docs/decisions.md`, `docs/conversation.md`).

기록 대상:

- 프로젝트 결정사항
- 조사 결과
- 명령어
- Terminal 결과
- Hardware dump
- Android 정보
- DTB/DTS
- Kernel 분석
- Driver 분석
- Build 결과
- Boot test
- 성공한 방법
- 실패한 방법
- 해결 방법
- 다음 단계
- Codex 작업 결과

## 12. ChatGPT / Codex / GitHub 역할

### ChatGPT

- 프로젝트 방향
- 기술 분석
- 작업 계획
- Codex 작업 지시
- 결과 검토
- 다음 단계 결정

### Codex

- Codespace repository 분석
- source code 검색
- 파일 작성/수정
- terminal 작업
- build/test
- log 분석
- 결과 보고서 작성
- git 작업
- commit
- push

### GitHub

- 코드
- 조사 결과
- 명령 결과
- build/test 결과
- Codex 결과 보고서
- 프로젝트 기록

### Retroid Pocket G2

- 실제 hardware test

## 13. Codex 작업 결과 기록 원칙

Codex가 실제 작업을 수행할 때마다 최종 결과를 GitHub에 기록하는 것을 목표로 한다. 기존 문서에는 명령 결과와 결정사항을 저장하는 workflow가 기록되어 있다. `docs/codex/`는 결과 보고서 위치로 사용할 예정이며, 현재 존재 여부와 보고서 형식의 실제 사용 이력은 미확인이다.

각 결과 보고서에는 가능하면 다음을 기록한다.

- 작업 목적
- 수행한 작업
- 주요 명령
- 변경 파일
- 결과
- 오류
- 해결 방법
- 남은 문제
- commit hash
- push 결과
- 다음 단계

## 14. Git 안전 규칙

작업 전과 후에 다음을 확인한다.

```bash
git status
git diff
```

- unrelated changes는 절대로 commit하지 않는다.
- `git add .`, `git add -A`, `git commit -am`은 사용하지 않는다.
- 이번 작업과 관련된 파일만 명시적으로 stage한다.
- commit 전에 반드시 `git diff --cached`를 확인한다.
- force push, `git push --force`, `git push -f`는 사용하지 않는다.

## 15. 프로젝트 진행 프로토콜

기본 흐름:

```text
ChatGPT 계획
→ Codex 조사/작업
→ 결과 파일 작성
→ git diff 검토
→ commit
→ push
→ GitHub 저장
→ ChatGPT 결과 검토
→ 다음 작업 결정
```

이는 향후 작업을 위한 프로토콜이다. 모든 단계가 현재까지 실제 수행되었다는 의미는 아니다.

## 16. 현재 다음 단계

현재 가장 우선적인 실제 조사는 다음 순서다.

1. G2를 실제 Android 상태에서 S20 FE에 연결
2. Termux에서 ADB 인식 확인
3. Android build 정보 수집
4. SoC/board 확인
5. Kernel 정보 확인
6. boot properties 확인
7. partition 정보 확인
8. 실제 hardware 식별 정보 정리
9. 식별자를 기반으로 공개 Kernel/Device Tree source 조사
10. SD card SteamOS boot 가능성과 필요한 boot chain 분석

1~8은 실제 기기 접근을 전제로 한 계획이며, 완료된 결과가 아니다. 9~10도 그 수집 결과에 근거해 수행해야 한다.

## 현재까지 확인된 사실

- repository는 Linux/SteamOS 포팅의 초기 조사·기록 단계다.
- 문서상 G2는 Snapdragon G2 Gen 2 기반이다.
- Codespace에는 ADB 34.0.4-debian가 설치되어 있다.
- G2와 S20 FE의 실제 ADB 연결 시험은 아직 기록되어 있지 않다.
- G2 hardware, Android, kernel, Device Tree, boot의 실제 조사 결과는 아직 없다.

## 아직 확인이 필요한 사항

- G2의 실제 hardware 및 Android software 정보
- kernel/Device Tree source와 DTB/DTS 확보 경로
- bootloader, partition, SD card boot 지원 여부
- Linux driver 지원 상태와 SteamOS 실행에 필요한 구성
- 참고 대상 프로젝트에서 비교 또는 재사용할 수 있는 자료

## 다음 조사 단계

먼저 G2를 S20 FE에 연결해 Termux에서 ADB 인식을 확인한다. 연결이 확인되면 Android build, SoC/board, kernel, boot properties, partition 및 hardware 식별 정보를 읽기 전용으로 수집한다. 그 식별자를 근거로 공개 kernel/Device Tree source와 SD 카드 기반 부팅 가능성을 조사한다.
