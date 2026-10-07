# Tomba! 2 - The Evil Swine Return for Android (psxrecomp)

Private. This repository holds only what makes **Tomba! 2 - The Evil Swine Return** run as a native Android app: its
configuration, code entry points (seeds), helper tools and play captures. **It contains no game
code or data.** You build the app on your own PC from **your own disc**; nothing from the disc is
ever uploaded.

Part of [psx-android](https://github.com/dguillot-gh/psx-android), which has the build scripts and
the full how-to. Engine: [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android)
(mstan/psxrecomp + our Android layer; PolyForm Noncommercial: personal, non-commercial use only).

## Status
Plays (2026-10-07) on a Pixel 8; GPU renderer recommended (menu > Display).

## The disc you need
- Serial **SCUS-94454**, 1 disc(s), as `.cue` + `.bin` (a raw rip of your own copy).
- Tested with: `Tomba! 2 - The Evil Swine Return (USA).cue` (your file names may differ, that's fine).
- Known-good dump, Track 1 MD5: `63e774ac891ca718e19a88b42c72de06`. Other dumps of the same serial usually work too.

## Build it and put it on your phone
Follow **Get a game on your phone** in the psx-android README once (PC setup), then:

```powershell
pwsh -File go.ps1 -Game tomba2_recomp -Disc "D:\my discs\<disc 1>.cue" -Speed
```

List every disc's `.cue` in order, separated by commas. The app (com.psxrecomp.tomba2) is installed on the phone
over USB, and the disc is copied to the phone's `Download\tomba2_recomp` folder. On the phone: open the app,
**Select game file**, side menu > your phone > Download > tomba2_recomp, pick the `.cue`, then **Play**.

## What's here
| File | What |
|---|---|
| `game.toml` | the game's configuration (boot program, memory layout, controller, video) |
| `seeds/` | code entry points the recompiler starts from |
| `play_captures.json` | addresses of code the game loaded while being played; makes the speed pre-compile cover it |
| `tools/`, `aot_exclude.txt` | game-specific helpers / pieces kept off the pre-compile (when present) |
