# CONTEXT (read this first; keep answers short)

## What this is
PS1 games turned into native C ("static recomp", framework = `psxrecomp`) and packaged as Android apps for a Pixel 8.
This repo holds small PowerShell tools that set up each game's Android app. You write ONE tool per task card.

## Rules
- PowerShell only (`.ps1`). No `.bat`/`.cmd`. Target PowerShell 7 (`pwsh`).
- Do exactly what the task card says. If something is missing, write `UNKNOWN: <what you need>` and stop.
- The check script named in the card is the judge. Make it print OK. Never edit check scripts, fixtures or templates.
- Never delete or modify: disc images (`disc\`), memory cards (`saves\`, `*.mcd`), anything outside the output folder.
- Never `adb uninstall`. Never edit `psxrecomp\runtime`, `psxrecomp\recompiler` or `generated\` (C/C++ is not your job).
- Prefer simple code: robocopy for copies, `Get-Content -Raw` + `.Replace()` for text, `Set-Content -Encoding utf8NoBOM`.
- robocopy exit codes 0-7 mean success; 8+ means failure. After robocopy, check `$LASTEXITCODE -ge 8`.
- No TOML module exists. Read `game.toml` as text: sections are lines like `[game]`, keys are `name = "value"`.

## Folder layout (drive root = `<drive>:\recomp-backups`)
```
recomps\<game>_recomp\          ORIGINAL games (read only): game.toml, generated\, seeds\, disc\, saves\, CMakeLists.txt
framework\psxrecomp\            NEWEST framework (read only). Every port copies it.
2026-10-03\tomba_recomp\        first finished Android game (snapshot, read only)
2026-10-03\policenauts_recomp\  first game (older app, mouse controls)
psx-android-tools\              THIS repo
  template\android\             Android app template (copied from Tomba; package com.psxrecomp.tomba)
  template\CMakeLists.txt.in    game CMakeLists with @@PROJECT@@ @@TITLE@@ @@EXE@@
  tasks\NN-*.md                 task cards        tools\*.ps1  tools + check-NN.ps1
  tests\fixtures\               small fake inputs for checks
```

## A game's Android setup (what the tools produce)
```
<game>\game.toml                 desktop config (input)
<game>\psxrecomp\                framework copy (from tomba_recomp\psxrecomp, without recompiler\build)
<game>\CMakeLists.txt            from template\CMakeLists.txt.in
<game>\android\app\build.gradle  namespace = "com.psxrecomp.<short>"
<game>\android\app\src\main\res\values\strings.xml   app_name, psx_game_title, psx_game_id
<game>\android\app\src\main\res\values\bools.xml     psx_analog_sticks (true only if default_mode = "analog")
<game>\android\app\src\main\assets\game.toml.in      Android config with @@DISC1@@.. placeholders
```
Shared Java (`com.psxrecomp.android`: start menu, touch pad, game screen) lives in `psxrecomp\runtime\android\java`
and SDL Java in `org.libsdl.app`. Never rename those two package names.

## Games
| folder | id | exe | discs | pad |
|---|---|---|---|---|
| tomba_recomp | SCUS-94236 | SCUS_942.36 | 1 | digital (DONE on phone) |
| tomba2_recomp | SCUS-94454 | SCUS_944.54 | 1 (2 track .bins) | digital |
| persona_recomp | SLUS-00339 | SLUS_003.39 | 1 | digital |
| persona2_recomp | SLUS-01158 | SLUS_011.58 | 1 | digital |
| parasite_eve_recomp | SLUS-00662 | SLUS_006.62 | 2 listed, only Disc 1 image present | digital |
| parasite_eve2_recomp | SLUS-01042 | SLUS_010.42 | 2 listed, only Disc 1 image present | digital |

## Build / phone commands (for reference; tasks tell you when to use them)
- Build APK: `cd <game>\android; .\gradlew.bat :app:assembleDebug` (add `-PpsxPlayBuild` for the fast build).
  Needs JDK 17, Android SDK with NDK 28.2.13676358 and CMake 3.22.1; `android\local.properties` = `sdk.dir=<sdk path>`.
- Phone: `adb mdns services`, `adb connect <ip>:<port>`, `adb install -r <apk>` (-r keeps saves).
- Saves on phone: `adb exec-out run-as <package> cat files/card1.mcd > card1.mcd` (same for card2). Back up BEFORE installing.
- Launch: `adb shell monkey -p <package> -c android.intent.category.LAUNCHER 1`
- Regenerate game C: `<game>\psxrecomp\recompiler\build-mingw\psxrecomp-game.exe --config game.toml` (run in `<game>`).
  go.ps1 does this itself: once per game, and again whenever that exe is newer than `<game>\.regenerated`.
  Outside a game folder (no `psxrecomp\` next to game.toml) add `--project-root <drive>:\recomp-backups\framework\psxrecomp`.

## Fast builds: `go.ps1 -Speed` (since 2026-10-05)
- Games load extra code ("overlays") from the disc at runtime; uncompiled, it runs on a slow interpreter.
  `tools\speed.ps1` pre-compiles it into `<game>\build-android-overlays\cache\<game id>\gcc\linux-arm64\`,
  which the play build (`build.ps1 -Play`) bundles into the APK.
- Sources of that code: `disc_captures.json` (found on the disc by `psxrecomp\tools\aot_overlay_spike\extract_generic.py`;
  works for Tomba 2 and Persona, finds nothing for Persona 2 / Parasite Eve 1+2) and `play_captures.json` (what the
  phone recorded while the game was played: `files/overlay_captures.json`, pulled read-only by
  `phone.ps1 -Action pull-captures`, accumulated across runs). More play = more pre-compiled code.
- Python: portable, on the drive (`tools-cache\python\tools\python.exe`, found by `Find-Python` in paths.ps1).
  The home PC has no Python of its own. `tools\captures.py` merges/splits captures (stdlib only).
- The compiler is `psxrecomp\tools\compile_overlays.py --target-os android --cps` with the NDK's clang, one process per
  group (`par\gNN.json`, one per CPU core). Shards are tagged with the codegen hash (`cg10_<hash>_...`); the app only
  bundles shards whose hash matches its runtime, and the runtime CRC-checks every piece before running it.
- `phone.ps1 -Action play-test` launches a game, taps PLAY, and saves fps (SurfaceFlinger frame timing),
  screenshots and logcat into `<game>\phone-test\<date-time>\`.

## New games from a disc: `tools\new-recomp.ps1 -Name <x>_recomp -Disc <cue1>,<cue2>,...` (since 2026-10-05)
- Creates `recomps\<x>_recomp\` (disc\ with every cue + track file, game.toml, seeds\ghidra_funcs.txt,
  catalog_identity.json, disc_probe.json, saves\) using the framework's
  `psxrecomp\tools\new_project_layout\probe_disc.py` (extra discs via --extra-disc-list). Verified on Tomba 2: same
  id/exe/load/entry/text size and 214 seeds as the hand-made recomp; the recompiler generates code from it.
- `generated\` does not exist yet; go.ps1's REGEN step creates it. Then port/build as usual.
- First boot of a brand-new game is Claude's job (seeds from runtime discovery, overlays, crashes).

## Since 2026-10-05 also
- `RUN-ALL.ps1` = `go.ps1 -Game all -Speed`: the single unattended command.
- Save states: pad menu "Save state" / "Load state" (PadOverlay) > PsxInput.nativeRequestState > the runtime's
  savestate_request_save/load between frames; 12 slots, files in the app's files/openbios/state_*_slotNN.pst.
- Icons: `tools\icon.ps1` (box art via fetch_boxart.py + `tools\MakeIcon.java`), run by go.ps1 once per game.
- Memory card import: `<game>\memcard-import\*.mcd` goes into a fresh app (phone.ps1 import-card; never overwrites).
- Signing: one key for all PCs in `tools-cache\debug.keystore` (setup.ps1 copies the home PC's; build.ps1 uses it).
- Disc file names may contain [ ]: PowerShell treats them as wildcards, so scripts use -LiteralPath for them.

## Multi-disc games (since 2026-10-05; framework code, not a tool task)
- A game's `game.toml` lists its discs (`discs = [...]`); the app's `game.toml.in` has one `@@DISCn@@` line per disc.
- The start menu (LauncherActivity) accepts several .cue files at once, numbers them by name in natural order,
  and writes one line per imported disc into files/game.toml (fillDiscs).
- In game: pad menu button > "Change disc" (PadOverlay) > PsxInput.nativeRequestDiscSwap(n) > the runtime swaps
  between frames with cdrom_swap_disc() (runtime/src/cdrom.c): tray open, new image, tray close.
- Tools only need to put every disc's .cue/.bin into `<game>\disc\`; phone.ps1 push-disc copies them all.

## Known: oversized generated files (fixed 2026-10-05)
- Normal `generated\*.c` files are 1-2 MB. A run of zero words in a game's EXE (an empty area where the game loads
  more code later) used to be written out one line per word: Parasite Eve got a 20 MB file that took hours and ran
  a 16 GB PC out of memory. The recompiler now writes such runs as one short C loop with the same behaviour.
- Safety nets: go.ps1 prints `WARNING: oversized generated file <name>` for any file over 4 MB, and the build
  compiles such a file without optimisation (runtime.cmake) so it still finishes.
- That WARNING is never yours to fix: no tool may edit `generated\`, `psxrecomp\recompiler` or `runtime.cmake`.
  Keep the line and report it; Claude fixes the recompiler.

## 2026-10-06 (Surface session) — framework changes, sync to the work PC's copy
- **FPS counter:** pad menu second row has `FPS: on/off` (PadOverlay, remembered per game in prefs
  `fps_counter`) > `PsxInput.nativeSetFpsCounter` > `android_apply_fps_request()` in main.cpp, which
  calls the existing `fps_telemetry_toggle()`. Shows the runtime's "Game N FPS 1.00x" status line top left.
- **On-screen toasts on Android:** `host_osd.c` now sets HOST_OSD_VISUAL for `__ANDROID__` too (it was
  launcher-only, so "Disc 2 inserted", "Saved slot N" etc. were never drawn on the phone).
- **Mouse games on the shared pad:** game.toml `[controller] mouse = true` makes PadOverlay a trackpad
  (reads assets/game.toml.in): pad buttons hidden, drag = cursor (accelerated: 0.45-1.6 counts/dp),
  tap = left click, two-finger tap = right click. New JNI `PsxInput.nativeMouseMotion/nativeMouseButton`
  (forward to the old PolicenautsActivity ones). None of these files are codegen-hash inputs (still d8b96482).
- **Policenauts is in recomps\policenauts_recomp** (from the 2026-10-03 snapshot): both discs, seeds,
  `tools\overlay_extract.py` (wraps extract_bin_dpk.py), `aot_exclude.txt` (0006C000 logo-hang bug,
  00012000), cards from the old app in `memcard-import\`. New package `com.psxrecomp.policenauts`
  installs NEXT TO the old `com.policenauts.recomp` (old key D1:59:67:7F is not on the drive).
- **template build.gradle:** stageGameOverlays skips slots listed in `<game>\aot_exclude.txt`.
- **go.ps1 -Game all now includes tomba_recomp.** The phone's Tomba 1 is signed with the old D1:59 key:
  the first install of the new build needs a full data backup, uninstall, install, restore (user said yes
  once, 2026-10-06). After that it updates normally.
- **setup.ps1:** command-line tools 23+ use `android sdk install ndk/28.2...` (sdkmanager.bat now forwards
  to it and cmd split the `;` names). **phone.ps1 import-card:** push to /data/local/tmp + `run-as cp`
  (exec-in stdin wrote nothing on the Pixel 8).
- PowerShell 7 portable is in `tools-cache\pwsh` (this PC has no installed pwsh).
- **Pad menu is now a side panel (PsxMenu.java, 2026-10-06):** the top-centre button opens a scrolling panel
  (right ~40% of the screen): Game (save/load state, change disc, Restart game), Display (FPS counter;
  [video] supersampling 1-4x, antialiasing, texture_filtering, perspective_texturing written into
  files/game.toml), Controls (Edit pad layout = the old drag editor, opacity). Display options need a
  restart: Restart saves a state to the LAST slot, writes files/autoload_slot + files/restart_pending, kills
  the ":game" process; LauncherActivity.onResume relaunches; PadOverlay loads the slot 3 s after start.
  Re-picking discs in the start menu rewrites files/game.toml (the [video] choices are lost then).
- **FPS counter is a movable pad control** (KIND_FPS, drawn by PadOverlay from `PsxInput.nativeGameFps()`);
  on Android the runtime no longer draws the status line into the picture.
- **PINNED by the user: GPU (OpenGL ES) renderer on Android.** PsxGameActivity passes `--renderer software`
  on purpose ("unavailable SDL GLES window path"). The software renderer's supersampling already works:
  Tomba 2 at 2x held ~58 fps on the Pixel 8 (same as 1x). Revisit GLES only if software scaling isn't enough.
