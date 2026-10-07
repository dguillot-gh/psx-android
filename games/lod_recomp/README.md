# Legend of Dragoon, The for Android (psxrecomp)

Private. This repository holds only what makes **Legend of Dragoon, The** run as a native Android app: its
configuration, code entry points (seeds), helper tools and play captures. **It contains no game
code or data.** You build the app on your own PC from **your own disc**; nothing from the disc is
ever uploaded.

Part of [psx-android](https://github.com/dguillot-gh/psx-android), which has the build scripts and
the full how-to. Engine: [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android)
(mstan/psxrecomp + our Android layer; PolyForm Noncommercial: personal, non-commercial use only).

## Status
NOT WORKING YET: same data-as-code problem as GT2. 4 discs. Set aside.

## The disc you need
- Serial **SCUS-94491**, 4 disc(s), as `.cue` + `.bin` (a raw rip of your own copy).
- Tested with: `Legend of Dragoon, The (USA, Canada) (Disc 1).cue`, `Legend of Dragoon, The (USA, Canada) (Disc 2).cue`, `Legend of Dragoon, The (USA, Canada) (Disc 3).cue`, `Legend of Dragoon, The (USA, Canada) (Disc 4).cue` (your file names may differ, that's fine).
- Known-good dump, Track 1 MD5: `acf7717e2192c78d8c5859cfacfc384d`. Other dumps of the same serial usually work too.

## Build it and put it on your phone
Follow **Get a game on your phone** in the psx-android README once (PC setup), then:

```powershell
pwsh -File go.ps1 -Game lod_recomp -Disc "D:\my discs\<disc 1>.cue","D:\my discs\<disc 2>.cue","D:\my discs\<disc 3>.cue","D:\my discs\<disc 4>.cue" -Speed
```

List every disc's `.cue` in order, separated by commas. The app (com.psxrecomp.lod) is installed on the phone
over USB, and the disc is copied to the phone's `Download\lod_recomp` folder. On the phone: open the app,
**Select game file**, side menu > your phone > Download > lod_recomp, pick the `.cue` files (all of them), then **Play**.

## What's here
| File | What |
|---|---|
| `game.toml` | the game's configuration (boot program, memory layout, controller, video) |
| `seeds/` | code entry points the recompiler starts from |
| `play_captures.json` | addresses of code the game loaded while being played; makes the speed pre-compile cover it |
| `tools/`, `aot_exclude.txt` | game-specific helpers / pieces kept off the pre-compile (when present) |
