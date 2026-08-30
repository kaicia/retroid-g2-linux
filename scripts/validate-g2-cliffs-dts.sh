#!/usr/bin/env bash
#
# validate-g2-cliffs-dts.sh
#
# Non-destructive validation for the G2 Cliffs SD-only DTS target.
#
# This script only reads the repository DTS sources and produces a temporary
# DTB under a scratch directory. It never writes to any block device, never
# touches internal Android/UFS/ABL/vbmeta/dtbo storage, and performs no
# flashing or formatting operation of any kind.
#
# Usage:
#   scripts/validate-g2-cliffs-dts.sh [DTS_FILE]
#
# Defaults to dts/g2/g2-cliffs-sd.dts.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS="${1:-$ROOT/dts/g2/g2-cliffs-sd.dts}"
OUTDIR="${TMPDIR:-/tmp}/g2-cliffs-dts-validate"
PP_DTS="$OUTDIR/g2-cliffs-sd.pp.dts"
DTB="$OUTDIR/g2-cliffs-sd.dtb"
ROUNDTRIP_DTS="$OUTDIR/g2-cliffs-sd.verify.dts"

mkdir -p "$OUTDIR"

echo "== G2 Cliffs SD-only DTS validation (non-destructive) =="
echo "DTS source : $DTS"
echo "Output dir : $OUTDIR"
echo

if [ ! -r "$DTS" ]; then
    echo "ERROR: DTS file not readable: $DTS"
    exit 2
fi

if ! command -v cpp >/dev/null 2>&1; then
    echo "ERROR: 'cpp' (C preprocessor) not found. Install gcc/cpp or device-tree-compiler toolchain."
    exit 2
fi

if ! command -v dtc >/dev/null 2>&1; then
    echo "ERROR: 'dtc' (device-tree-compiler) not found."
    exit 2
fi

echo "[1/3] Preprocess with cpp"
if ! cpp -x assembler-with-cpp -P -nostdinc -undef -o "$PP_DTS" "$DTS"; then
    echo "FAIL: cpp preprocessing failed."
    exit 1
fi
echo "      Preprocessed: $PP_DTS ($(wc -l < "$PP_DTS") lines)"
echo

echo "[2/3] Compile with dtc"
DTB_BASENAME="$(basename "$DTB")"
if ! dtc -I dts -O dtb -o "$DTB" "$PP_DTS" 2> "$OUTDIR/dtc.log"; then
    echo "FAIL: dtc compile failed. Log:"
    cat "$OUTDIR/dtc.log"
    exit 1
fi
echo "      Compiled: $DTB ($(stat -c%s "$DTB") bytes)"
echo

echo "[3/3] Round-trip DTB -> DTS"
if ! dtc -I dtb -O dts -o "$ROUNDTRIP_DTS" "$DTB" 2> "$OUTDIR/roundtrip.log"; then
    echo "FAIL: DTB round-trip failed."
    exit 1
fi
echo "      Round-trip: $ROUNDTRIP_DTS"
echo

echo "== dtc warnings (informational) =="
grep -iE 'warning|error' "$OUTDIR/dtc.log" || echo "(none)"
echo

echo "== Result =="
echo "PASS: G2 Cliffs SD-only DTS compiled to DTB and round-tripped."
echo "DTB : $DTB"
echo "This is a compile verification only. Compiling does NOT make the G2"
echo "bootable and does NOT modify any device storage."
