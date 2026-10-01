#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""
Find our kernel's log in a Qualcomm crash RAM dump, taken with edl.py memorydump
from 900E mode, and optionally render the framebuffer region.

Read-only: it opens dump files and writes text and BMP files next to them.

Usage:
  python g2-ramdump-scan.py <memory dir or .BIN files...> [--marker "Linux version 7.1"]
  python g2-ramdump-scan.py --fb <DDR .BIN file> <base address of that file>
  python g2-ramdump-scan.py --resetinfo <memory dir>

Log mode scans every file for the marker and for "Booting Linux". For each hit it
writes <file>.<offset>.log.txt: the printable text from the hit to the end of the
printk text ring. The ring stores each message's text after an 8-byte binary
header, so the output is readable line by line. A crash or hang shows as the last
lines.

The marker defaults to our kernel's banner, so the stale Android
"Linux version 6.1..." left in DRAM from earlier boots is skipped.

FB mode cuts the 1080x1920 a8r8g8b8 simple-framebuffer at 0xe3940000 out of the
dump and writes fb-e3940000.bmp. The <base address> is the physical address the
file starts at, from the edl.py table line "XXX.BIN(...): Offset 0x..., Length
...". The BMP shows whether fbcon drew there. If it shows kernel text while the
screen stayed on the ABL log, the panel was scanning a different buffer.
"""

import mmap
import os
import struct
import sys

FB_ADDR = 0xE3940000
FB_W, FB_H = 1080, 1920
FB_STRIDE = FB_W * 4
WINDOW = 8 * 1024 * 1024    # log_buf_len=4M + initcall_debug: keep the whole ring


def printable_lines(buf):
    out, cur = [], bytearray()
    for b in buf:
        if 32 <= b < 127 or b in (9,):
            cur.append(b)
        else:
            if len(cur) >= 4:
                out.append(cur.decode("ascii", "replace"))
            cur = bytearray()
    if len(cur) >= 4:
        out.append(cur.decode("ascii", "replace"))
    return out


def scan(paths, marker):
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += [os.path.join(p, f) for f in sorted(os.listdir(p))
                      if f.lower().endswith(".bin")]
        else:
            files.append(p)
    found = 0
    for f in files:
        size = os.path.getsize(f)
        if size == 0:
            continue
        with open(f, "rb") as fh, mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ) as m:
            print("scanning %s (%d MiB)" % (f, size >> 20))
            pos = 0
            while True:
                i = m.find(marker, pos)
                if i < 0:
                    break
                # back up a little to catch messages logged before the banner
                start = max(0, i - 4096)
                chunk = m[start:min(size, i + WINDOW)]
                # stop at the first long zero run: the unused tail of the ring
                z = chunk.find(b"\x00" * 256, i - start)
                if z > 0:
                    chunk = chunk[:z]
                lines = printable_lines(chunk)
                out = "%s.%08x.log.txt" % (f, i)
                with open(out, "w", encoding="utf-8") as o:
                    o.write("\n".join(lines) + "\n")
                print("  HIT at file offset 0x%x -> %s (%d lines)" % (i, out, len(lines)))
                for ln in lines[-15:]:
                    print("    | " + ln)
                found += 1
                pos = i + len(marker)
    if not found:
        print("no hit for %r. Try --marker \"Booting Linux\" or send the edl.py table output" % marker)
    return 0 if found else 1


def fb(path, base):
    off = FB_ADDR - base
    size = os.path.getsize(path)
    if off < 0 or off + FB_STRIDE * FB_H > size:
        raise SystemExit("0x%x is not inside %s (base 0x%x, size 0x%x)" % (FB_ADDR, path, base, size))
    with open(path, "rb") as fh:
        fh.seek(off)
        raw = fh.read(FB_STRIDE * FB_H)
    # BMP, 32bpp, top-down rows (negative height); a8r8g8b8 little-endian is B,G,R,A in memory.
    hdr = b"BM" + struct.pack("<IHHI", 54 + len(raw), 0, 0, 54)
    dib = struct.pack("<IiiHHIIiiII", 40, FB_W, -FB_H, 1, 32, 0, len(raw), 2835, 2835, 0, 0)
    out = os.path.join(os.path.dirname(path) or ".", "fb-e3940000.bmp")
    with open(out, "wb") as o:
        o.write(hdr + dib + raw)
    nz = sum(1 for i in range(0, len(raw), 4096) if raw[i:i + 4096].strip(b"\x00"))
    print("wrote %s  (%d of %d 4K pages non-zero)" % (out, nz, len(raw) // 4096))
    return 0


RESET_FILES = ["RST_STAT.BIN", "FSM_STS.BIN", "FSM_CTRL.BIN", "DBG_EN.BIN",
               "PMIC_PON.BIN", "PMPONHIS.BIN", "PMON_HIS.BIN", "CD_STRCT.BIN"]


def resetinfo(d):
    """Print the small reset-reason regions as hex, and load.cmm as text, for pasting."""
    for name in RESET_FILES:
        p = os.path.join(d, name)
        if not os.path.exists(p):
            print("%-13s (missing)" % name)
            continue
        data = open(p, "rb").read()
        print("%-13s %d bytes" % (name, len(data)))
        for i in range(0, len(data), 16):
            print("  %04x: %s" % (i, data[i:i + 16].hex(" ")))
    p = os.path.join(d, "load.cmm")
    if os.path.exists(p):
        print("load.cmm:")
        print(open(p, "rb").read().decode("ascii", "replace"))
    return 0


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 2
    if a[0] == "--resetinfo":
        return resetinfo(a[1])
    if a[0] == "--fb":
        return fb(a[1], int(a[2], 0))
    marker = b"Linux version 7.1"
    if "--marker" in a:
        k = a.index("--marker")
        marker = a[k + 1].encode()
        del a[k:k + 2]
    return scan(a, marker)


if __name__ == "__main__":
    sys.exit(main())
