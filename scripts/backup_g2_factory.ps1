<#
  backup_g2_factory.ps1  —  Retroid Pocket G2 "factory" full backup (userdata excluded)

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

  읽기 전용 — 기기에 아무것도 쓰지 않습니다. 예상: ~25~28 GB (super+rawdump 포함), ~15~45분
  (userdata 포함 시 +~83 GiB, +1.5~3시간, PC 여유 100 GB+ 필요)

  참고: 한글 Windows 콘솔(cp949)에서 bkerler 진행률 막대(█) 때문에 나던
        UnicodeEncodeError 를 막으려고 Python 을 UTF-8 출력 모드로 강제합니다.
#>

param(
  [string]$Loader = "xbl_s_devprg_ns.melf",
  [string]$OutDir = "",
  [int[]] $Luns   = @(0,1,2,3,4,5,6,7),
  [switch]$IncludeUserdata,
  [string]$Python = "python"
)

$ErrorActionPreference = "Continue"

# --- 인코딩 고정: cp949 UnicodeEncodeError(진행률 막대 █) 방지 ---
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
try { chcp 65001 > $null 2>&1 } catch { }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

if (-not (Test-Path ".\edl.py"))  { Write-Host "[!] edl.py not found. Run from the edl-master folder." -ForegroundColor Red; exit 1 }
if (-not (Test-Path ".\$Loader")) { Write-Host "[!] loader '$Loader' not found." -ForegroundColor Red; exit 1 }

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
Log ("=== G2 factory backup start (exclude userdata: {0}) ===" -f [bool](-not $IncludeUserdata))
Log "out: $OutDir / loader: $Loader / LUNs: $($Luns -join ',')"

# 각 LUN: GPT(gpt_main/backup) + rawprogram xml + 모든 파티션 (rl)
foreach ($lun in $Luns){
  $lunDir = Join-Path $OutDir ("lun{0}" -f $lun)
  New-Item -ItemType Directory -Force -Path $lunDir | Out-Null
  Log "LUN $lun : dumping (empty LUN is skipped) ..."
  $a = @("rl", $lunDir, "--lun=$lun", "--genxml", "--memory=UFS", "--loader=$Loader")
  if ($skip){ $a += "--skip=$skip" }
  Run-Edl $a | Out-Null
  if (-not (Get-ChildItem -Path $lunDir -File -ErrorAction SilentlyContinue)){
    Remove-Item -Path $lunDir -Recurse -Force -ErrorAction SilentlyContinue
    Log "LUN $lun : no partitions (empty) - folder removed"
  }
}

# 무결성: SHA256 매니페스트 + 0바이트 검사
Log "generating SHA256 manifest ..."
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
Log ("=== done ({0} min) ===" -f [math]::Round($sw.Elapsed.TotalMinutes,1))
if ($zero.Count -gt 0){ Log "[!] zero-byte files (re-check needed):"; $zero | ForEach-Object { Log ("    " + $_) } }
else { Log "no zero-byte files - OK." }
Log ">>> keep this folder ($OutDir) together with the loader ($Loader)."
Log ">>> restore guide: docs/g2-edl-backup-runbook.md"
try { Stop-Transcript | Out-Null } catch { }
