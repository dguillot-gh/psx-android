#!/usr/bin/env python3
"""Play-free overlay producer for Policenauts' /NAUTS/BIN.DPK.

All of the game's runtime-loaded code lives in this one archive ("FRID" magic,
14 named members: BLOOD.BIN, DISPLAY.BIN, ITP.BIN, ...). The members are raw,
position-fixed MIPS images (disc bytes == RAM bytes, verified against live
overlay captures), so each one goes through the framework's own raw-code
producer path from tools/aot_overlay_spike/extract_generic.py: jal-fit base
recovery, prologue/leaf/pointer-table seeds, page-aligned region, rec().
The generic extractor finds nothing here only because it treats BIN.DPK as a
single file; this script just splits the container first.

Output is a synthetic overlay_captures.json for tools/compile_overlays.py.
Members whose base cannot be proven are skipped (they stay interpreted, which
is safe: every shard is code-CRC guarded at dispatch).

Usage:
  extract_bin_dpk.py --disc <disc1.cue> --out aot_dpk_captures.json
"""
import argparse
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPIKE = os.path.join(HERE, "..", "psxrecomp", "tools", "aot_overlay_spike")
sys.path.insert(0, SPIKE)
sys.path.insert(0, os.path.join(HERE, "..", "psxrecomp", "tools"))

import extract_generic as eg  # noqa: E402

ARCHIVE = "BIN.DPK"


def dpk_members(data):
    """Yield (name, offset, size) for each member of a FRID archive."""
    magic, _flags, _sector, count, _unk, recsz = struct.unpack_from("<4sIIIII", data, 0)
    if magic != b"FRID" or recsz < 24:
        raise ValueError("not a FRID DPK archive")
    for i in range(count):
        o = 0x20 + i * recsz
        name = data[o:o + 12].split(b"\0")[0].decode("ascii", "replace")
        off, size = struct.unpack_from("<II", data, o + 12)
        if off + size > len(data):
            raise ValueError(f"member {name} runs past the archive")
        yield name, off, size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--disc", required=True, help="Disc 1 .cue")
    ap.add_argument("--out", required=True)
    ap.add_argument("--base-lo", default="0x80010000",
                    help="lowest admissible load base (default: main EXE load address)")
    a = ap.parse_args()

    bp, raw = eg.parse_cue_datatrack(a.disc)
    dr = eg.eo.DiscReader(bp, raw=raw)
    hit = [(p, l, s) for p, l, s in eg.eo.enumerate_files(dr)
           if os.path.basename(p).upper() == ARCHIVE]
    if not hit:
        sys.exit(f"{ARCHIVE} not found on {a.disc}")
    path, lba, size = hit[0]
    archive = dr.read_file_bytes(lba, size)
    base_lo = int(a.base_lo, 16)

    records, skipped = [], []
    for name, off, size in dpk_members(archive):
        data = archive[off:off + size]
        rb = eg.recover_raw_base(data, base_lo)
        if rb is None:
            skipped.append(name)
            print(f"  [skip] {name}: {size}B, load base not provable")
            continue
        base, score, second = rb
        prologue_seeds = eg.prologues(data, base)
        frameless = eg.frameless_leaf_entries(data, base)
        supplemental = eg.supplemental_callable_seeds(data, base)
        seeds = sorted(set(prologue_seeds) | frameless | supplemental)
        page_base, region = eg.page_aligned_region(base, data)
        direct = eg.direct_jal_roots(data, base)
        record = eg.rec(page_base, region, seeds, static_discovery=direct)
        if direct and set(seeds) != set(direct):
            record["optional_enrichment_fallback_entry_pcs"] = [
                f"0x{addr:08X}" for addr in direct]
        record["producer"] = "policenauts_bin_dpk"
        record["producer_name"] = f"{path}:{name}@{off:08X}"
        records.append(record)
        print(f"  [raw-code] {name}: {size}B base 0x{base:08X} region 0x{page_base:08X} "
              f"(jal-fit score={score}, runner-up={second}), seeds={len(seeds)}")

    with open(a.out, "w") as f:
        json.dump(records, f)
    print(f"{len(records)} members -> {a.out}; skipped: {', '.join(skipped) or 'none'}")


if __name__ == "__main__":
    main()
