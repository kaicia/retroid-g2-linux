<#
  backup_g2_edl.ps1  —  Retroid Pocket G2 full partition backup over EDL (bkerler/edl)

  사용 전 준비 (recovery/backup runbook과 동일):
    - 기기: EDL(9008) 진입
    - 드라이버: Zadig 로 WinUSB 바인딩
    - 로더 xbl_s_devprg_ns.melf 를 edl-master 폴더에 둘 것
    - firehose.py 패치 2개 적용 (str/bytes, 읽기 무한멈춤 방지) — recovery runbook 참고

  실행 (edl-master 폴더에서):
    powershell -ExecutionPolicy Bypass -File .\backup_g2_edl.ps1
    # 옵션:
    #   -IncludeSuper      : super 파티션도 백업 (~수 GB, 느림)
    #   -IncludeUserdata   : userdata 도 백업 (매우 큼 — 보통 불필요)
    #   -OutDir <경로>     : 출력 폴더 지정 (기본: backup_YYYYMMDD_HHMMSS)
    #   -Loader <파일>     : 로더 파일명 (기본: xbl_s_devprg_ns.melf)
    #   -Luns 0,1,2,3,4    : 백업할 LUN 목록 (기본: 0..7 전부)

  주의:
    - 읽기 전용입니다. 기기 데이터에 아무것도 쓰지 않습니다.
    - --debugmode 는 일부러 안 씁니다 (약 10배 느려짐).
    - 빈 LUN(5~7 등)은 GPT가 없어 에러가 떠도 스크립트는 계속 진행합니다(정상).
    - Windows PowerShell 5.1 및 PowerShell 7 모두 호환.
#>

param(
  [string]$Loader = "xbl_s_devprg_ns.melf",
  [string]$OutDir = "",
  [int[]] $Luns   = @(0,1,2,3,4,5,6,7),
  [switch]$IncludeSuper,
  [switch]$IncludeUserdata,
  [string]$Python = "python"
)

$ErrorActionPreference = "Continue"

# --- sanity checks ---
if (-not (Test-Path ".\edl.py")) {
  Write-Host "[!] edl.py 가 현재 폴더에 없습니다. edl-master 폴더에서 실행하세요." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path ".\$Loader")) {
  Write-Host "[!] 로더 '$Loader' 가 현재 폴더에 없습니다." -ForegroundColor Red
  exit 1
}

if ([string]::IsNullOrEmpty($OutDir)) {
  $OutDir = "backup_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Log = Join-Path $OutDir "backup.log"

# 큰 파티션은 기본 제외
$skipList = @()
if (-not $IncludeSuper)    { $skipList += "super" }
if (-not $IncludeUserdata) { $skipList += "userdata" }
$skip = ($skipList -join ",")

# 전체 세션 로그 (5.1 호환) — 화면 출력은 그대로 보이고 파일에도 기록됨
try { Start-Transcript -Path $Log -Force | Out-Null } catch { }

function Log($msg) {
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg)
}

# edl.py 실행 헬퍼 — 실시간 출력, 실패해도 계속
function Run-Edl([string[]]$edlArgs) {
  Write-Host ("`n>>> python edl.py " + ($edlArgs -join " ")) -ForegroundColor DarkGray
  & $Python edl.py @edlArgs 2>&1 | Out-Host
  return $LASTEXITCODE
}

Log "=== G2 EDL 백업 시작 ==="
Log "출력 폴더 : $OutDir"
Log "로더      : $Loader"
Log "LUN 목록  : $($Luns -join ', ')"
Log "제외      : $(if($skip){$skip}else{'(없음 — super/userdata 포함)'})"
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# --- 1) 각 LUN 의 GPT(파티션표) + 복원용 rawprogram xml ---
Log "--- 1단계: GPT 백업 ---"
$gptDir = Join-Path $OutDir "gpt"
New-Item -ItemType Directory -Force -Path $gptDir | Out-Null
foreach ($lun in $Luns) {
  Log "GPT LUN $lun ..."
  Run-Edl @("gpt", $gptDir, "--lun=$lun", "--genxml", "--memory=UFS", "--loader=$Loader") | Out-Null
}

# --- 2) 각 LUN 의 모든 파티션 덤프 (super/userdata 는 기본 제외) ---
Log "--- 2단계: 파티션 덤프 ---"
foreach ($lun in $Luns) {
  $lunDir = Join-Path $OutDir ("lun{0}" -f $lun)
  New-Item -ItemType Directory -Force -Path $lunDir | Out-Null
  Log "LUN $lun 파티션 읽는 중 (빈 LUN이면 그냥 넘어감) ..."
  $rlArgs = @("rl", $lunDir, "--lun=$lun", "--genxml", "--memory=UFS", "--loader=$Loader")
  if ($skip) { $rlArgs += "--skip=$skip" }
  Run-Edl $rlArgs | Out-Null
}

# --- 3) 무결성: SHA256 매니페스트 + 0바이트 검사 ---
Log "--- 3단계: 무결성 매니페스트 생성 ---"
$manifest = Join-Path $OutDir "SHA256SUMS.txt"
Remove-Item $manifest -ErrorAction SilentlyContinue
$root = (Resolve-Path $OutDir).Path
$files = Get-ChildItem -Path $OutDir -Recurse -File | Where-Object {
  $_.Name -ne "backup.log" -and $_.Name -ne "SHA256SUMS.txt"
}
$zero = @()
foreach ($f in $files) {
  if ($f.Length -eq 0) { $zero += $f.FullName; continue }
  $h   = (Get-FileHash -Algorithm SHA256 -Path $f.FullName).Hash
  $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
  Add-Content -Path $manifest -Value ("{0}  {1}" -f $h, $rel)
}

$sw.Stop()
$mins = [math]::Round($sw.Elapsed.TotalMinutes, 1)
Log "=== 완료 ($mins 분) ==="
Log ("백업 파일 수 : {0}" -f $files.Count)
if ($zero.Count -gt 0) {
  Log "[!] 0바이트 파일 발견 (재확인 필요):"
  $zero | ForEach-Object { Log ("    " + $_) }
} else {
  Log "0바이트 파일 없음 — 정상."
}
Log "매니페스트  : $manifest"
Log ""
Log ">>> 이 폴더($OutDir) 와 로더($Loader) 를 함께 안전한 곳에 보관하세요."
Log ">>> 복원 방법은 docs/g2-edl-backup-runbook.md 참고."

try { Stop-Transcript | Out-Null } catch { }
