# Policenauts for Android (psxrecomp)

Private. This repository holds only what makes **Policenauts** run as a native Android app: its
configuration, code entry points (seeds), helper tools and play captures. **It contains no game
code or data.** You build the app on your own PC from **your own disc**; nothing from the disc is
ever uploaded.

Part of [psx-android](https://github.com/dguillot-gh/psx-android), which has the build scripts and
the full how-to. Engine: [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android)
(mstan/psxrecomp + our Android layer; PolyForm Noncommercial: personal, non-commercial use only).

## Status
Plays (2026-10-07) with the touch trackpad (Sony Mouse). Known issue: slow opening (about 30 fps). Japanese release, 2 discs.

## The disc you need
- Serial **SLPS-00215**, 2 disc(s), as `.cue` + `.bin` (a raw rip of your own copy).
- Tested with: `Policenauts (Japan) (Disc 1) [En by Slowbeef v1.0].cue`, `Policenauts (Japan) (Disc 2) [En by Slowbeef v1.0].cue` (your file names may differ, that's fine).
- Known-good dump, Track 1 MD5: `65977ae8b63042475730e6efb6a5a8a6`. Other dumps of the same serial usually work too.

## Build it and put it on your phone
Follow **Get a game on your phone** in the psx-android README once (PC setup), then:

```powershell
pwsh -File go.ps1 -Game policenauts_recomp -Disc "D:\my discs\<disc 1>.cue","D:\my discs\<disc 2>.cue" -Speed
```

List every disc's `.cue` in order, separated by commas. The app (com.psxrecomp.policenauts) is installed on the phone
over USB, and the disc is copied to the phone's `Download\policenauts_recomp` folder. On the phone: open the app,
**Select game file**, side menu > your phone > Download > policenauts_recomp, pick the `.cue` files (all of them), then **Play**.

## What's here
| File | What |
|---|---|
| `game.toml` | the game's configuration (boot program, memory layout, controller, video) |
| `seeds/` | code entry points the recompiler starts from |
| `play_captures.json` | addresses of code the game loaded while being played; makes the speed pre-compile cover it |
| `tools/`, `aot_exclude.txt` | game-specific helpers / pieces kept off the pre-compile (when present) |
