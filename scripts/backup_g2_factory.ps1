<#
  backup_g2_factory.ps1  —  Retroid Pocket G2 "공장복원용" 전체 백업 (userdata만 제외)

  이 스크립트 하나면 gpt + core + full + super 가 전부 포함됩니다 (userdata 만 빠짐).
  소프트웨어/펌웨어 벽돌은 이걸로 거의 다 복구 가능.

  준비:
    - 기기 EDL(9008) 진입, Zadig 로 WinUSB 바인딩
    - 로더 xbl_s_devprg_ns.melf 를 edl-master 폴더에 둘 것
    - firehose.py 패치 2개 적용 (recovery runbook 참고)

  실행 (edl-master 폴더에서, 옵션 필요 없음):
    powershell -ExecutionPolicy Bypass -File .\backup_g2_factory.ps1

    # userdata(개인 데이터)까지 완전 클론하려면:
    powershell -ExecutionPolicy Bypass -File .\backup_g2_factory.ps1 -IncludeUserdata

  읽기 전용 — 기기에 아무것도 쓰지 않습니다. 예상: ~15~20 GB, ~20~45분
  (userdata 포함 시 +~83 GiB, +1.5~3시간, PC 여유 100 GB+ 필요)
#>

param(
  [string]$Loader = "xbl_s_devprg_ns.melf",
  [string]$OutDir = "",
  [int[]] $Luns   = @(0,1,2,3,4,5,6,7),
  [switch]$IncludeUserdata,
  [string]$Python = "python"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path ".\edl.py"))  { Write-Host "[!] edl.py 없음. edl-master 폴더에서 실행하세요." -ForegroundColor Red; exit 1 }
if (-not (Test-Path ".\$Loader")) { Write-Host "[!] 로더 '$Loader' 없음." -ForegroundColor Red; exit 1 }

if ([string]::IsNullOrEmpty($OutDir)) { $OutDir = "backup_factory_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
try { Start-Transcript -Path (Join-Path $OutDir "backup.log") -Force | Out-Null } catch { }

# userdata 만 제외 (super 포함). -IncludeUserdata 면 아무것도 제외 안 함.
$skip = if ($IncludeUserdata) { "" } else { "userdata" }

function Log($m){ Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m) }
function Run-Edl([string[]]$a){
  Write-Host ("`n>>> python edl.py " + ($a -join " ")) -ForegroundColor DarkGray
  & $Python edl.py @a 2>&1 | Out-Host
  return $LASTEXITCODE
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Log "=== G2 공장복원용 백업 시작 (userdata 제외: $([bool](-not $IncludeUserdata))) ==="
Log "출력 폴더: $OutDir / 로더: $Loader / LUN: $($Luns -join ',')"

# 각 LUN: GPT(gpt_main/backup) + rawprogram xml + 모든 파티션 (rl)
foreach ($lun in $Luns){
  $lunDir = Join-Path $OutDir ("lun{0}" -f $lun)
  New-Item -ItemType Directory -Force -Path $lunDir | Out-Null
  Log "LUN $lun 덤프 중 (빈 LUN이면 넘어감) ..."
  $a = @("rl", $lunDir, "--lun=$lun", "--genxml", "--memory=UFS", "--loader=$Loader")
  if ($skip){ $a += "--skip=$skip" }
  Run-Edl $a | Out-Null
  if (-not (Get-ChildItem -Path $lunDir -File -ErrorAction SilentlyContinue)){
    Remove-Item -Path $lunDir -Recurse -Force -ErrorAction SilentlyContinue
    Log "LUN $lun : 파티션 없음 (빈 LUN) — 폴더 삭제"
  }
}

# 무결성: SHA256 매니페스트 + 0바이트 검사
Log "무결성 매니페스트 생성 ..."
$man  = Join-Path $OutDir "SHA256SUMS.txt"
Remove-Item $man -ErrorAction SilentlyContinue
$root = (Resolve-Path $OutDir).Path
$zero = @()
Get-ChildItem -Path $OutDir -Recurse -File | Where-Object { $_.Name -ne "SHA256SUMS.txt" -and $_.Name -ne "backup.log" } | ForEach-Object {
  if ($_.Length -eq 0){ $zero += $_.FullName; return }
  $h   = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
  $rel = $_.FullName.Substring($root.Length).TrimStart('\','/')
  Add-Content -Path $man -Value ("{0}  {1}" -f $h, $rel)
}

$sw.Stop()
Log ("=== 완료 ({0} 분) ===" -f [math]::Round($sw.Elapsed.TotalMinutes,1))
if ($zero.Count -gt 0){ Log "[!] 0바이트 파일 (재확인 필요):"; $zero | ForEach-Object { Log ("    " + $_) } }
else { Log "0바이트 파일 없음 — 정상." }
Log ">>> 이 폴더($OutDir) 와 로더($Loader) 를 함께 안전한 곳에 보관하세요."
Log ">>> 복원 방법: docs/g2-edl-backup-runbook.md"
try { Stop-Transcript | Out-Null } catch { }
