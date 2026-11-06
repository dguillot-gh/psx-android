# psx-android

PlayStation 1 games as **native Android apps**, made with [psxrecomp](https://github.com/mstan/psxrecomp)
static recompilation: the game's own program is translated into C and compiled for the phone, not emulated.
Every app gets the same Android layer: touch pad (or a controller), a side menu with 12 save-state slots,
disc change, restart and display options, a movable FPS counter, software or GPU (OpenGL ES) rendering.

**Public repository. It contains no game code or data.** Each person builds the apps on their own PC from
**their own discs**. Never share the APKs you build: they contain the game's translated program.

| Repository | What |
|---|---|
| **psx-android** (this one) | build scripts and notes, and the list of games (see **Games** below) |
| [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android) | the engine, in `framework/`: mstan/psxrecomp + our Android work (branch `android`) |
| `dguillot-gh/<name>-android` | one standalone repository per game: clone it, add your discs, run its `scripts\RUN-ALL.ps1` (no play captures: they hold game code) |

---

## Get a game on your phone

### What you need
- A **Windows 10/11 PC** with about **15 GB free** and internet for the first setup.
- **Your own copy of the game**, ripped to `.cue` + `.bin` (each game's README says which version).
- An **Android phone** (64-bit, Android 5 or newer; tested on a Pixel 8) and a USB cable.
- **PowerShell 7**: in a normal PowerShell window run `winget install Microsoft.PowerShell`.
- **GitHub Desktop** (or git). The repositories are public: no account or access needed to clone them.

### 1. Get the repositories (once)
1. Make a folder with a short path, for example `C:\psx`.
2. In GitHub Desktop: **File > Clone repository > dguillot-gh/psx-android**, local path `C:\psx\psx-android`.
   GitHub Desktop also fetches the engine (a "submodule"). With plain git:
   `git clone --recursive https://github.com/dguillot-gh/psx-android.git`
   The games are not inside this repository. To build one game, the simplest way is its own repository
   (see **Games**); `go.ps1` below sets a game up on this PC from your disc with `tools\new-recomp.ps1`.

Everything the scripts download or build goes **next to** the repository (`C:\psx\tools-cache`,
`C:\psx\recomps`, `C:\psx\android-recomp`), never into Windows.

### 2. Get the phone ready (once)
1. **Settings > About phone**, tap **Build number** 7 times (this unlocks Developer options).
2. **Settings > System > Developer options**: turn on **USB debugging**.
3. Plug the phone in, unlock it, and tap **Allow** on the "USB debugging" prompt (tick "Always allow").

### 3. Build a game and install it
Open **PowerShell 7** (search the Start menu for "pwsh") in `C:\psx\psx-android` and run, with the path to
**your** disc:

```powershell
pwsh -File go.ps1 -Game einhander_recomp -Disc "D:\my discs\Einhander (USA).cue" -Speed
```

- For a game on several discs, list every `.cue` in order, separated by commas (each game's README shows
  the exact line).
- **The first time takes about 1-1.5 hours**: it downloads Java, the Android SDK and Python (about 5 GB),
  builds the recompiler once, then the game. Later games take 20-60 minutes each.
- When it finishes, the app is on your phone and the disc is copied to the phone's `Download\<game>` folder.
- Watch progress from a second PowerShell window: `pwsh -File watch.ps1`.

### 4. On the phone
1. Open the app (its icon is the game's box art when one was found).
2. **Select game file**: open the side menu > your phone's name > **Download** > the game's folder, pick
   the `.cue` (all of them for a multi-disc game). The "Downloads" shortcut shows the folder as empty;
   use the side menu path instead.
3. **Play.** The button at the top centre opens the menu: save/load state, change disc, restart, display
   options (resolution, smoothing, GPU renderer), controls and pad layout.

Memory-card saves are the game's own and are kept across app updates. **Save states only load in the build
that made them**: after an app update, make new ones.

### Games

Each game with a repository builds on its own: clone it with `--recurse-submodules`, put your discs in a
`discs\` folder next to it and run `scripts\RUN-ALL.ps1 -Install` (its README has the details and the disc
SHA-1s it accepts). With this repository's `go.ps1`, the `-Game` name is the game's folder name, for example
`tomba_recomp`.

**Status**: *playable* = played past the title on a phone; *boots* = reaches its title or intro, gameplay not
checked yet; *in progress* = known problems before it plays. **Speed** is the engine's own counter
(**1.00x = full speed**). LG V30 figures are from 2026-11-05 on the current engine, GPU renderer with the render
thread and idle skip on; Pixel 8 figures for the older games are from 2026-10-07/09 on the earlier engine.

| Game | Repository | Status | Pixel 8 (2023) | LG V30 (2017) |
|---|---|---|---|---|
| Final Fantasy VII (Shinra Archaeology Cut) | [ff7-android](https://github.com/dguillot-gh/ff7-android) | playable | 1.00x, 60 fps | 0.8-0.9x (field, battles) |
| Mizzurna Falls - The Chilling Cut | [mizzurnafallsthechillingcut-android](https://github.com/dguillot-gh/mizzurnafallsthechillingcut-android) | in progress | plays (older engine) | boots on the older engine; needs a Sony BIOS backend on the current one |
| Parasite Eve | [parasite-eve-android](https://github.com/dguillot-gh/parasite-eve-android) | playable | 60 fps | 0.25x (title) |
| Parasite Eve II | [parasite-eve2-android](https://github.com/dguillot-gh/parasite-eve2-android) | playable | plays; no sound | boots (not measured) |
| Persona | [persona-android](https://github.com/dguillot-gh/persona-android) | playable | 60 fps | 0.47-0.49x (boot screens) |
| Persona 2: Eternal Punishment | [persona2-android](https://github.com/dguillot-gh/persona2-android) | playable | ~60 fps | boots (not measured) |
| Policenauts (English patch) | [policenauts-android](https://github.com/dguillot-gh/policenauts-android) | playable | plays (touch trackpad); ~30 fps opening | boots (not measured) |
| Racing Lagoon (English patch) | [racinglagoon-android](https://github.com/dguillot-gh/racinglagoon-android) | in progress | builds; not play-tested | not tested |
| Tomba! | [tomba-android](https://github.com/dguillot-gh/tomba-android) | playable | 60 fps | 0.40-0.43x (title, intro) |
| Tomba! 2: The Evil Swine Return | [tomba2-android](https://github.com/dguillot-gh/tomba2-android) | playable | plays; GPU renderer recommended | not measured |
| Einhänder | no repository yet | playable | 60 fps | 0.41-0.76x (title, attract) |
| Xenogears | no repository yet | playable | not tested | 0.96-1.03x in the field; ~0.33x in dark/fog scenes |
| Jersey Devil | no repository yet | playable | not tested | 0.35x (tutorial room) |
| Castlevania: Symphony of the Night | no repository yet | boots | not tested | 0.79-1.00x (boot, attract) |
| Final Fantasy VIII | no repository yet | boots | not tested | 0.47x (intro) |
| Madden NFL 2002 | no repository yet | boots | not tested | 0.33-0.54x (boot, title) |
| Chrono Cross | no repository yet | boots | not tested | 0.17-0.20x (title) |
| Vagrant Story | no repository yet | boots | not tested | boots (not measured) |
| NASCAR Rumble | no repository yet | boots | not tested | boots (not measured) |
| Legend of Legaia | no repository yet | boots | not tested | boots (not measured) |
| MediEvil | no repository yet | boots | not tested | boots (not measured) |
| Tekken 3 | no repository yet | boots | not tested | intro movie (not measured) |

Set up but not booting or not checked yet: ATV Racers, Crash Bandicoot 2 and 3, LEGO Island 2, Gran Turismo 2,
Gex 1-3, Legend of Dragoon, Soul Reaver, retail Final Fantasy VII.

### If something goes wrong
- `go.ps1` ends with a **SUMMARY**; each failure names a log file. Logs are in `C:\psx\android-recomp\<game>\`.
- "No phone connected": check the cable, unlock the phone, accept the USB debugging prompt.
- "this disc is X, but the game is set up for Y": you have another region or version of the game.

---

## Rules (everyone)
- **Your own discs only.** Never commit or share disc images, BIOS files, saves, memory cards, APKs,
  generated code, or `tools-cache\debug.keystore` (the signing key). The `.gitignore` files keep them out.
- **Non-commercial use only**: psxrecomp is under the PolyForm Noncommercial license.

## On the build PC: the easy menu
All routine jobs (build, add a game, install, overnight speed, saves, phone storage, GitHub, engine update)
are in **`easy\MENU.ps1`** (right-click > Run with PowerShell). See `easy\README.md`.

## For maintainers
- `START-HERE.md`: the step-by-step guide on the build PC; `CONTEXT.md`: running notes and decisions;
  `PS1-RECOMP-ANDROID-HANDBOOK.md`: deep reference; `LOCAL-MODEL.md`: the local-model task system.
- `go.ps1` options: `-Game all`, several games comma-separated, `-Speed`, `-SpeedMinutes`, `-NoPhone`,
  `-NoInstall`, `-NoDiscPush`, `-Framework`, `-WorkDir` (see the top of `go.ps1`).
- `tools\phone-pass.ps1`: install, disc copy and test for games that are already built.
- `tools\export-games.ps1`: refresh `games\<name>` from the build drive's `recomps\` after changing a game.
- `tools\build-recompiler.ps1`: build the recompiler on this PC (go.ps1 does it when needed).

## License and credits
- The scripts and docs in this repository are under the **MIT License** (`LICENSE`).
- It does not cover the linked repositories: the engine (`framework/`, psxrecomp-android) is under
  **PolyForm Noncommercial 1.0.0** like [mstan/psxrecomp](https://github.com/mstan/psxrecomp) it is based on;
  each game repository under `games/` holds only configuration and has its own terms.
- Credits: [mstan/psxrecomp](https://github.com/mstan/psxrecomp) (the recompiler and runtime),
  [OpenBIOS](https://github.com/grumpycoders/pcsx-redux) (MIT, the free PS1 BIOS the apps boot),
  [SDL](https://libsdl.org) (zlib), and Slowbeef's Policenauts English translation patch (the Policenauts setup
  expects the patched disc). No game code, game data or BIOS images are part of any of these repositories.
