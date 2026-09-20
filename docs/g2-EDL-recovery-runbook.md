# G2 slot recovery — EDL runbook (RECOVERED ✅, as-executed)

**Outcome: the bricked G2 was fully recovered, data preserved.** The device now
boots Android 15 from slot b. This document is the as-executed record — the plan
worked, but with several real gotchas that are captured here so the next person
(or the next incident) does not re-discover them.

## What had happened

`fastboot set_active a` (run in fastbootd) set **both** the GPT active slot **and
the UFS boot LUN** to slot a, which has no bootable image → bootloop. Slot b (the
working Android 15) was intact the whole time. Fixing it required setting **both**
the GPT slot **and** the boot LUN back to b — doing only one is not enough.

## The loader (verified, NOT in this repo)

`xbl_s_devprg_ns.melf` — native G2 firehose programmer from the Retroid G2
firmware package (community route). Kept off the repo (vendor firmware). Verified:

| Check | Value |
|---|---|
| Chipset | `TME_FW_CHIPSET_STRING=Palawan` (SM8635 / Cliffs = G2 platform) |
| HWID | `SM_PALAWAN` (= Sahara HWID 002750E1) |
| Signing | no-sign build, matches device `secure:no` |
| Storage | UFS; reported `prod_name HN8T05DEHKX073`, block 4096, 8 LUNs |
| sha256 | `6965176655fa2f7b767b6a3a4ea1aea2a70e621ec4ac8bfc4b82ee47fccbe27b` |

## Host setup (Windows) — what actually worked

1. Python 3 (python.org, "Add to PATH").
2. `git clone https://github.com/bkerler/edl && cd edl && pip install -r requirements.txt`
3. Copy `xbl_s_devprg_ns.melf` into the `edl` folder.
4. G2 into **EDL (9008)**.
5. **Driver: WinUSB via Zadig** (Options → List All Devices → `QUSB_BULK`/9008 →
   WinUSB → Replace Driver). **This is the one that worked.**
   - The **QDLoader 9008 serial** driver does **not** work with bkerler here —
     `--serial` mode misroutes into the legacy HDLC "streaming" protocol and
     hangs. WinUSB (libusb) is required for bkerler.

## Required firehose.py patches (WinUSB read was broken without them)

Two edits to `edlclient\Library\firehose.py` were necessary; without them the
reads hang or crash:

1. **str/bytes fix** (configure TypeError): replace
   `resp=resp, data=rdata, log=log` → `resp=resp, data=resp, log=log`, and
   `return response(resp=status, data=rdata)` → `... data=resp)`.
2. **read no-hang guard** in `cmd_read_buffer`'s read loop — break on repeated
   empty reads:
   ```python
   empty = 0
   while bytestoread > 0:
       tmp = self.cdc.read(min(self.cdc.maxsize, bytestoread))
       size = len(tmp)
       if size == 0:
           empty += 1
           if empty > 20:
               break
           continue
       empty = 0
       bytestoread -= size
       resData.extend(tmp)
       progbar.show_progress(prefix="Read", pos=total - bytestoread, total=total, display=display)
   ```

## Command-form gotchas (learned the hard way)

- **Memory type auto-detects.** The loader reports UFS, and bkerler sets
  4096-byte sectors automatically. `--memory=UFS` is **accepted** by
  `printgpt`/`r`/`gpt`/`rl` but **rejected** by `getactiveslot`/`setactiveslot`
  (they have no such option — passing it just prints the usage help and does
  nothing). So: omit `--memory` for the slot commands; it is optional elsewhere.
- **Do NOT use `--debugmode` for real transfers** — it is ~10× slower. Use it
  only to diagnose a hang.
- `--setactivepartition` (fh_loader) is **not** a slot switch — it emits
  `setbootablestoragedrive` (boot LUN only). The GPT A/B flip is a different
  operation (`setactiveslot`). Both were needed here, separately.

## The sequence that recovered the device

All from the `edl` folder, device in EDL(9008), WinUSB bound, patches applied.

```
# 1. read-only: prove loader + read path work, confirm current slot
python edl.py printgpt --loader=xbl_s_devprg_ns.melf --memory=UFS --lun=0
python edl.py getactiveslot --loader=xbl_s_devprg_ns.melf          # -> a

# 2. flip GPT active slot to b  (the first write)
python edl.py setactiveslot b --loader=xbl_s_devprg_ns.melf
python edl.py getactiveslot --loader=xbl_s_devprg_ns.melf          # -> b

# 3. flip the UFS boot LUN to b's xbl  (the second write — this device needs it)
python edl.py setbootablestoragedrive 2 --loader=xbl_s_devprg_ns.melf

# 4. reboot
python edl.py reset --loader=xbl_s_devprg_ns.melf                  # 'Pipe error' = normal (device dropped USB to reboot)
```

### Known bug in `setactiveslot` (harmless here, but read this)

`cmd_setactiveslot` loops over **all** LUNs and dereferences `guid_gpt_a.header`
one line **before** its `None` check. This device has empty LUNs (5–7) with no
GPT, so on reaching one it crashes with
`'NoneType' object has no attribute 'header'`.

**Crucially, by the time it crashes it has already patched every real slotted
partition on LUN 0–4 (primary + backup GPT, CRCs fixed) — 3814 patch ops in our
run.** The crash is on empty LUNs that have nothing to switch, so the switch is
effectively complete anyway. Verify with `getactiveslot` → it reported `b`.

If you want a clean run (or a re-run), add the guard in `cmd_setactiveslot`:
```python
        gpt_data_a, guid_gpt_a = self.get_gpt(lun_a, int(0), int(0), int(0))
        if guid_gpt_a is None:
            continue
        backup_gpt_data_a, backup_guid_gpt_a = self.get_gpt(lun_a, 0, 0, 0, guid_gpt_a.header.backup_lba)
```
Re-running is safe: for an already-switched device it early-returns on the first
`_a` partition without writing.

## Boot-LUN detail

- `setactiveslot b` alone left the device at the **bootloader** screen (ABL
  `ValidateSlotGuids` saw GPT=b but boot LUN still =a → refused to boot HLOS).
- `setbootablestoragedrive 2` (bBootLunEn → boot LUN B, where xbl_b lives)
  matched them, and the device advanced past ABL.
- Boot-LUN mapping: **1 = slot a, 2 = slot b** on this device (confirmed working).

## Last step: fastbootd, then Android

After the boot-LUN fix the device booted **into fastbootd** (userspace fastboot —
which means boot_b's kernel+ramdisk actually ran; the switch worked). It landed
there because of a leftover `boot-fastboot` command in the **misc/BCB** partition
from the original fastbootd session. Resolved by rebooting to system (recovery
clears the BCB command on entry). If it ever sticks in fastbootd:
```
python edl.py e misc --loader=xbl_s_devprg_ns.melf   # clears the stale boot command; slot info lives in GPT, so this is safe
python edl.py reset --loader=xbl_s_devprg_ns.melf
```

## Safety notes / lessons

- EDL (9008) is in mask-ROM PBL — always reachable; nothing here can remove it.
- Every write here is tiny reversible metadata (GPT attrs, boot LUN, misc). No
  boot/super/userdata was touched; data was preserved end to end.
- **Never** run `set_active` in fastboot/fastbootd toward a slot that lacks a
  bootable image. That is exactly what caused this.
- Keep the loader `xbl_s_devprg_ns.melf` **and** a partition backup off-device
  (see `g2-edl-backup-runbook.md`) so a future incident is a 5-minute fix.
