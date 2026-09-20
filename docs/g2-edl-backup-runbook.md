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

## 0. Prep
```powershell
cd C:\Users\KAICIA\Downloads\edl-master
mkdir backup -Force
```

## 1. GPT / partition tables (most important, seconds)
```
python edl.py gpt backup\gpt --genxml --memory=UFS --loader=xbl_s_devprg_ns.melf
```
Saves each LUN's GPT plus a `rawprogram` XML for restore.

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

## Time estimates (EDL over USB2, ~10–20 MB/s effective)
| Step | Size | Time |
|---|---|---|
| 1. GPT | tens of KB | < 10 s |
| 2. critical partitions (a/b) | ~1–1.5 GB | ~3–8 min |
| 3. full dump (no super/userdata) | ~2–4 GB | ~10–30 min |

Minimum useful backup = **steps 1 + 2** (~5–10 min).
