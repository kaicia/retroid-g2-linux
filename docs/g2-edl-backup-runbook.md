# G2 EDL backup runbook (do this while the device is healthy)

Purpose: capture the partitions needed to recover from a future slot/boot
accident, so the fix in `g2-EDL-recovery-runbook.md` is a 5-minute restore.

Run with the same setup that did the recovery: device in **EDL (9008)**, **WinUSB
(Zadig)** driver, from the `edl` folder, with the verified loader
`xbl_s_devprg_ns.melf` present and the two `firehose.py` patches applied (see the
recovery runbook). Reads are non-destructive.

> Note: `getactiveslot`/`setactiveslot` reject `--memory`; `printgpt`/`r`/`gpt`/
> `rl` accept it. Memory type auto-detects as UFS regardless. **Do not add
> `--debugmode`** — it makes transfers ~10× slower.

## One-shot script (recommended)

`scripts/backup_g2_edl.ps1` does all of this automatically: every LUN's GPT +
every partition (super/userdata skipped by default), a full session log, and a
`SHA256SUMS.txt` integrity manifest with a 0-byte check. Copy it into the
`edl-master` folder and run:

```
powershell -ExecutionPolicy Bypass -File .\backup_g2_edl.ps1
```
Options: `-IncludeSuper`, `-IncludeUserdata`, `-OutDir <path>`,
`-Loader <file>`, `-Luns 0,1,2,3,4`. Output lands in `backup_YYYYMMDD_HHMMSS\`.

The manual steps below are the equivalent, for reference or partial backups.

## 0. Prep
```powershell
cd C:\Users\KAICIA\Downloads\edl-master
mkdir backup -Force
```

## 1. GPT / partition tables
> ⚠️ **Do NOT use `edl.py gpt`** — in this bkerler version its file writes are
> commented out, so it saves nothing, never creates the folder, and crashes on
> `--genxml` (`FileNotFoundError: rawprogram0.xml`). Use `rl` (step 3) instead:
> it writes `gpt_main{lun}.bin`, `gpt_backup{lun}.bin` and `rawprogram{lun}.xml`
> per LUN automatically. To only *view* the table (no file), use
> `python edl.py printgpt --lun=0 --memory=UFS --loader=xbl_s_devprg_ns.melf`.

## 2. Recovery-critical partitions, both slots (~3–8 min, ~1–1.5 GB)
```powershell
$L = "xbl_s_devprg_ns.melf"
$parts = @(
  "xbl","xbl_config","aop","tz","hyp","abl","devcfg","keymaster","uefi","uefisecapp",
  "boot","init_boot","vendor_boot","dtbo","vbmeta","vbmeta_system","recovery",
  "featenabler","cpucp","shrm","imagefv","qupfw","dsp","modem","bluetooth"
)
foreach ($p in $parts) {
  foreach ($s in "a","b") {
    $n = "${p}_$s"
    python edl.py r $n "backup\$n.img" --loader=$L --memory=UFS
  }
}
```
Partitions that don't exist print "cannot find partition" and are skipped
(harmless). The big ones (`modem_*`, `vendor_boot_*`, `boot_*`) dominate the time.

## 3. Optional full dump, minus the huge partitions (~10–30 min, ~2–4 GB)
```
python edl.py rl backup_full --skip=super,userdata --genxml --memory=UFS --loader=xbl_s_devprg_ns.melf
```

## 4. Verify + store
```powershell
dir backup | Select Name,Length     # confirm no 0-byte files
```
Store `backup\` **and** the loader `xbl_s_devprg_ns.melf` together off-device
(cloud/external). The loader is required to enter firehose for any restore.

## Restore later (reference)
```
python edl.py w boot_a backup\boot_a.img --loader=xbl_s_devprg_ns.melf --memory=UFS
# slot / boot-LUN pointers if needed:
python edl.py setactiveslot b --loader=xbl_s_devprg_ns.melf
python edl.py setbootablestoragedrive 2 --loader=xbl_s_devprg_ns.melf   # 1=slot a, 2=slot b
python edl.py reset --loader=xbl_s_devprg_ns.melf
```

## Time & size estimates (EDL over USB2, ~10–20 MB/s effective)

Sizes are from this device's GPT (128 GB UFS, ~107 GiB usable):

| Target | Size | Time |
|---|---|---|
| GPT (via rl) | tens of KB | < 10 s |
| critical partitions (a/b) | ~1–1.5 GB | ~3–8 min |
| all firmware (no super/userdata) | ~2–4 GB | ~10–30 min |
| **super** (OS logical partition) | **≈ 12 GB** | **~10–20 min** |
| **userdata** (your data, encrypted) | **≈ 83 GiB (~89 GB)** | **~1.5–3 hours** |
| **everything incl. super + userdata** | **≈ 100+ GB** | **~2–4 hours** |

Notes if including the big two:
- Needs **100+ GB free** on the PC drive where the backup folder lives.
- `userdata` is your live, **FBE-encrypted** data — the dump is an opaque blob
  (restorable, not browsable) and is **not needed for slot/boot recovery**.
- `super` (system/vendor/product) is intact and reflashable from the firmware
  package; not needed for slot recovery either.
- So for unbricking, **skip both** (the default). Include them only for a full
  offline clone, with the disk space and hours above.

Minimum useful backup = **critical partitions + GPT** (~5–10 min, default run).
