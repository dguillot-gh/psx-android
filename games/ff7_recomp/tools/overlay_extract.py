#!/usr/bin/env python3
"""FF7 static overlay extractor (play-free pre-compile). Hand-written 2026-10-05; stdlib only.

  python tools/overlay_extract.py --game-toml game.toml --out <captures.json> [--framework psxrecomp]

FF7 streams most of its code as modules loaded at fixed addresses (map from the reference recomp,
reference/Final-Fantasy-VII/symbols_overlays.toml; see REFERENCE.md):
  0x800A0000  battle (BATTLE/BATTLE.X), brom (BATTLE/BROM.X), field (FIELD/FIELD.BIN),
              world (WORLD/WORLD.BIN), dschange (FIELD/DSCHANGE.X), ending (FIELD/ENDING.X)
  0x801B0000  batini (BATTLE/BATINI.X), barrier/lv5deth (MAGIC/*.BIN, the battle-effect modules)
  0x801D0000  menus (MENU/*.MNU)
On the disc a module is either raw, or an 8-byte header + a gzip stream (the EXE's Unzip routine).

Every module is CHECKED at its base before it is used: the calls (jal) a module makes into its own
address range must land on function prologues (addiu sp,sp,-N). A wrong base or a non-code file fails
that test and is skipped; the runtime only ever runs a pre-compiled piece whose bytes match RAM, so a
skipped module just stays interpreted. Output: psxrecomp overlay capture v2 records (all discs, de-duplicated
later by captures.py merge).
"""
import argparse, base64, os, struct, sys, tomllib, zlib

MODULES = [  # (disc path prefix or exact path, base, how)
    ("BATTLE/BATTLE.X", 0x800A0000, "gz8"),
    ("BATTLE/BROM.X",   0x800A0000, "gz8"),
    ("FIELD/FIELD.BIN", 0x800A0000, "gz8"),
    ("WORLD/WORLD.BIN", 0x800A0000, "gz8"),
    ("FIELD/DSCHANGE.X", 0x800A0000, "raw"),
    ("FIELD/ENDING.X",  0x800A0000, "raw"),
    ("BATTLE/BATINI.X", 0x801B0000, "gz8"),
    ("BATTLE/BATRES.X", 0x801B0000, "gz8"),
    ("MAGIC/",          0x801B0000, "raw"),   # battle-effect (spell) modules: only with --with-magic
    ("MENU/",           0x801D0000, "raw"),   # every menu module; each one is checked
]
# Checked 2026-10-05 on the Shinra Archaeology Cut discs: field 1385/1386 calls on function starts,
# battle 1501/1505, world 1148/1177, all menus/batini/batres/brom/ending 100%, ~100 MAGIC modules >= 92.5%.
# MAGIC is ~15 MB of code across ~100 spells: pre-compiling all of it takes hours and gigabytes, so by
# default spells come from play captures (the ones actually cast); --with-magic takes them all.
MIN_CALLS, MIN_RATIO = 4, 0.9


def words(data):
    return struct.unpack_from(f"<{len(data) // 4}I", data, 0)


def is_prologue(w):
    """addiu sp, sp, -N (a MIPS function's first instruction)."""
    return (w >> 16) == 0x27BD and (w & 0x8000) != 0


JR_RA = 0x03E00008


def is_function_start(ws, i):
    """A function starts with a prologue, or (leaf functions have no stack frame) right after the
    previous function's `jr ra` + delay slot, or at the very start of the module."""
    return i == 0 or is_prologue(ws[i]) or (i >= 2 and ws[i - 2] == JR_RA)


def check(data, base):
    """(calls into the module, how many land on a function start)."""
    ws = words(data)
    inside = hits = 0
    for w in ws:
        if (w >> 26) != 3:  # jal
            continue
        t = 0x80000000 | ((w & 0x03FFFFFF) << 2)
        off = t - base
        if 0 <= off < len(ws) * 4:
            inside += 1
            hits += 1 if is_function_start(ws, off // 4) else 0
    return inside, hits


def seeds(data, base):
    ws = words(data)
    s = {base + 4 * i for i, w in enumerate(ws) if is_prologue(w)}
    for w in ws:
        if (w >> 26) == 3:
            t = 0x80000000 | ((w & 0x03FFFFFF) << 2)
            if 0 <= t - base < len(ws) * 4:
                s.add(t)
    return sorted(s)


def unpack(raw, how):
    if how == "raw":
        return raw
    if raw[8:10] != b"\x1f\x8b":
        return None
    return zlib.decompress(raw[8:], 16 + zlib.MAX_WBITS)


def record(base, data):
    sd = [f"0x{a:08X}" for a in seeds(data, base)]
    return {"schema": "psxrecomp overlay capture v2", "load_addr": f"0x{base:08X}", "size": len(data),
            "bytes_b64": base64.b64encode(data).decode(), "executed_pcs": [],
            "dispatch_entry_pcs": sd, "function_entry_pcs": sd, "seeds": sd}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game-toml", default="game.toml")
    ap.add_argument("--out", required=True)
    ap.add_argument("--framework", default="psxrecomp")
    ap.add_argument("--with-magic", action="store_true", help="also every MAGIC/*.BIN spell module (large)")
    a = ap.parse_args()
    sys.path.insert(0, os.path.join(a.framework, "tools"))
    import extract_overlays as eo

    game = tomllib.load(open(a.game_toml, "rb"))["game"]
    root = os.path.dirname(os.path.abspath(a.game_toml))
    cues = game.get("discs") or [game.get("disc")]
    out, kept, skipped = [], 0, []
    for cue in cues:
        bp, rawmode = eo.parse_cue(os.path.join(root, cue))
        disc = eo.DiscReader(bp, raw=rawmode)
        for path, lba, size in sorted(eo.enumerate_files(disc)):
            up = path.upper()
            for key, base, how in MODULES:
                if not (up == key or (key.endswith("/") and up.startswith(key))):
                    continue
                if key == "MAGIC/" and not a.with_magic:
                    break
                data = unpack(disc.read_file_bytes(lba, size), how)
                if not data or len(data) < 64:
                    skipped.append(f"{path}: not a module"); break
                data = data[: len(data) & ~3]
                inside, hits = check(data, base)
                # A module named in the reference map that only calls the main program (no calls into
                # itself, e.g. DSCHANGE.X) passes when it starts with a function prologue.
                named_leaf = (not key.endswith("/")) and inside == 0 and is_prologue(words(data)[0])
                if not named_leaf and (inside < MIN_CALLS or hits < MIN_RATIO * inside):
                    skipped.append(f"{path} @0x{base:08X}: {hits}/{inside} calls on prologues"); break
                out.append(record(base, data)); kept += 1
                print(f"  ok  {os.path.basename(cue)[:40]:40} {path:22} @0x{base:08X} {len(data):>7} B  {hits}/{inside} calls ok")
                break
    with open(a.out, "w") as f:
        json_dump(out, f)
    print(f"FF7 extractor: {kept} module(s) kept, {len(skipped)} skipped (failed the check or not code)")
    for s in skipped[:40]:
        print("  skip", s)


def json_dump(obj, f):
    import json
    json.dump(obj, f)


if __name__ == "__main__":
    main()
