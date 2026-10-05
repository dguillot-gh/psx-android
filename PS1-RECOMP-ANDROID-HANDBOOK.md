# PS1 static recomps on Android: handbook

Everything learned porting **Policenauts** and **Tomba!** (psxrecomp static recompilations) to a
Pixel 8, written so the next game, or the next person, can pick it up cold.
Last updated 2026-10-03.

---

## 1. Goals and ground rules

- Goal: games that feel native on the phone, a **steady 60 fps** (an occasional stutter is OK),
  with Claude driving builds, installs and tests over adb and reporting results with numbers.
- **Saves are sacred.** Never let anything delete or overwrite a memory card without an explicit
  yes. Back up app data before any uninstall. Use the empty Memory Card 2 for test runs.
- One game per chat. Remaining games are on the USB drive `F:\recomps`: tomba2, parasite_eve,
  parasite_eve2, persona, persona2 (each 0.4-0.8 GB without `build-release/`).
- **psxrecomp/CLAUDE.md** rules apply to the framework: faithful, general fixes (no per-game
  hacks during foundation work), **no printf or log-file debugging** (use the TCP debug server or
  the perf report), never hand-edit generated code (fix the recompiler and regenerate), and fix
  broken tooling the moment it is found.

## 2. The work PC (policy-locked)

Company group policy **blocks `.bat`/`.cmd` in user-writable folders** (gradlew.bat,
sdkmanager.bat, CMake's post-build.bat). `.exe` files run fine. **Do not route around the policy.**
The approved way is the same as Android Studio's: call Java directly.

| Tool | Location / note |
|---|---|
| JDK 17 | `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` (pinned in `~/.gradle/gradle.properties`; Gradle 8.12 fails on JDK 25) |
| Android SDK | `C:\Users\dguillot\AppData\Local\Android\Sdk`, NDK `28.2.13676358`, CMake 3.22.1 |
| adb | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Google.PlatformTools_*\platform-tools\adb.exe` |
| llvm-mingw (recompiler host build) | `C:\Users\dguillot\tools\llvm-mingw-20260922-ucrt-x86_64` (put `bin` on PATH to run the exes) |
| Python 3.12 | `%LOCALAPPDATA%\Programs\Python\Python312\python.exe` (no PIL) |

The recompiler is built with llvm-mingw into `psxrecomp/recompiler/build-mingw`
(`CMAKE_CXX_FLAGS=-include cstdlib -include exception -include cstring`, `PSXRECOMP_ENABLE_CHD=OFF`).
Android-irrelevant POST_BUILD staging is gated `NOT ANDROID`, so no post-build.bat is ever generated.

In Git Bash, set `MSYS_NO_PATHCONV=1` for adb device paths, but pass local APK paths as `C:/...`.

## 3. Folder layout

```
C:\Users\dguillot\Documents\recomp\
  policenauts_recomp\        Policenauts (SLPS-00215), package com.policenauts.recomp
  tomba_recomp\              Tomba! (SCUS-94236), package com.psxrecomp.tomba
  phone-backup\              earlier phone pulls (Policenauts app data tar, memcards, md5s)
  PS1-RECOMP-ANDROID-HANDBOOK.md   (this file)
<game>\
  CMakeLists.txt  game.toml  generated\  seeds\  disc\  saves\
  psxrecomp\                 the framework (each game ships its own copy)
  android\                   Gradle app (app\build.gradle, src\main\...)
  build-android-overlays\    AOT overlay captures, parallel compile, merged cache
```

**Backups:** `F:\recomp-backups\2026-10-03\` holds both projects, phone-backup, Claude's memory
notes, both sessions' scratch folders (installed APKs, bisect log, Tomba card backup) and this
handbook.

## 4. Build, install, run

### Build

```bash
cd <game>/android
"C:/Program Files/Microsoft/jdk-17.0.20.101-hotspot/bin/java.exe" -classpath gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain :app:assembleDebug
```

- Add `-PpsxPlayBuild` for the **play build**: `PSX_DEBUG_TOOLS=OFF`, no debug server, about 20% faster.
  The default build keeps the TCP debug server (port 4370).
- A full native build takes about 28 minutes (1.5 M lines of generated C, `-O3 -flto=thin`).
  An incremental build after one runtime .cpp changes takes about 7 minutes; Java-only changes take seconds.
- Output: `android/app/build/outputs/apk/debug/app-debug.apk`. Copy each APK you install to a
  named file (`play7_fastcyc.apk`, `tomba_dbg2.apk`, ...) so you can roll back.

### Phone (Pixel 8, wireless adb)

```bash
adb mdns services                 # find the current port (it changes)
adb connect 192.168.0.134:<port>
adb install -r app.apk            # -r keeps app data; never uninstall without backing up
```

Wireless debugging drops overnight; the user re-enables it on the phone.

### Debugging and measuring

- **Logcat:** `adb logcat -d` usually misses the runtime's lines, because the 256 KB main buffer
  fills with system chatter (keyboard, Bluetooth) within seconds. Start a live capture
  **before** launching: `adb logcat -v time > live.log &`. Runtime lines use tag `psxrecomp`.
- **Perf report:** `adb shell run-as <pkg> touch files/perf_diag` and relaunch. Every 2 s it logs
  `runtime cadence: guest=59.99 Hz ... work guest=NNN ms/s pacer=... overlay native=+N interp=+N`.
  `work guest` is the emulator CPU time per second (below about 1000 means headroom). Delete the
  file to switch it off.
- **Extra env vars:** write `KEY=VALUE` lines into `files/runtime_env` (via run-as). They are read at launch.
- **TCP debug server** (debug builds): `adb forward tcp:4370 tcp:4370`, then
  `python psxrecomp/tools/raw_tcp.py 4370 <cmd>` or `tools/debug_client.py`. Useful commands:
  `ping`, `frame`, `overlay_loader_status` (native vs interpreted overlay dispatch),
  `dirty_ram_stats`, `dispatch_stats`, `overlay_native_off/on` (A/B a scene), `read_ram`.
  Frames per second = the change in `frame` per second. The server stops answering while the app is backgrounded.
- **Display fps without the debug server:** `adb shell dumpsys SurfaceFlinger --latency` on the
  `SurfaceView[...](BLAST)` layer.
- **Screenshots:** `adb exec-out screencap -p > shot.png`. Taps: `adb shell input tap x y`;
  hold a button: `input swipe x y x y <ms>`. In landscape the screen is 2400x1080.
- `simpleperf` is the planned profiler for hot spots (Policenauts speed work used it).

## 5. Regenerating game code

```bash
export PATH=/c/Users/dguillot/tools/llvm-mingw-20260922-ucrt-x86_64/bin:$PATH
cd <game>
./psxrecomp/recompiler/build-mingw/psxrecomp-game.exe --config game.toml
```

This is the core of `psxrecomp_cli.py generate`, minus the toolchain download. Copy `generated/` to a
scratch baseline first, then `diff -r`. Tomba: all 41 shards were byte-identical; only
`*_dispatch.c` gained the new dense lookup index.

**Codegen hash gotcha:** editing any file listed in `psxrecomp/runtime/codegen_hash_sources.cmake`
(emitter sources, overlay ABI headers) changes `PSX_OVERLAY_CODEGEN_HASH`. The phone's overlay
cache folder `cg10_<hash>_...` then changes, and **every overlay must be recompiled**. The
current hash for both games is `ee27d7e5`. `config_loader.*`, `main.cpp`, `memcard.c` and the Java
code are **not** in the hash.

**Zero runs (fixed 2026-10-05, drive framework only).** A run of zero words in the EXE (an overlay
load area reached by a `jal` before the overlay is installed) was emitted one statement per word:
Parasite Eve's `func_8019234C` was 441 KB of zeros, a 20 MB shard with one 110k-statement function
that ran a 16 GB PC out of memory even at -O0. `code_generator.cpp` now emits 64+ consecutive
zero words with no other per-address emission as one C loop with the identical per-word effects
(I-cache fetch at line starts, the nop's `psx_cyc_step`, `cosim_instr`). Result: PE 62 → 53 shards,
Persona 2 46 → 26, nothing over ~2 MB in any of the six games. Codegen hash on the drive framework
is now `d8b96482`; Tomba's and Policenauts' C: copies are still on `ee27d7e5` (syncing this change
there means recompiling their AOT overlays). Recompiler rebuild: build dir
`recomp-backups\tools-cache\recompiler-build` (Ninja + llvm-mingw, `CMAKE_CXX_FLAGS="-include cstdlib
-include exception -include cstring"` for rabbitizer), then copy the exe into `framework\psxrecomp\
recompiler\build-mingw\`. Outside a game folder the exe needs `--project-root <framework>`.
Safety nets: runtime.cmake builds any shard > 4 MB at -O0 without LTO, and go.ps1 warns about it.
A regeneration that changes the NUMBER of shards needs the shard glob to be re-run: runtime.cmake's
GEN_FULL_GLOB uses `file(GLOB ... CONFIGURE_DEPENDS)` since 2026-10-05; before that an incremental build
failed with "Recompiled game code is MISSING", listing the deleted shards.

## 6. Overlays: ahead-of-time (AOT) compiled code

PS1 games load code from disc at runtime ("overlays"). Without help they run on the dirty-RAM
interpreter (correct but slow). The fix is to compile them ahead of time into `.so` shards,
bundle them in the APK, and install them into the runtime cache on first launch
(`files/cache/<game-id>/gcc/linux-arm64/cg10_<hash>_gcc15c8ed0_f0/`). Every shard is CRC-guarded
at dispatch, so a mismatched shard is skipped, never run wrong. A shard can still be
**miscompiled**, though: always verify visually.

1. **Captures** (synthetic `overlay_captures.json`, made without playing):
   - Generic: `psxrecomp/tools/aot_overlay_spike/extract_generic.py --game-toml game.toml --recompiler <psxrecomp-game.exe> --out caps.json --tmp tmpdir`.
     For Tomba it found 24 code overlays (X??.BIN, INFO*.BIN, DSPSUB*.BIN, OPTSUB00.BIN, all
     loaded at region 0x800E7000 +904) plus a BIOS helper: 25 regions, in 14 s.
   - Policenauts needs its own splitter first, because all of its code lives in one FRID archive:
     `policenauts_recomp/tools/extract_bin_dpk.py` (/NAUTS/BIN.DPK; Disc 2's copy is identical).
   - Captures can also come from play: with `[runtime] overlay_cache = true` the phone writes
     `files/overlay_captures.json`.
2. **Compile in parallel** (`build-android-overlays/par/run.sh`): split the captures into
   size-balanced groups (12 for Tomba, 17 for Policenauts) and run one `compile_overlays.py`
   per group with `--target-os android --target-arch arm64 --android-sysroot <NDK>/sysroot --gcc <NDK clang> --cps --jobs 1`.
   Use a `--game-toml` filled from the app's `game.toml.in`. Only `[widescreen]` fields feed the
   config hash. Tomba: 283 shards, 0 failed, about 25 min.
3. **Merge** `par/out_gXX/<id>/gcc/linux-arm64/cg10_*/` into `build-android-overlays/cache/...`
   (Tomba) or `cache2/...` (Policenauts). `app/build.gradle` (`stageGameOverlays`) bundles the
   shards matching the current codegen hash as APK assets. `-PpsxOverlayCache=<dir>` overrides the source.
4. **Verify:** `overlay_loader_status` shows `dispatch_native` climbing and `last_msg` naming the
   loaded shard. Then compare screenshots of a scene with `overlay_native_off` and `on`.

## 7. The shared Android layer (built for Tomba, meant for every game)

Location: `psxrecomp/runtime/android/java/com/psxrecomp/android/`. The game app picks it up through
`sourceSets.main.java.srcDir(new File(gameRoot, 'psxrecomp/runtime/android/java'))`. SDL's own
Java (`org.libsdl.app`, SDL 3.4.10) stays in each app.

| Class | What it does |
|---|---|
| `LauncherActivity` | Bare-bones start menu: game title, which disc file is loaded, **Play**, **Select game file**. Accepts a .cue picked together with its .bin(s), or a single .bin/.img/.iso/.chd, with a folder fallback when tracks are missing. Copies into `files/gamedata` with a progress bar, fixes case-only cue mismatches, and writes `files/game.toml` from `assets/game.toml.in` (`@@DISC1@@`). Never touches memory cards. |
| `PsxGameActivity` | SDL game screen. Runs in its **own process `:game`**, because SDL's native side cannot start twice in one process (it would `System.exit` on re-create), so quitting ends the process (`System.exit` in `onDestroy`). Back asks "Quit?" first. Handles perf_diag/runtime_env, BIOS assets and the AOT overlay install. Immersive, keeps the screen on, and hides the pad when a gamepad or real keyboard is used. |
| `PadOverlay` | Full PS1 pad: D-pad (8-way), Cross/Circle/Square/Triangle drawn as shapes, L1/L2/R1/R2, Select/Start, optional analog sticks. Multi-touch, one control per finger; sliding onto another button presses it; haptics on press. Layout in units of **screen height**, anchored left/right/centre (idea from SlickAmogus/silent-hill-decomp `pc_touch.c`); hit areas are 1.3x the drawn size. The top-centre **≡** button opens an editor: drag to move, Smaller/Bigger/Rename/Hide/Opacity/Reset, saved in SharedPreferences. |
| `PsxInput` | JNI: `nativeSetButtons(heldMask)` (raw PS1 pad bits, Select=0x1 ... Square=0x8000) and `nativeSetStick(stick, x, y)` (0x80 = centre). |
| `PsxFiles` | Asset copy, BIOS staging, overlay install (content-addressed, `.so` before `.ranges`, a stamp keyed on the APK's `lastUpdateTime`). |

Per-game values come from resources: strings `app_name`, `psx_game_title`, `psx_game_id`
(names the overlay cache folder), and bool `psx_analog_sticks`. The icon is a vector adaptive
icon (no PNG tooling needed).

Policenauts still uses its own older `PolicenautsActivity` (folder-import flow for two discs,
`TouchMouseOverlay` with a trackpad, tap-to-click, D-pad-to-mouse with key repeat, and ACT/MOVE
buttons). It has not been moved onto the shared layer yet.

## 8. Runtime changes made (tomba_recomp's psxrecomp copy)

All are general (every game), none per-game:

1. **Generic JNI touch pad:** `Java_com_psxrecomp_android_PsxInput_nativeSetButtons/nativeSetStick`
   in `runtime/src/main.cpp`. Touch sticks override player 1's stick bytes while a finger is on them.
2. **Mouse is now a game.toml option:** `[controller] mouse = true` puts the Sony Mouse in port 1.
   Before this, Android hardcoded the mouse for every game (Policenauts-only behaviour). If
   Policenauts moves onto this framework copy, **its `game.toml.in` needs `mouse = true`**.
3. **Android window opens fullscreen:** `SDL_WINDOW_FULLSCREEN_DESKTOP`. Otherwise SDL shows the
   status and navigation bars over the picture. The picture fits the full height at 4:3.
4. **Memory-card write-back:** writes used to sit in RAM until a clean shutdown, so a killed app
   lost the save. Now each card is written about 30 frames (0.5 s) after its last sector write,
   through a temp file plus rename (`memcard_flush_settled()` in `memcard.c`), so an interrupted
   write can't truncate a card. **Policenauts' framework copy does not have this yet.**

Changes from the Policenauts sessions (both copies have them): inlined `psx_cyc_step`/`psx_cyc_charge`
(the `PSX_CYC_INLINE` fast path); `-fvisibility=hidden` and `-Wl,-Bsymbolic` for Android; emulator
thread pinned to the fastest cores; an Android Performance Hint session; stdout/stderr routed to
logcat; `files/runtime_env`; the bundled AOT overlay install; and the game.toml blank-line growth fix.

## 9. Game status

### Policenauts (`com.policenauts.recomp`)

- Installed: play build `play7_fastcyc.apk` (hash ee27d7e5). Black screen before the opening movie
  holds 60 Hz; the credits movie runs at 55-56 Hz. Fallback: `play6.apk` (hash d13c83b1; its cache
  folder is still on the phone).
- **Open bug:** one of three fragment shards in slot 0x8006C000 (`0006C000_5876E522` /
  `5DD0BF24` / `636C6044`) corrupts the opening "POLICENAUTS" logo and hangs the game. Found by
  bisect (`bisect.txt` in the backup). All three are quarantined on the phone
  (`files/quarantine_6C000`), and `build.gradle` excludes the whole `0006C000_*` slot from the APK.
  Next: bisect the last three, diff the bad shard's C against the interpreter, fix the emitter.
  `PSX_OVERLAY_DIFF` is unusable here because it replays CD I/O and wedges the CD state.
- Dead end: `idle_skip = true` made scenes slower (`psx_idle_note_check` costs about 7% and found no idle loops).
- Next speed work: the cost of `check_interrupts` calls and dispatch validation.

### Tomba! (`com.psxrecomp.tomba`)

- Installed: debug build `tomba_dbg2.apk`. Disc imported through the new menu. Verified: menu
  import, boot, intro movie, village gameplay, START/Cross on the touch pad, fullscreen, a steady
  60 Hz guest rate with the emulator using about 40-50% of the frame time (debug build), and AOT
  overlays running natively.
- To do: the play build plus a simpleperf profile; a D-pad walk/jump test; a native-off A/B
  screenshot compare; a real memory-card save to prove the write-back; user feedback on the pad layout.

## 10. Porting the next game: checklist

1. Ask which game. Copy `F:\recomps\<game>` to `Documents\recomp\<game>`, **skipping
   `build-release/`** and keeping `disc/` and `saves/`. Look before copying. The USB's own
   `psxrecomp/` may be empty (Tomba's was).
2. Copy the newest framework (`tomba_recomp\psxrecomp`, which has every change above) into the
   game. Diff it against the game's own copy if the game has one.
3. Regenerate code (section 5) and diff against a baseline.
4. Copy `tomba_recomp\android` (skip `app/build`, `.cxx`, `.gradle`). Change the `namespace`,
   strings, `bools.xml` (`psx_analog_sticks` = true if the game reads sticks), `assets/game.toml.in`
   (from the game's game.toml, `discs = [@@DISC1@@]`, `[runtime] video_renderer = "software"`,
   `overlay_cache = true`, the `[controller]` mode, `[bios] path = "bios/openbios.bin"`), the overlay
   cache path in `build.gradle`, and the icon colour.
5. Copy `tomba_recomp\CMakeLists.txt`'s Android block and change the project name, title and generated file names.
6. Build the debug APK, push the disc to `/sdcard/Download/<Game>/`, import it through the menu, and boot.
7. Extract and compile overlays (section 6), rebuild, and verify native dispatch and pictures.
8. Measure with the perf report, then build the play APK and measure again.
9. Multi-disc games: the menu currently handles one disc (`@@DISC1@@`). Policenauts'
   two-disc import (`disc_serials`, `@@DISC2@@`) is the model for extending it.

## 11. Gotchas collected

- The Android file picker opens wherever it was last used, and can briefly show a stale "1 selected"
  animation frame. Its search box is the fastest way to reach files when driving it over adb.
- `adb shell am start` cannot start the non-exported `PsxGameActivity`. Start `LauncherActivity`
  and tap Play (1200, 555 in landscape). A tap during the rotation animation is lost.
- Pixels report the volume and power keys as a keyboard source. Don't treat those as "a controller is connected".
- `logcat -c` followed by `logcat -d` can still come back empty (buffer pruning). Use a live capture.
- The runtime's first perf interval shows a catch-up burst (guest 105 Hz, audio overflows). Ignore it.
- The Tomba picture is 224 lines inside a 240-line frame, so thin black bands top and bottom are faithful.
- `taskkill` on adb.exe restarts the adb server; wireless devices then need `adb connect` again.

## 12. User's wishlist (after speed is solid)

1. Better picture quality (sharp-bilinear or integer scaling; GLES renderer for higher internal resolution in 3D games).
2. Full touch control for Policenauts (tap-to-point mouse, using the cursor X/Y found in guest RAM).
3. Movable, relabelable buttons (**done in the shared PadOverlay**; Policenauts doesn't use it yet).
4. Fullscreen, not stretched (**done for Tomba**; Policenauts still pins its picture to the top ~60%).
5. Volume balance between scenes (a loudness-levelling or music/voice/SFX mix option).
