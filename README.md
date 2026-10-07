# psx-android

PlayStation 1 games as **native Android apps**, made with [psxrecomp](https://github.com/mstan/psxrecomp)
static recompilation: the game's own program is translated into C and compiled for the phone, not emulated.
Every app gets the same Android layer: touch pad (or a controller), a side menu with 12 save-state slots,
disc change, restart and display options, a movable FPS counter, software or GPU (OpenGL ES) rendering.

**Private repository. It contains no game code or data.** Each person builds the apps on their own PC from
**their own discs**. Never share the APKs you build: they contain the game's translated program.

| Repository | What |
|---|---|
| **psx-android** (this one) | build scripts, notes, and every game under `games/` (one repository each) |
| [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android) | the engine, in `framework/`: mstan/psxrecomp + our Android work (branch `android`) |
| `games/<name>` | one repository per game: its config, seeds, tools and play captures, plus its own README |

---

## Get a game on your phone

### What you need
- A **Windows 10/11 PC** with about **15 GB free** and internet for the first setup.
- **Your own copy of the game**, ripped to `.cue` + `.bin` (each game's README says which version).
- An **Android phone** (64-bit, Android 5 or newer; tested on a Pixel 8) and a USB cable.
- **PowerShell 7**: in a normal PowerShell window run `winget install Microsoft.PowerShell`.
- **GitHub Desktop** (or git), signed in with an account that has been given access to these repositories.

### 1. Get the repositories (once)
1. Make a folder with a short path, for example `C:\psx`.
2. In GitHub Desktop: **File > Clone repository > dguillot-gh/psx-android**, local path `C:\psx\psx-android`.
   GitHub Desktop also fetches the engine and every game (they are "submodules"). With plain git:
   `git clone --recursive https://github.com/dguillot-gh/psx-android.git`

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

| Game | `-Game` name | Discs | Status (Pixel 8) |
|---|---|---|---|
| Einhänder | `einhander_recomp` | 1 | plays, 60 fps |
| Final Fantasy VII | `ff7_recomp` | 3 | plays, ~50 fps in the opening |
| Parasite Eve | `parasite_eve_recomp` | 1 tested | plays, 60 fps |
| Parasite Eve II | `parasite_eve2_recomp` | 1 tested | plays; no sound yet |
| Persona | `persona_recomp` | 1 | plays, 60 fps |
| Persona 2: Eternal Punishment | `persona2_recomp` | 1 | plays, ~60 fps |
| Policenauts (Japanese) | `policenauts_recomp` | 2 | plays with the touch trackpad; slow opening |
| Tomba! | `tomba_recomp` | 1 | plays, 60 fps |
| Tomba! 2 | `tomba2_recomp` | 1 | plays; GPU renderer recommended |
| ATV Racers | `atvracers_recomp` | 1 | builds; save states work |
| Crash Bandicoot 2 | `crash2_recomp` | 1 | builds; first boot not checked |
| Crash Bandicoot 3: Warped | `crash3_recomp` | 1 | builds; first boot not checked |
| LEGO Island 2 | `legoisland2_recomp` | 1 | builds; first boot not checked |
| Gran Turismo 2 (Simulation) | `gt2sim_recomp` | 1 | **not working yet** |
| Legend of Dragoon, Gex 1-3, GT2 Arcade | see `games/` | | set up, not built yet |

### If something goes wrong
- `go.ps1` ends with a **SUMMARY**; each failure names a log file. Logs are in `C:\psx\android-recomp\<game>\`.
- "No phone connected": check the cable, unlock the phone, accept the USB debugging prompt.
- "this disc is X, but the game is set up for Y": you have another region or version of the game.

---

## Rules (everyone)
- **Your own discs only.** Never commit or share disc images, BIOS files, saves, memory cards, APKs,
  generated code, or `tools-cache\debug.keystore` (the signing key). The `.gitignore` files keep them out.
- **Non-commercial use only**: psxrecomp is under the PolyForm Noncommercial license.

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
