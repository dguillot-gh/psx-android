# FF7 (Shinra Archaeology Cut): what we know before the first build

Prepared 2026-10-05 from the user's discs (3 x .cue/.bin) with `psx-android-tools\tools\new-recomp.ps1`.

## The reference recomp
`..\..\reference\Final-Fantasy-VII\` is a clone of https://github.com/TechnicallyComputers/Final-Fantasy-VII
(commit 2fcd344, psxrecomp fd019bbc): FF7 USA retail (SCUS-94163/94164/94165) statically recompiled on the SAME
psxrecomp framework, with desktop releases. Read-only reference; nothing is copied blindly.

- Their `game.toml`: same header values as ours (load 0x80010000, entry 0x800110C0, text 0x60800). Taken over:
  `[controller] lock_mode = true, allow_hybrid = false`, `[runtime] overlay_cache = true`.
- Their seeds (623) are identical to ours: the same JAL scan of the same code layout.
- `symbols.toml` / `symbols_overlays.toml`: ~1,100 function names imported (addresses only) from
  Xeeynamo/ff7-decomp's address tables (no licence: source never used). Gated on the RETAIL boot EXE SHA-1
  a95e8b16b97071203b953bb81a33980509262f30.

## Our disc differs from retail
Boot EXE `disc\SCUS_941.63` SHA-1 b17a7714ede541edaa574e5acfa8976ee715d661 (Shinra Archaeology Cut v1.0.5 patched
it), but the layout is identical (entry, text size, all 623 call targets). So the reference names and overlay map
very probably line up; treat them as unverified for this disc until checked.

## FF7 overlay map (for the FF7 pre-compile extractor; from symbols_overlays.toml)
Most FF7 code is streamed modules, several sharing one load address:
- 0x800A0000: battle, brom, dschange, ending, field, world
- 0x801D0000: the menus
- 0x801B0000: batini, barrier, lv5deth
## FF7 pre-compile extractor: `tools\overlay_extract.py` (written 2026-10-05)
psx-android-tools\tools\speed.ps1 runs it automatically (any game with tools\overlay_extract.py gets this).
On disc: `.X`/`FIELD.BIN`/`WORLD.BIN` = u32 unpacked size + u32 + gzip stream (the EXE's Unzip, 0x80017108);
`DSCHANGE.X`, `ENDING.X`, `MENU/*.MNU`, `MAGIC/*.BIN` are raw. Each module is checked at its base: calls into
itself must land on function starts (prologue, or right after a `jr ra` + delay slot: FF7 has many leaf
functions). Results on these discs: FIELD.BIN 1385/1386, BATTLE.X 1501/1505, WORLD.BIN 1148/1177, every menu,
BATINI/BATRES/BROM/ENDING 100%, DSCHANGE (no internal calls) accepted as named + starts with a prologue,
~100 MAGIC spell modules >= 92.5% at 0x801B0000. Default output (core): 23 unique modules, 1.9 MB of code,
3273 function starts. `--with-magic` adds every spell (~15 MB code: hours of compile, GBs): off by default;
spells actually cast arrive via play captures. PATYMENU.MNU is too small to verify (play captures cover it).
The runtime only runs a pre-compiled piece whose bytes match RAM, so a wrong module cannot run wrong code.

## Brought along
- `memcard-import\Final Fantasy VII (USA)_1.mcd`: the user's DuckStation card (128 KB); go.ps1 imports it into a
  fresh app install, never over an existing card.
- `launcher_assets\img\boxart.png`: retail FF7 cover (libretro-thumbnails), used for the app icon.
