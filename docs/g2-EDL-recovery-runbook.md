# G2 slot recovery — EDL runbook (loader verified)

The loader is in hand and verified. This is the step-by-step fix.

## Loader verification (passed)

`xbl_s_devprg_ns.melf`, received from the Retroid G2 firmware package via the
community (moustafa.nl's route). Not committed to this repo — it is vendor
firmware. Verified from its own strings:

| Check | Value |
|---|---|
| Chipset | `TME_FW_CHIPSET_STRING=Palawan` (SM8635 / Cliffs = the G2 platform) |
| Variant | `IMAGE_VARIANT_STRING=SocPalawanLAA` |
| HWID name | `SM_PALAWAN` (= Sahara HWID 002750E1) |
| Programmer | `devprg_entry.c` — dev (firehose) programmer |
| Signing | `TME_FW_NS_DUMP` — no-sign build, matches this device's `secure:no` |
| Storage | UFS boot interface supported |
| QC version | `BOOT.MXF.2.1-02003-LANAI-1` |
| sha256 | `6965176655fa2f7b767b6a3a4ea1aea2a70e621ec4ac8bfc4b82ee47fccbe27b` |

This is the native G2 programmer, so the derivative-mismatch worry from the Moto
substitute route does not apply.

## What we are doing and why it is minimal

Only the active-slot state is wrong. boot_a/boot_b are intact (the Tier-0 flash
was refused). `edl.py`'s `cmd_setactiveslot` patches only the GPT attribute
flags (0x6f active / 0x3a inactive on the boot partitions) — exactly what ABL's
`FindBootableSlot` reads. It does **not** touch the UFS boot LUN; that is a
separate `setbootablestoragedrive` command, applied only if needed (see step 8).

## Host setup (Windows)

1. Install **Python 3** (python.org; tick "Add to PATH").
2. Get the tool and its deps:
   ```
   git clone https://github.com/bkerler/edl
   cd edl
   pip install -r requirements.txt
   ```
3. Copy `xbl_s_devprg_ns.melf` into the `edl` folder.
4. Put the G2 in **EDL**: bootloader menu -> **Emergency mode**. PC shows
   `QUSB_BULK_CID:045B`.
5. **Zadig** (zadig.akeo.ie) -> Options -> List All Devices -> select the
   `QUSB_BULK` / 9008 entry -> target **WinUSB** -> Replace Driver.
   (bkerler/edl speaks libusb, not the QDLoader serial driver QFIL uses.)

## Step 1 — read-only: prove the loader runs on this silicon (writes nothing)

```
python edl.py --loader=xbl_s_devprg_ns.melf printgpt --memory=ufs
```

- The tool loads the programmer over Sahara, then prints the partition table.
- **Expect** to see `boot_a`, `boot_b`, `super`, `userdata`, `xbl_a` … at the
  sizes `fastboot getvar all` reported. That proves DDR + UFS init worked on
  this die.
- Hang, garbage, or a Sahara error -> **stop**. Nothing was written. Tell Claude
  the exact output. (Also: if the tool says the device is in "firehose"/dump
  mode 900E rather than 9008, the programmer will not load — report that.)

## Step 2 — read-only: confirm current slot

```
python edl.py --loader=xbl_s_devprg_ns.melf getactiveslot
```
Expect `a`. (Matches `fastboot getvar current-slot`.)

## Step 3 — the fix (the one write)

```
python edl.py --loader=xbl_s_devprg_ns.melf setactiveslot b
```

## Step 4 — confirm, still read-only

```
python edl.py --loader=xbl_s_devprg_ns.melf getactiveslot
```
Expect `b`.

## Step 5 — reboot and test

```
python edl.py --loader=xbl_s_devprg_ns.melf reset
```
The device reboots. **Expected: it boots Android from slot b.**

## Step 6 — only if it does NOT boot Android (lands in fastboot / bootloops)

That is the `ValidateSlotGuids` boot-LUN-vs-slot mismatch (ABL wants UFS boot
LUN 2 for slot b). Back into EDL, then:
```
python edl.py --loader=xbl_s_devprg_ns.melf setbootablestoragedrive 2
python edl.py --loader=xbl_s_devprg_ns.melf reset
```
This is separated out deliberately: it is only run if step 5 fails, so an
unnecessary boot-LUN write is avoided. EDL always remains reachable if anything
goes sideways.

## Fallbacks (not expected to be needed)

- If a partition turns out to be damaged after all, Mike's community boot backup
  (verified genuine G2, but Android 14 not 15) or a full flash from the Retroid
  firmware package with QFIL are the heavier options.
- Nothing here writes boot/super/userdata; the only writes are the GPT slot
  attributes (step 3) and, conditionally, the UFS boot LUN (step 6).

## Safety

EDL is handled by the PBL in mask ROM, so it is always reachable; no step here
can remove it. The two writes are tiny metadata changes, both reversible from
EDL. Slot b's Android is intact throughout.
