#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""
Compare Qualcomm ABL ELF images: the G2's own factory ABL backup against a
candidate replacement (e.g. ROCKNIX-ABL abl_signed-SM8650.elf).

Read-only. It opens files and prints; it never talks to a device.

What must match for XBL to load a replacement ABL at all:
  - ELF class/machine (Qualcomm ABL images are ELF32/ARM wrappers)
  - the LOAD segment's physical address (XBL places ABL there)
  - the MBN hash-segment header version (v6 = SM8250 era, v7 = SM8550 and later)
The candidate must also fit the abl partition (1 MiB on the G2).

Usage:
  python check-abl-compat.py <factory abl_b.bin> <candidate.elf> [more.elf ...]

The first file is the reference; every other file is checked against it.
A factory backup is the raw 1 MiB partition dump: ELF at offset 0, zero padded.
"""

import struct
import sys

ABL_PARTITION_SIZE = 0x100000  # getvar partition-size:abl_a on the G2
PT_LOAD = 1
PT_NULL = 0
MI_PBT_HASH_SEGMENT = 0x2  # Qualcomm segment type in p_flags bits 24..26


def parse(path):
    data = open(path, "rb").read()
    if data[:4] != b"\x7fELF":
        raise SystemExit("%s: not an ELF image" % path)
    cls = data[4]
    if cls == 1:
        (e_type, e_machine, _ver, e_entry, e_phoff, _shoff, _flags, _ehsize,
         e_phentsize, e_phnum) = struct.unpack("<HHIIIIIHHH", data[16:46])
        phfmt, phsize = "<8I", 32
    elif cls == 2:
        (e_type, e_machine, _ver, e_entry, e_phoff, _shoff, _flags, _ehsize,
         e_phentsize, e_phnum) = struct.unpack("<HHIQQQIHHH", data[16:58])
        phfmt, phsize = "<IIQQQQQQ", 56
    else:
        raise SystemExit("%s: unknown ELF class %d" % (path, cls))

    loads, hashseg = [], None
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        f = struct.unpack(phfmt, data[off:off + phsize])
        if cls == 1:
            p_type, p_offset, _vaddr, p_paddr, p_filesz, p_memsz, p_flags, _ = f
        else:
            p_type, p_flags, p_offset, _vaddr, p_paddr, p_filesz, p_memsz, _ = f
        if p_type == PT_LOAD:
            loads.append((p_paddr, p_memsz))
        elif p_type == PT_NULL and (p_flags >> 24) & 0x7 == MI_PBT_HASH_SEGMENT:
            hashseg = p_offset

    mbn_version = None
    if hashseg is not None:
        mbn_version = struct.unpack("<I", data[hashseg + 4:hashseg + 8])[0]

    # Real image end = furthest byte any segment reaches (a partition dump is padded).
    end = 0
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        f = struct.unpack(phfmt, data[off:off + phsize])
        p_offset, p_filesz = (f[1], f[4]) if cls == 1 else (f[2], f[5])
        end = max(end, p_offset + p_filesz)

    return {
        "class": "ELF32" if cls == 1 else "ELF64",
        "machine": e_machine,
        "entry": e_entry,
        "loads": loads,
        "mbn": mbn_version,
        "size": end,
    }


def show(path, info):
    print(path)
    print("  %s machine=%d entry=0x%08x  MBN hash header v%s  image %d bytes"
          % (info["class"], info["machine"], info["entry"], info["mbn"], info["size"]))
    for paddr, memsz in info["loads"]:
        print("  LOAD 0x%08x .. 0x%08x (%d KiB)" % (paddr, paddr + memsz, memsz // 1024))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    ref_path = sys.argv[1]
    ref = parse(ref_path)
    show(ref_path, ref)
    ok_all = True
    for path in sys.argv[2:]:
        info = parse(path)
        print()
        show(path, info)
        checks = [
            ("ELF class", info["class"] == ref["class"]),
            ("machine", info["machine"] == ref["machine"]),
            ("entry point", info["entry"] == ref["entry"]),
            ("LOAD address", [l[0] for l in info["loads"]] == [l[0] for l in ref["loads"]]),
            ("MBN hash header version", info["mbn"] == ref["mbn"]),
            ("fits abl partition (1 MiB)", info["size"] <= ABL_PARTITION_SIZE),
        ]
        for name, ok in checks:
            print("  [%s] %s" % ("OK " if ok else "BAD", name))
            ok_all &= ok
    print()
    print("RESULT: %s" % ("all checks match the factory ABL" if ok_all
                          else "MISMATCH - do not flash; report the output"))
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
