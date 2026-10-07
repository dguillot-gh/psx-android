# Parasite Eve II for Android (psxrecomp)

Private. This repository holds only what makes **Parasite Eve II** run as a native Android app: its
configuration, code entry points (seeds), helper tools and play captures. **It contains no game
code or data.** You build the app on your own PC from **your own disc**; nothing from the disc is
ever uploaded.

Part of [psx-android](https://github.com/dguillot-gh/psx-android), which has the build scripts and
the full how-to. Engine: [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android)
(mstan/psxrecomp + our Android layer; PolyForm Noncommercial: personal, non-commercial use only).

## Status
Plays (2026-10-07) on a Pixel 8. Known issue: no sound. Disc 1 only tested.

## The disc you need
- Serial **SLUS-01042**, 2 disc(s), as `.cue` + `.bin` (a raw rip of your own copy).
- Tested with: `Parasite Eve II (USA, Canada) (Disc 1).cue`, `Parasite Eve II (USA, Canada) (Disc 2).cue` (your file names may differ, that's fine).
- Known-good dump, Track 1 MD5: `c2528bbcd164efad25c0aaccd8f6982b`. Other dumps of the same serial usually work too.

## Build it and put it on your phone
Follow **Get a game on your phone** in the psx-android README once (PC setup), then:

```powershell
pwsh -File go.ps1 -Game parasite_eve2_recomp -Disc "D:\my discs\<disc 1>.cue","D:\my discs\<disc 2>.cue" -Speed
```

List every disc's `.cue` in order, separated by commas. The app (com.psxrecomp.parasiteeve2) is installed on the phone
over USB, and the disc is copied to the phone's `Download\parasite_eve2_recomp` folder. On the phone: open the app,
**Select game file**, side menu > your phone > Download > parasite_eve2_recomp, pick the `.cue` files (all of them), then **Play**.

## What's here
| File | What |
|---|---|
| `game.toml` | the game's configuration (boot program, memory layout, controller, video) |
| `seeds/` | code entry points the recompiler starts from |
| `play_captures.json` | addresses of code the game loaded while being played; makes the speed pre-compile cover it |
| `tools/`, `aot_exclude.txt` | game-specific helpers / pieces kept off the pre-compile (when present) |
