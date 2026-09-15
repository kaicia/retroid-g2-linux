#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""
Pack a `fastboot boot` image for the Retroid Pocket G2.

Why this exists rather than AOSP's mkbootimg: we need boot image header
version 2 specifically, and we need to choose load addresses from the
device's own usable-DRAM map rather than from Android's defaults. Both are
short and better stated explicitly than configured through someone else's
tool.

Header version 2 is the choice because it is the last version that carries
the device tree *inside the boot image*. From v3 on the DTB lives in
vendor_boot, which means `fastboot boot` of a v3/v4 image would run our
kernel against the stock Qualcomm device tree - the opposite of the
experiment. v2 hands ABL our kernel and our DTB in one file.

Nothing here writes to the device. `fastboot boot` loads into RAM and jumps;
no partition is touched.

Layout (every section padded up to page_size):

    page 0        header
    page 1..      kernel
                  ramdisk
                  second stage   (absent)
                  recovery dtbo  (absent)
                  dtb
"""

import argparse
import gzip
import hashlib
import io
import struct
import sys

BOOT_MAGIC = b"ANDROID!"
HEADER_SIZE_V2 = 1660
PAGE_SIZE = 4096

# Load addresses.
#
# The device's usable-DRAM list (dumps/g2/, /memory in the device's own tree)
# has one large clean block below 4 GiB:
#
#     0xa7000000 .. 0xd8000000      784 MiB
#
# Everything the boot header can address is a 32-bit field, so the 5 GiB
# block at 0x8c0000000 is unreachable here, and the 474 MiB block at
# 0xe1d40000 contains the continuous-splash framebuffer we are trying to
# print into. That leaves this one.
#
# Android's own convention is base+0x8000 for the kernel; kept, because ABL
# is the thing reading these and it is used to seeing that shape. Note that
# the arm64 kernel is CONFIG_RELOCATABLE and will move itself to a 2 MiB
# boundary regardless, and that many Qualcomm ABLs override these fields
# with their own values outright. They are a best effort, not a contract.
BASE = 0xA7000000
KERNEL_ADDR = BASE + 0x00008000
RAMDISK_ADDR = BASE + 0x01000000
SECOND_ADDR = BASE + 0x00F00000
TAGS_ADDR = BASE + 0x00000100
DTB_ADDR = BASE + 0x02000000


def pad(data: bytes, page_size: int) -> bytes:
    """Pad up to a whole number of pages."""
    if len(data) % page_size == 0:
        return data
    return data + b"\x00" * (page_size - len(data) % page_size)


def empty_initramfs() -> bytes:
    """A valid, empty gzipped cpio newc archive.

    An image with ramdisk_size == 0 is legal, but some bootloaders treat it
    as a malformed image rather than as "no ramdisk". This is 100-odd bytes
    and removes the question.

    The kernel unpacks it, finds no /init, and panics with "No working init
    found" - which at Tier 0 is a success, not a failure: it means the
    kernel reached the end of its own startup.
    """
    # newc: magic(6) ino mode uid gid nlink mtime filesize devmajor devminor
    #       rdevmajor rdevminor namesize check   -> 13 eight-digit fields
    name = b"TRAILER!!!\x00"
    fields = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, len(name), 0]
    rec = b"070701" + b"".join(b"%08X" % f for f in fields) + name
    rec = rec + b"\x00" * (-len(rec) % 4)
    buf = io.BytesIO()
    # mtime=0 so the image is byte-reproducible.
    with gzip.GzipFile(fileobj=buf, mode="wb", mtime=0) as gz:
        gz.write(rec)
    return buf.getvalue()


def build(kernel: bytes, ramdisk: bytes, dtb: bytes, cmdline: str,
          page_size: int = PAGE_SIZE) -> bytes:
    cmdline_b = cmdline.encode()
    if len(cmdline_b) > 512 + 1024:
        raise SystemExit("cmdline too long: %d bytes (max 1536)" % len(cmdline_b))
    main_cmdline = cmdline_b[:512]
    extra_cmdline = cmdline_b[512:]

    # The id[] field is a SHA-1 over each section and its length. Nothing in
    # the boot path verifies it for `fastboot boot` on an unlocked device,
    # but it is part of a well-formed image and costs one pass.
    sha = hashlib.sha1()
    for section in (kernel, ramdisk, b""):          # kernel, ramdisk, second
        sha.update(section)
        sha.update(struct.pack("<I", len(section)))
    for section in (b"", dtb):                      # recovery_dtbo, dtb
        sha.update(struct.pack("<I", len(section)))
        sha.update(section)
    img_id = sha.digest().ljust(32, b"\x00")[:32]

    hdr = bytearray()
    hdr += BOOT_MAGIC
    hdr += struct.pack("<I", len(kernel))
    hdr += struct.pack("<I", KERNEL_ADDR)
    hdr += struct.pack("<I", len(ramdisk))
    hdr += struct.pack("<I", RAMDISK_ADDR)
    hdr += struct.pack("<I", 0)                     # second_size
    hdr += struct.pack("<I", SECOND_ADDR)
    hdr += struct.pack("<I", TAGS_ADDR)
    hdr += struct.pack("<I", page_size)
    hdr += struct.pack("<I", 2)                     # header_version
    hdr += struct.pack("<I", 0)                     # os_version
    hdr += b"\x00" * 16                             # name
    hdr += main_cmdline.ljust(512, b"\x00")
    hdr += img_id
    hdr += extra_cmdline.ljust(1024, b"\x00")
    hdr += struct.pack("<I", 0)                     # recovery_dtbo_size
    hdr += struct.pack("<Q", 0)                     # recovery_dtbo_offset
    hdr += struct.pack("<I", HEADER_SIZE_V2)
    hdr += struct.pack("<I", len(dtb))
    hdr += struct.pack("<Q", DTB_ADDR)
    assert len(hdr) == HEADER_SIZE_V2, len(hdr)

    return (pad(bytes(hdr), page_size) + pad(kernel, page_size)
            + pad(ramdisk, page_size) + pad(dtb, page_size))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--dtb", required=True)
    ap.add_argument("--ramdisk", help="default: a generated empty initramfs")
    ap.add_argument("--cmdline", required=True)
    ap.add_argument("--page-size", type=int, default=PAGE_SIZE)
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    kernel = open(args.kernel, "rb").read()
    if kernel[56:60] != b"ARM\x64":
        raise SystemExit("%s is not an arm64 Image (no ARM\\x64 at 0x38)" % args.kernel)
    dtb = open(args.dtb, "rb").read()
    if dtb[:4] != b"\xd0\x0d\xfe\xed":
        raise SystemExit("%s is not a device tree blob" % args.dtb)
    ramdisk = open(args.ramdisk, "rb").read() if args.ramdisk else empty_initramfs()

    img = build(kernel, ramdisk, dtb, args.cmdline, args.page_size)
    open(args.output, "wb").write(img)

    print("%s  %d bytes" % (args.output, len(img)))
    print("  kernel   %8d -> 0x%08x" % (len(kernel), KERNEL_ADDR))
    print("  ramdisk  %8d -> 0x%08x" % (len(ramdisk), RAMDISK_ADDR))
    print("  dtb      %8d -> 0x%08x" % (len(dtb), DTB_ADDR))
    print("  cmdline  %s" % args.cmdline)
    print("  sha256   %s" % hashlib.sha256(img).hexdigest())
    return 0


if __name__ == "__main__":
    sys.exit(main())
