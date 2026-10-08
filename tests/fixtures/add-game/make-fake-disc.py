#!/usr/bin/env python3
"""Make the FAKE two-disc PS1 game used by tests/add-game-dryrun.ps1 (no real game data).

Each disc is a tiny MODE2/2352 image (21 sectors, ~49 KB): an ISO 9660 volume with SYSTEM.CNF and a
small PS-X EXE that has a few JAL instructions, which is all probe_disc.py reads. Writes
nas/fakegame_recomp/Fake Game (USA) (Disc N).cue/.bin next to this script. Run again to remake them.
"""
import struct
from pathlib import Path

SEC = 2352
SYNC = bytes([0x00] + [0xFF] * 10 + [0x00])
EXE_NAME = "SLUS_999.99"


def both16(v):  # ISO 9660 "both-endian" 16-bit
    return struct.pack("<H", v) + struct.pack(">H", v)


def both32(v):
    return struct.pack("<I", v) + struct.pack(">I", v)


def dir_record(name: bytes, extent: int, size: int, is_dir: bool) -> bytes:
    rec = bytearray(33 + len(name) + (1 - len(name) % 2))  # padded to an even length
    rec[0] = len(rec)
    rec[2:10] = both32(extent)
    rec[10:18] = both32(size)
    rec[25] = 2 if is_dir else 0
    rec[28:32] = both16(1)
    rec[32] = len(name)
    rec[33:33 + len(name)] = name
    return bytes(rec)


def raw_sector(lba: int, data: bytes) -> bytes:
    data = data.ljust(2048, b"\0")
    m, rest = divmod(lba + 150, 75 * 60)
    s, f = divmod(rest, 75)
    bcd = lambda x: (x // 10) << 4 | (x % 10)
    header = bytes([bcd(m), bcd(s), bcd(f), 2])
    subheader = bytes([0, 0, 8, 0] * 2)
    return SYNC + header + subheader + data + bytes(SEC - 24 - 2048)  # EDC/ECC left zero


def make_disc(disc_no: int) -> bytes:
    cnf = f"BOOT = cdrom:\\{EXE_NAME};1\r\nTCB = 4\r\nEVENT = 10\r\nSTACK = 801FFFF0\r\n".encode()
    # PS-X EXE: 2 KB header + 2 KB text at 0x80010000: a few JALs to fake functions, then jr ra.
    text = bytearray()
    for target in (0x80010100, 0x80010200, 0x80010300):
        text += struct.pack("<I", (3 << 26) | ((target >> 2) & 0x03FFFFFF)) + bytes(4)
    text += struct.pack("<I", 0x03E00008) + bytes(4)
    text = bytes(text).ljust(2048, b"\0")
    hdr = bytearray(2048)
    hdr[0:8] = b"PS-X EXE"
    struct.pack_into("<IIII", hdr, 0x10, 0x80010000, 0, 0x80010000, len(text))
    struct.pack_into("<II", hdr, 0x30, 0x801FFFF0, 0)
    hdr[0x4C:0x4C + 32] = b"Sony Computer Entertainment Inc."  # (the BIOS checks only the magic)
    exe = bytes(hdr) + text

    root_lba, cnf_lba, exe_lba = 18, 19, 20
    root = (dir_record(b"\0", root_lba, 2048, True) + dir_record(b"\1", root_lba, 2048, True) +
            dir_record(b"SYSTEM.CNF;1", cnf_lba, len(cnf), False) +
            dir_record(EXE_NAME.encode() + b";1", exe_lba, len(exe), False))
    pvd = bytearray(2048)
    pvd[0] = 1
    pvd[1:6] = b"CD001"
    pvd[6] = 1
    pvd[40:72] = f"FAKEGAME_DISC{disc_no}".ljust(32).encode()
    pvd[80:88] = both32(exe_lba + 2)
    pvd[120:124] = both16(1)
    pvd[124:128] = both16(1)
    pvd[128:132] = both16(2048)
    pvd[156:156 + 34] = dir_record(b"\0", root_lba, 2048, True)
    term = bytearray(2048)
    term[0] = 255
    term[1:6] = b"CD001"
    term[6] = 1

    sectors = [b""] * 16 + [bytes(pvd), bytes(term), root, cnf, exe[:2048], exe[2048:]]
    return b"".join(raw_sector(i, d) for i, d in enumerate(sectors))


out = Path(__file__).resolve().parent / "nas" / "fakegame_recomp"
out.mkdir(parents=True, exist_ok=True)
for n in (1, 2):
    stem = f"Fake Game (USA) (Disc {n})"
    (out / f"{stem}.bin").write_bytes(make_disc(n))
    (out / f"{stem}.cue").write_text(f'FILE "{stem}.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n',
                                     newline="\r\n")
print(f"wrote {out}")
