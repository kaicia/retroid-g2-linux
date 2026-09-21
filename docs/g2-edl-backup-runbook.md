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

## One-shot script (recommended) — 4 tiers

`scripts/backup_g2_edl.ps1` picks a backup tier with `-Tier`. Each tier writes
its own folder, a full session log, and a `SHA256SUMS.txt` with a 0-byte check.
Copy the script into the `edl-master` folder and run:

```
powershell -ExecutionPolicy Bypass -File .\backup_g2_edl.ps1 -Tier core
```

| `-Tier` | Contents | Size | Time |
|---|---|---|---|
| `gpt` | partition tables only (`r gpt`, 32 sectors/LUN) | ~1 MB | < 1 min |
| `core` | key partitions a/b (boot, xbl, abl, vbmeta, dtbo, modem…) + GPT | ~1–1.5 GB | ~3–8 min |
| `full` | all firmware, **super + userdata excluded** | ~2–4 GB | ~10–30 min |
| `factory` | **userdata excluded only** (super included) — reflash to clean state | ~15–20 GB | ~20–45 min |
| `all` | the four above, each in its own folder | ~20–26 GB | ~35–80 min |

Tiers nest: `factory ⊃ full ⊃ gpt`, and `core` is a curated subset of `full`.
**For a complete offline image, `-Tier factory` alone is enough** (everything but
your userdata). Add userdata with `-Tier factory -IncludeUserdata` (adds ~83 GiB
and 1.5–3 h; needs 100+ GB free).

Other options: `-OutDir <path>`, `-Loader <file>`, `-Luns 0,1,2,3,4`.
Output root: `backup_YYYYMMDD_HHMMSS\<tier>\`.

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

Sizes are from this device's GPT (128 GB UFS, ~107 GiB usable). Big partitions:
**super ≈ 12 GB**, **userdata ≈ 83 GiB (~89 GB)**.

| Tier | Contents | Size | Time |
|---|---|---|---|
| gpt | partition tables only | ~1 MB | < 1 min |
| core | key partitions a/b + GPT | ~1–1.5 GB | ~3–8 min |
| full | all firmware (no super/userdata) | ~2–4 GB | ~10–30 min |
| factory | all except userdata (super in) | ~15–20 GB | ~20–45 min |
| all four (separate folders) | — | ~20–26 GB | ~35–80 min |
| + userdata (`-IncludeUserdata`) | adds encrypted data blob | +~83 GiB | +~1.5–3 h |

Notes if including the big two:
- Needs **100+ GB free** on the PC drive where the backup folder lives.
- `userdata` is your live, **FBE-encrypted** data — the dump is an opaque blob
  (restorable, not browsable) and is **not needed for slot/boot recovery**.
- `super` (system/vendor/product) is intact and reflashable from the firmware
  package; not needed for slot recovery either.
- So for unbricking, **skip both** (the default). Include them only for a full
  offline clone, with the disk space and hours above.

Minimum useful backup = **critical partitions + GPT** (~5–10 min, default run).
