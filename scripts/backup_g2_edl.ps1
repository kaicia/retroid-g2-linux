<#
  backup_g2_edl.ps1  —  Retroid Pocket G2 EDL 백업 (bkerler/edl), 4단계 선택식

  준비 (recovery/backup runbook과 동일):
    - 기기 EDL(9008) 진입, Zadig 로 WinUSB 바인딩
    - 로더 xbl_s_devprg_ns.melf 를 edl-master 폴더에 둘 것
    - firehose.py 패치 2개 적용 (str/bytes, 읽기 무한멈춤 방지)

  실행 (edl-master 폴더에서):
    powershell -ExecutionPolicy Bypass -File .\backup_g2_edl.ps1 -Tier core

  -Tier 값 (여러 개 지정 가능, 쉼표):
    gpt      : GPT(파티션표)만            (~1 MB,      <1분)
    core     : 핵심 파티션 a/b + GPT       (~1~1.5 GB,  ~3~8분)
    full     : 전체 덤프, super/userdata 제외 (~2~4 GB, ~10~30분)
    factory  : 공장복원용 = userdata만 제외(super 포함) (~15~20 GB, ~20~45분)
    all      : 위 4개를 각각 별도 폴더로 전부

  예:
    -Tier gpt
    -Tier core
    -Tier full
    -Tier factory
    -Tier all
    -Tier gpt,core

  참고: tier 는 포함관계입니다 (factory ⊃ full ⊃ gpt, core 는 full 의 일부).
        전부 다 뜨고 싶으면 factory 하나만 떠도 userdata 빼고 다 들어갑니다.
        userdata 까지 원하면 -IncludeUserdata 를 factory 와 함께 쓰세요.

  전부 읽기 전용 — 기기에 아무것도 쓰지 않습니다. --debugmode 안 씀(10배 느림).
#>

param(
  [ValidateSet("gpt","core","full","factory","all")]
  [string[]]$Tier = @("core"),
  [string]$Loader = "xbl_s_devprg_ns.melf",
  [string]$OutDir = "",
  [int[]] $Luns   = @(0,1,2,3,4,5,6,7),
  [switch]$IncludeUserdata,     # factory 에 userdata 까지 포함 (매우 큼)
  [string]$Python = "python"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path ".\edl.py"))     { Write-Host "[!] edl.py 없음. edl-master 폴더에서 실행하세요." -ForegroundColor Red; exit 1 }
if (-not (Test-Path ".\$Loader"))    { Write-Host "[!] 로더 '$Loader' 없음." -ForegroundColor Red; exit 1 }

if ($Tier -contains "all") { $Tier = @("gpt","core","full","factory") }

if ([string]::IsNullOrEmpty($OutDir)) { $OutDir = "backup_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
try { Start-Transcript -Path (Join-Path $OutDir "backup.log") -Force | Out-Null } catch { }

# 핵심 파티션 목록 (core). 없는 건 자동으로 건너뜀.
$CoreParts = @(
  "xbl","xbl_config","aop","aop_config","tz","hyp","abl","devcfg","keymaster",
  "uefi","uefisecapp","multiimgoem","multiimgqti","featenabler","cpucp","cpucp_dtb",
  "shrm","imagefv","qupfw","dsp","modem","bluetooth",
  "boot","init_boot","vendor_boot","dtbo","vbmeta","vbmeta_system","recovery"
)

function Log($m){ Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $m) }
function Run-Edl([string[]]$a){
  Write-Host ("`n>>> python edl.py " + ($a -join " ")) -ForegroundColor DarkGray
  & $Python edl.py @a 2>&1 | Out-Host
  return $LASTEXITCODE
}
function New-Manifest($dir){
  $man = Join-Path $dir "SHA256SUMS.txt"
  Remove-Item $man -ErrorAction SilentlyContinue
  $root = (Resolve-Path $dir).Path
  $zero = @()
  Get-ChildItem -Path $dir -Recurse -File | Where-Object { $_.Name -notin @("SHA256SUMS.txt") } | ForEach-Object {
    if ($_.Length -eq 0) { $zero += $_.FullName; return }
    $h = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
    $rel = $_.FullName.Substring($root.Length).TrimStart('\','/')
    Add-Content -Path $man -Value ("{0}  {1}" -f $h, $rel)
  }
  if ($zero.Count -gt 0){ Log "[!] 0바이트 파일:"; $zero | ForEach-Object { Log ("    " + $_) } }
  else { Log "0바이트 파일 없음 — 정상." }
}

# --- tier 구현 ---
function Backup-Gpt($dir){
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  foreach ($lun in $Luns){
    Log "GPT LUN $lun ..."
    Run-Edl @("r","gpt",(Join-Path $dir "gpt"),"--lun=$lun","--memory=UFS","--loader=$Loader") | Out-Null
  }
}
function Backup-Core($dir){
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  Backup-Gpt (Join-Path $dir "gpt")
  foreach ($p in $CoreParts){
    foreach ($s in "a","b"){
      $n = "${p}_$s"
      Run-Edl @("r",$n,(Join-Path $dir "$n.img"),"--memory=UFS","--loader=$Loader") | Out-Null
    }
  }
}
function Backup-Rl($dir,$skip){
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  foreach ($lun in $Luns){
    $lunDir = Join-Path $dir ("lun{0}" -f $lun)
    New-Item -ItemType Directory -Force -Path $lunDir | Out-Null
    Log "LUN $lun 덤프 중 (빈 LUN이면 넘어감) ..."
    $a = @("rl",$lunDir,"--lun=$lun","--genxml","--memory=UFS","--loader=$Loader")
    if ($skip){ $a += "--skip=$skip" }
    Run-Edl $a | Out-Null
    if (-not (Get-ChildItem -Path $lunDir -File -ErrorAction SilentlyContinue)){
      Remove-Item -Path $lunDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Log "=== G2 EDL 백업 시작 — tier: $($Tier -join ', ') ==="
Log "출력 폴더: $OutDir / 로더: $Loader / LUN: $($Luns -join ',')"

foreach ($t in $Tier){
  $tdir = Join-Path $OutDir $t
  Log "----- [$t] 시작 -----"
  switch ($t){
    "gpt"     { Backup-Gpt $tdir }
    "core"    { Backup-Core $tdir }
    "full"    { Backup-Rl $tdir "super,userdata" }
    "factory" {
                 $sk = if ($IncludeUserdata) { "" } else { "userdata" }
                 Backup-Rl $tdir $sk
               }
  }
  Log "무결성 매니페스트 ($t) ..."
  New-Manifest $tdir
  Log "----- [$t] 완료 -----"
}

$sw.Stop()
Log ("=== 전체 완료 ({0} 분) ===" -f [math]::Round($sw.Elapsed.TotalMinutes,1))
Log ">>> 이 폴더($OutDir) 와 로더($Loader) 를 함께 안전한 곳에 보관하세요."
Log ">>> 복원 방법: docs/g2-edl-backup-runbook.md"
try { Stop-Transcript | Out-Null } catch { }
