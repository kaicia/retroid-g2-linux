# The EDL route, made concrete — and a caution of mine that was too broad

## The fix is one command, not a firmware flash

`bkerler/edl` implements **`setactiveslot`**:

```
edl --loader=<programmer.elf> setactiveslot b
```

That writes the GPT partition attribute bits — exactly the thing that is wrong
on this device and the one thing no bootloader command here can touch. Slot b's
Android is intact, so this alone would end the problem. No firmware package, no
reflash, nothing erased.

So the whole situation reduces to obtaining **one file** that runs on this SoC.

## A read-only gate exists, which changes the risk

Earlier in this investigation I wrote that trying a programmer built for another
SoC "is not a harmless failure to attempt." **That was too broad, and it closed
a door that is not actually closed.**

`edl printgpt` reads the partition table and writes nothing:

```
edl --loader=<candidate.elf> printgpt --memory=ufs
```

A programmer does not touch storage while initialising — it brings up DDR, the
UFS controller and USB, then waits for XML commands. We choose those commands.
So a candidate can be loaded and then asked only to *read*:

- **Partition table comes back correct** → the programmer runs on this silicon,
  and `setactiveslot b` is safe to issue.
- **Garbage, or nothing** → stop. Nothing was written.

The residual risk is a hang or a reset, from which the device returns to the
same state it is in now. That is a real risk but a much smaller one than the
blanket warning implied, and the verification step is what makes the difference.

This does not make a cross-SoC programmer *likely* to work — a firehose is built
for the DDR and UFS controllers of one chip. It makes trying one a bounded
experiment rather than a gamble.

## First, the one read that costs nothing and needs no programmer

In EDL, before any programmer is loaded, the Sahara protocol exchanges a hello
that carries the device's **MSM HW ID**, serial, and OEM public-key hash — and
reveals whether the PBL will accept an unsigned programmer at all.

`bkerler/edl` prints all of this on connect, even when it has no loader to send.
That is the single highest-value action available right now, because:

- The HW ID is how firehose files are named and matched. Searching without it is
  guesswork; searching with it is exact.
- If the PBL reports that unsigned programmers are accepted — which
  `SECURE BOOT - no` on the device's own screen suggests — then any *correct*
  programmer works, not only Retroid's signed one.

### Windows setup

`bkerler/edl` speaks USB directly through libusb, so it needs **WinUSB bound to
the 9008 device** — not the Qualcomm QDLoader serial driver that QFIL wants.
This matters: installing the wrong one makes the tool report no device.

1. Device into EDL: bootloader menu → **Emergency mode**. The PC shows
   `QUSB_BULK_CID:045B_SN:45604CF1`.
2. **Zadig** (<https://zadig.akeo.ie>) → Options → List All Devices → select that
   entry → target driver **WinUSB** → Replace Driver.
3. Python 3, then:

```
git clone https://github.com/bkerler/edl
cd edl
pip install -r requirements.txt
python edl printgpt --memory=ufs
```

It will fail for want of a loader. **The lines it prints before failing are the
point** — HW ID, serial, PK hash, and whether signing is enforced.
