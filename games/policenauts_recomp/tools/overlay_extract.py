#!/usr/bin/env python3
"""Policenauts' overlay extractor for speed.ps1 (same interface as FF7's):
    overlay_extract.py --game-toml game.toml --out <captures.json> --framework psxrecomp
All of the game's runtime-loaded code is in /NAUTS/BIN.DPK (Disc 2's copy is identical), so
this only finds Disc 1 in game.toml and runs extract_bin_dpk.py (2026-10-02) on it.
Run from the game folder (speed.ps1 does)."""
import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game-toml", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--framework", default="psxrecomp")  # extract_bin_dpk finds ../psxrecomp itself
    a = ap.parse_args()
    text = open(a.game_toml, encoding="utf-8").read()
    m = re.search(r'(?ms)^discs\s*=\s*\[\s*"([^"]+)"', text) or re.search(r'(?m)^disc\s*=\s*"([^"]+)"', text)
    if not m:
        print("overlay_extract: no disc in game.toml")
        return 1
    disc = os.path.join(os.path.dirname(os.path.abspath(a.game_toml)), m.group(1))
    return subprocess.call([sys.executable, os.path.join(HERE, "extract_bin_dpk.py"), "--disc", disc, "--out", a.out])


if __name__ == "__main__":
    sys.exit(main())
