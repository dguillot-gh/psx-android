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
- **Pinned by the user (2026-10-06, "not just yet"):** keep [video] choices across a disc re-pick (store
  them like the pad layout); Analog on/off in the menu panel; an "adding a new game" checklist in START-HERE.
- **Pinned (2026-10-06): publishing to GitHub.** Plan discussed, nothing done: one repo per game (config,
  seeds, tools, aot_exclude, README; never discs, disc EXEs, BIOS, `generated/`, overlays, APKs, saves,
  keystore, box art), framework linked as a submodule (fork of mstan's psxrecomp, PolyForm Noncommercial)
  or upstream + patch files. First step when resumed: read-only diff of framework\psxrecomp (not a git
  checkout) against an upstream clone to isolate our changes. Personal GitHub account, private repos first.
- **GPU renderer pin, motivating number (2026-10-06):** FF7 on the software renderer with supersampling 4 +
  antialiasing + 16:9 + bilinear + perspective = ~20 game fps on the Pixel 8. Routes: adapt gpu_gl_renderer
  to GLES 3 (shaders, desktop-only calls; SDL GLES context) or the Vulkan backend. The user wants this later.
- **play-test fps is DISPLAY fps** (SurfaceFlinger presents), not game fps: FF7 "60" while the in-game FPS
  box showed 20. Fix: read `PsxInput.nativeGameFps` instead (e.g. turn the FPS counter on and log it).
- **framework\psxrecomp is a git repo now (2026-10-06).** Remote `upstream` = github.com/mstan/psxrecomp
  (partial clone, blob:none; core.autocrlf=true, core.filemode=false). Branches: `upstream-base` (240cff54,
  the upstream commit our copy came from), `android` (checked out; = upstream-base + "Android port work
  before 2026-10-06" + "FPS/menu/trackpad/D-pad" commits; every game syncs from this working tree),
  `gpu-gles` (worktree at framework\psxrecomp-gpu: OpenGL ES work, NOT synced to games; test by copying its
  changed files into one game's psxrecomp, e.g. tomba2). go.ps1/port-game.ps1 robocopy now skip `.git`.
  **Pinned:** update to upstream master (766 commits since 240cff54): rebase `android` onto it, rebuild the
  recompiler, regenerate + rebuild every game (new codegen hash = all overlays recompile). Home-PC script TBD.
- **Policenauts speed:** the new app (com.psxrecomp.policenauts) started with no play captures; the old
  app's are recovered from the 2026-10-03 snapshot (par\g*.json etc.) into build-android-overlays\
  play_captures.json -> 1279 pre-compiled pieces (old fast build: 903). Old app uninstalled by the user.
- **Pinned (2026-10-06):** (1) audio is lost after another app interrupts a game (pause/resume); a relaunch
  brings it back. Android-layer bug, all games. (2) 16:9 needs per-game widescreen MOD packages (main.cpp
  clamps [video] aspect_ratio: "widescreen is mod-owned on PSX"); the menu row is hidden. Tomba 1/2 have
  widescreen mods in mstan's game repos. (3) Built-in mods worth exposing in the menu: psx.enhancement.
  fast-loading, cd-speed, pgxp (framework\psxrecomp\mods\builtin\packages).
- **GPU (gpu-gles) first results, Tomba 2 on the Pixel 8 (Mali-G715, OpenGL ES 3.2):** pipeline comes up,
  picture correct at 1x; 4x + bilinear + perspective = 31-42 game fps (0.55x). Next: profile (suspect
  per-frame CPU<->GPU VRAM sync/readback), not fill rate.
- **Pinned (2026-10-06): GPU work paused after step 2b** (keep the hr FBO bound between batches; Tomba 2
  gameplay did ~4,500 hr FBO binds/s at 4x -> 30-45 fps; Tomba 1 4x = solid 60). Next GPU steps when resumed:
  re-enable dual-source via GL_EXT_blend_func_extended (Mali has it), batch uploads, then a threaded
  renderer. **Pinned: multi-core** = GPU submission thread ("threaded rendering"), then SPU and MDEC
  threads; game code itself stays single-threaded. Check upstream master for existing threading first.
- **End of 2026-10-06 (Surface):** framework branch `android` = 41dc4e4 (merge of gpu-gles: GLES renderer
  option, default software; tile-GPU fix 2b). All 8 games rebuilt from it and installed (apks\2026-10-06,
  16:57-19:35 builds). Tomba 1+2 set to GPU 2x by the user; profiler (files/runtime_env) removed everywhere.
  **Open, pinned for next session:**
  1. Policenauts is slow in its opening on software (in-game 29-44 fps, 0.5-0.7x) despite ~1,480 AOT
     pieces; the old fast build held 60 there. Profile with files/runtime_env PSX_RUNTIME_PERF_DIAG=1
     while the user plays (dirty/interp counts, which slots run interpreted; 0006C000/00012000 excluded).
  2. Verify GPU step 2b (keep hr FBO bound) in Tomba 2 GAMEPLAY at 4x (intro already 60).
  3. 16:9 toggle ("route 1"): drop the PSX mod-owned widescreen clamp in our fork for [video] aspect_ratio,
     un-hide the menu row, check letterboxing on software + GPU; then rebuild all (~1.5 h). Route 2 later:
     mstan's tuned Tomba 1/2 widescreen mods.
  4. Audio dies after another app interrupts a game (relaunch fixes it).
  5. play-test reports DISPLAY fps; switch it to the in-game [FPS] lines (logged when the FPS counter is on).
  6. Policenauts + Tomba 2 pre-compile still has unfinished groups (45-min limit); next -Speed run continues.

## 2026-10-07 (Surface) — framework moved to upstream master; 10 new games
- **framework\psxrecomp branch `android` = upstream master 8077e710 + our Android work** (merge 5ff292a5,
  fixes bf4c2f72). The old branch is tag `android-pre-upstream`. Work-PC copy must be re-synced from this.
  Merge choices: upstream's disc roster (cdrom_disc_select) is used; our `cdrom_swap_disc(path)` is now a
  wrapper over it. Kept: inlined cycle charge, interrupt fast path (+ upstream frozen-time guard), single
  dispatch validation, GLES renderer + hr FBO fix, Android CMake, overlay cross-compile (target_os_tag maps
  android -> linux; interpreter-arch check skipped for android). DROPPED for now (upstream rewrote that
  code): dense game-dispatch index and the BIOS key-page fast route — port into
  recompiler/src/game_dispatch_emitter.cpp if speed is worse than before. Mouse (Policenauts) hooks into
  upstream's drain_host_events(). Android: g_fullscreen forced 0 + FULLSCREEN_DESKTOP flag.
- **Codegen hash is now 6d3e857a** (every game's pre-compiled overlays rebuild).
- **Recompiler is built on this PC** with portable llvm-mingw (tools-cache\llvm-mingw, release 20260922)
  and the SDK's cmake 3.22.1: needs `-DPSXRECOMP_ENABLE_CHD=OFF` and CMAKE_CXX_FLAGS forcing the std
  headers (`-include cstdlib -include cstdio -include cstring -include cstdint -include exception
  -include algorithm -include functional -include memory -include string -include vector -include utility
  -include limits`); copy libc++.dll + libunwind.dll next to the exe. Old exe: tools-cache\
  recompiler-build-mingw-pre-upstream.
- go.ps1: `-Framework <dir>` (test a framework copy, with `-WorkDir` elsewhere); existing games now get the
  framework by robocopy /MIR (no stale files). make-game-toml-in.ps1: a probe-made game with only
  `disc = "..."` gets one @@DISC1@@ slot (Einhander quit "no disc image selected" before).
  play-test summary now leads with GAME fps from the runtime's [FPS] log lines (needs the FPS counter on).
- **New games (recomps\, from to-do\):** einhander (seeds = strider973/Einhander-Recompiled, same disc
  md5), atvracers, crash2, crash3 (Warped), gex, gex2, gex3, gt2arcade + gt2sim (separate apps: each disc
  boots its own EXE), legoisland2, lod (4 discs). Einhander verified booting/playing on the phone (debug
  build). The rest: first boots pending.
- Phone is on USB debugging now (wired).
- **Batch result (2026-10-07, all on the new framework, installed with saves backed up):** einhander, ff7,
  parasite_eve, parasite_eve2, persona, persona2, policenauts, tomba, tomba2, atvracers, crash2, crash3,
  legoisland2. 30 s tests: 60 fps einhander/pe/persona/tomba/tomba2, ~60 persona2, ~50 ff7 opening, ~30
  policenauts opening (known). Save states from before the switch don't load (new code); new ones work (ATV).
  Speed step hit its cap for policenauts (45), persona (45), tomba2 (15, -SpeedMinutes): next run continues.
- **Not built:** gt2sim + lod (and probably gt2arcade): the boot EXE is mostly data (740 "reserved opcode"
  words across 0x80011E30-0x800A8AA0 in GT2); hundreds of "functions" start inside data and run to its end, so
  the recompiler emits ~1000 shards x 5 MB (5 GB of C) and the PC runs out of memory. Needs a data-range
  fix (no such option in game.toml today) or real code boundaries. Set aside in ..\recomps-later\ with the
  three Gex games (user's choice); gt2sim stays in recomps\ but out of runs.
- **Pipeline fixes today:** port-game escapes apostrophes in the app name (LEGO Island 2 "Brickster's");
  phone.ps1 starts the adb server DETACHED (an adb server started inside `pwsh ... | Out-Host` inherited the
  pipe and hung speed.ps1 45 min); go.ps1 -Game takes a comma list, -NoInstall, -SpeedMinutes;
  tools\phone-pass.ps1 (install + disc + card + test for built games). Portable pwsh 7 segfaulted twice
  with two go.ps1 runs side by side: run long batches as one go.ps1 per game.
- **GitHub (account dguillot-gh, all private):** psxrecomp-android (framework, default branch android, tag
  android-pre-upstream, Actions DISABLED so upstream's desktop CI doesn't run), one repo per game
  (<name>-android, from games\<name>, strict .gitignore), psx-android (this repo; games\ and framework\ as
  submodules). gh CLI portable in tools-cache\gh (signed in by the user; scopes repo, workflow). Push with
  `git -c credential.helper= -c "credential.helper=!<gh.exe> auth git-credential" push` (no global config).
  Co-worker flow: README.md (clone --recursive, go.ps1 -Game x -Disc <their cue>); new-recomp.ps1 uses the
  repo's games\<name> setup and only takes disc names from their copy; build-recompiler.ps1 self-builds.
- **Pinned (user):** shareable APK with no game code that builds the game on the phone from the user's disc
  (like Matteo842/CrashBandicoot-Launcher, ZeldaWWHDRecomp); later GitHub Actions builds it as a Release.

## PINNED LIST (consolidated end of 2026-10-07; supersedes the scattered pins above)
Fixes: (1) Policenauts opening ~30 fps (full speed pre-compile running tonight; re-test, then profile with
PSX_RUNTIME_PERF_DIAG=1). (2) PE2 no sound. (3) Audio dies after another app interrupts (all games).
(4) Persona 2 / Tomba 2 cutscene lag (re-check). (5) First boots: crash2, crash3, legoisland2, gex 1-3 (gex2
retry queued after tonight's batch). (6) gt2sim / gt2arcade / lod: data-as-code recompiler fix. (7) Re-port
the dense game-dispatch index + BIOS key-page route into game_dispatch_emitter.cpp if speed regressed.
Features: (8) 16:9 toggle (route 1 drop clamp + unhide row; route 2 mstan's Tomba 1/2 widescreen mods).
(9) Analog on/off in the menu panel. (10) Keep [video] choices across a disc re-pick. (11) Built-in mods in
the menu (fast-loading, cd-speed, pgxp). (12) GPU: verify Tomba 2 gameplay at 4x; EXT_blend_func_extended
dual-source, batched uploads, threaded renderer; later multi-core (SPU/MDEC threads).
Pipeline: (13) download SDL3 once, reuse in every build (a DNS drop failed gex2 at 17:20). (14) phone
install: skip the Download disc copy when files/gamedata already has the disc (phone filled up 2026-10-07).
(15) test the co-worker flow on a fresh `git clone --recursive` of psx-android. (16) "adding a new game"
checklist in START-HERE. (17) sync the work-PC framework copy to branch android (f1919cd6).
Sharing: (18) shareable APK (memory note "project-shareable-apk-on-device-build"): milestone 1 = engine-only
APK loading the game code module from storage; then on-phone TCC build; one library app keyed by disc
serial; GitHub Actions releases + Obtainium. (19) upstream PR of the Android layer to mstan/psxrecomp.
(20) make repos public after stripping local paths from game.toml; invite co-workers (read-only).

## 2026-10-08: GitHub "Build APK" button on a home build PC (self-hosted runner)
- RUNNER.md = the guide. `.github/workflows/build-apk.yml` (workflow_dispatch: game, speed, speed_minutes, clean)
  runs on runner label `psx-build` (the Windows VM on the user's Proxmox box: 3 cores, 13 GB, little disk;
  discs on the NAS, env PSX_DISCS in actions-runner\.env, copied in per game and removed after).
- `tools/ci-build.ps1`: pulls psx-android (ff-only) + games submodules, engine (origin/android, rebuilds the
  recompiler when recompiler/ changed), copies games\<name> setup into recomps\<name> keeping this PC's
  [game] disc lines; go.ps1 -NoPhone -NoTasks per game at BelowNormal priority; APKs -> private Release of
  psx-android (tag apk-<date>-<game>) with the workflow token (RELEASE_TOKEN); -Clean removes work folders.
- Signing: secret PSX_KEYSTORE_B64 (= tools-cache\debug.keystore); build.ps1 prefers env PSX_KEYSTORE.
- go.ps1 got -NoTasks (skip the local-model task cards). `tools/setup-runner.ps1`: MinGit if no git, gh login,
  runner download (SHA-256 checked), registration, Windows service as the user's account, .env.
- Public repos later: move the button + Releases to a separate PRIVATE repo first (runner + game-code APKs).
- Later the same day: the button, runner and Releases MOVED to the PRIVATE repo dguillot-gh/psx-android-builds
  (workflow there; secret PSX_KEYSTORE_B64 there; ci-build releases to RELEASE_REPO). psx-android, the engine
  and the game repos can then go public (user's call). export-games.ps1 strips absolute disc paths from
  game.toml (6 game repos cleaned 2026-10-08). move-to-nas.ps1 / setup-vm.ps1 retire the USB drive (RUNNER.md).
