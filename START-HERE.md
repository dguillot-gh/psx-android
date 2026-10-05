# START HERE: step by step

The drive letter may change (J: on the other PC); only the letter differs.
What this does: turns the PS1 recomp games in `..\recomps` into Android apps (APKs), copies them to the drive,
and installs them on the phone, unattended. Everything is written to the USB drive, not the PC's C: drive.

## 1. Before you start
- PowerShell 7 must be installed (`pwsh`). If it isn't: `winget install --id Microsoft.PowerShell -e`
- Everything else is downloaded automatically on the first run, onto the drive (`..\tools-cache`):
  Java 17 (portable), the Android SDK with NDK 28.2.13676358 and CMake 3.22.1 (a few GB, from Google),
  and Python 3 (portable, 15 MB; already on the drive since 2026-10-05). Nothing needs installing on the PC.
- To have the games installed on the phone at the end: turn on Developer options > Wireless debugging on the phone,
  and pair it with this PC once (`adb pair <ip:port>` with the pairing code the phone shows).
  Without the phone the APKs are still built and copied to the drive.

## 2. Run it
Window 1 (does the work). The FAST version (what you normally want now that every game boots):
```powershell
cd J:\recomp-backups\psx-android-tools
pwsh -File go.ps1 -Game all -Speed
```
Without `-Speed` it makes the plain first builds (slower games, but with the debug server Claude uses).
Details of `-Speed` are in "Fast builds" below.
Window 2 (optional, shows progress and the live build log, refreshes every 5 s; Ctrl+C stops only the watcher):
```powershell
pwsh -File J:\recomp-backups\psx-android-tools\watch.ps1
```
Window 3 (optional, scrolling live view: which C file each clang is compiling, its CPU and RAM, then the linker
and Gradle; Ctrl+C stops only this window):
```powershell
pwsh -File J:\recomp-backups\psx-android-tools\watch-compile.ps1
```
For each game in `..\recomps` (except Tomba, already done) go.ps1:
- copies the game into `..\android-recomp\<game>`, with the newest framework from `..\framework`;
- creates its Android app (own package name, title and config);
- regenerates its C code with the new recompiler (the original stays in `generated.orig`);
- builds the APK into `..\android-recomp\<game>\apk\`. The first build of each game takes about 30 minutes;
- copies the APK to `..\apks\<date>\`;
- if the phone is connected: backs up the app's memory cards, installs it, and copies the game's disc
  to the phone's `Download\<game>` folder.

It skips anything already done, so rerunning is always safe (for example once the phone is connected).
It ends with a SUMMARY: one line per game and per phone step. Every step is also in `progress.log`.
- One game only: `pwsh -File go.ps1 -Game tomba2_recomp`
- Don't touch the phone: add `-NoPhone`. Install but don't copy discs: add `-NoDiscPush`.
- Port and regenerate only, no build: add `-SkipBuild`

### Fast builds (`-Speed`)
PS1 games load extra code from the disc while they run. Without help that code runs on a slow interpreter
(laggy cutscenes, menus). `-Speed` pre-compiles it for the phone, per game:
1. finds the code on the disc itself (seconds; works for Tomba 2 and Persona);
2. adds the code the phone recorded while you played that game (read from the phone, never changes it). For
   Persona 2 and both Parasite Eves this is the main source: **the more of a game you play, the more gets
   pre-compiled on the next run.** Play new areas, then run `-Speed` again; it only recompiles when there is new code;
3. compiles it on all CPU cores (a few minutes up to ~30 min per game; heartbeat `SPEED: still compiling ...`);
4. builds the "play" version (no debug server, about 20% faster) with that code inside, and installs it
   (saves backed up first, as always);
5. opens the game on the phone, presses Play, and for 90 s records the frame rate, 3 screenshots and the game's
   log into `..\android-recomp\<game>\phone-test\<date-time>\`. The SUMMARY shows each game's fps.
   Don't touch the phone during this step. A game whose disc was never picked in the app is skipped (pick it once).
Some pre-compiled pieces can fail to compile; those parts just stay on the interpreter (the summary says how many).
Pre-compiled code is checked before it runs, so a bad piece is skipped, not run wrong; graphics glitches that only
appear in the fast build are still possible: bring the screenshots to Claude.

### What to expect while it builds
- 30-60 minutes per game the first time (more for Parasite Eve). Unload any model in LM Studio first: the build needs the memory.
- The build log can stay silent for a long time while C code compiles. Every minute the build prints a heartbeat
  (also in progress.log and the watcher), e.g. `BUILD: still working, 12 min so far: 3 clang compiling, 410/429 files compiled`.
  As long as heartbeats keep coming, it's working. The last step says "linking" and can take several minutes.
- Generated C files are normally 1-2 MB. Empty areas of a game used to come out as one giant file (Parasite Eve: 20 MB)
  that took hours and ran the PC out of memory. Fixed in the recompiler on 2026-10-05: go.ps1 regenerates every game
  with it automatically, including games regenerated before (whenever the recompiler is newer). If progress.log shows
  `WARNING: oversized generated file`, the build still finishes (that file is compiled without optimisation); bring it to Claude.
- Close LM Studio, browsers and games while it builds. If everything stops with no FAIL line and no more heartbeats,
  the PC most likely ran out of memory: close more programs and rerun the same command; it resumes.
- To stop: Ctrl+C in the go.ps1 window, wait until no clang.exe is left in Task Manager. Rerunning resumes.
  Never unplug the drive during a build; use "Safely remove hardware" after stopping.

## 3. Play
On the phone, open the game, tap **Select game file**, open the side menu (top left) > **Pixel 8** > **Download** >
`<game>`, pick the .cue and the .bin file(s) together (long-press one, tap the others), then **Select**, then **Play**.
(The picker's "Downloads" shortcut shows these folders as empty: files copied over USB/adb are not in Android's
media index. "Pixel 8" reads the folders directly.) The app remembers the disc; next time just tap **Play**.

## A NEW game from your own disc (e.g. FF7)
1. Have the disc images (.cue + .bin for every disc; modified/patched images are fine) anywhere on the PC.
2. ONE command does everything: creates the recomp from your discs (copies them onto the drive, reads the disc,
   writes the game's config), generates its C code, pre-compiles, builds the Android app and installs it:
   ```powershell
   pwsh -File go.ps1 -Game ff7_recomp -Disc "C:\games\FF7\FF7 (Disc 1).cue","C:\games\FF7\FF7 (Disc 2).cue","C:\games\FF7\FF7 (Disc 3).cue" -Speed
   ```
   Name: lowercase, ends in `_recomp` (the app becomes `com.psxrecomp.ff7`). List the discs in order.
   From then on it is a normal game: `-Game ff7_recomp` or part of `-Game all` (no `-Disc` needed again).
   (Only the "create" part: `pwsh -File tools\new-recomp.ps1 -Name ff7_recomp -Disc ...`.)
3. A brand-new game usually needs work before it plays right (missing code entry points, crashes, graphics):
   that part is Claude's. Bring the drive after step 2 with whatever the phone shows.
Optional: copy your DuckStation memory card for the game onto the drive too (DuckStation's `memcards` folder,
a 128 KB .mcd file); the phone apps use the same format, Claude can load it onto the phone.

## Multi-disc games (since 2026-10-05)
- Put every disc's .cue and .bin files in the game's disc folder: `..\android-recomp\<game>\disc\` (and in
  `..\recomps\<game>\disc\` for new ports). go.ps1 copies them all to the phone's `Download\<game>`.
- On the phone: Select game file > select ALL the discs' .cue and .bin files together. The menu shows "N discs";
  the game starts on Disc 1.
- When the game asks for the next disc: tap the pad's menu button (top centre) > **Change disc** > pick the disc.
  The game sees the PS1's lid open and close, exactly like swapping discs on a real console.
- Saves are on the memory card, shared by all discs; save states are kept per disc.

## Notes per game
- Tomba 2: the disc has two track files; select the .cue and both .bins together.
- Parasite Eve 1 and 2: only Disc 1 is on the drive so far. Add Disc 2 (see Multi-disc games above) to play past
  the disc change; the home PC has them under G:\ps1 ports\games to recomp\.
- Package names: `com.psxrecomp.` + the folder name without `_recomp` and underscores
  (tomba2, persona, persona2, parasiteeve, parasiteeve2). Single phone steps: see `tools\phone.ps1`'s first lines.

## Bring to Claude
- A FAIL in the summary that its log doesn't explain.
- Games still slow after `-Speed`, graphics glitches, crashes, controls (the `phone-test` folders help).
- Known open items (2026-10-05): Parasite Eve II has no sound; analog sticks (an ANALOG button on the pad);
  multi-disc support is written but not yet tested with a real disc change; any change to C/C++ or Java code.

## Writing new tools with the local model (optional)
Task cards in `tasks\` describe tools for the local model to write. If any card's check fails, `go.ps1` runs it first
(via `run.ps1` and LM Studio with qwen3.5-9b on port 1234). All current cards already pass. See README.md.
