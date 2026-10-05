# START HERE: step by step

The drive letter may change (J: on the other PC); only the letter differs.
What this does: turns the PS1 recomp games in `..\recomps` into Android apps (APKs), copies them to the drive,
and installs them on the phone, unattended. Everything is written to the USB drive, not the PC's C: drive.

## 1. Before you start
- PowerShell 7 must be installed (`pwsh`). If it isn't: `winget install --id Microsoft.PowerShell -e`
- Everything else is downloaded automatically on the first run, onto the drive (`..\tools-cache`):
  Java 17 (portable), and the Android SDK with NDK 28.2.13676358 and CMake 3.22.1 (a few GB, from Google).
- To have the games installed on the phone at the end: turn on Developer options > Wireless debugging on the phone,
  and pair it with this PC once (`adb pair <ip:port>` with the pairing code the phone shows).
  Without the phone the APKs are still built and copied to the drive.

## 2. Run it
Window 1 (does the work):
```powershell
cd J:\recomp-backups\psx-android-tools
pwsh -File go.ps1 -Game all
```
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
On the phone, open the game, tap **Select game file**, go to `Download\<game>`, pick the .cue and the .bin
file(s) together (long-press one, tap the others), then tap **Play**.

## Notes per game
- Tomba 2: the disc has two track files; select the .cue and both .bins together.
- Parasite Eve 1 and 2: only Disc 1 is on the drive, so only Disc 1 plays for now (the menu takes one disc).
- Package names: `com.psxrecomp.` + the folder name without `_recomp` and underscores
  (tomba2, persona, persona2, parasiteeve, parasiteeve2). Single phone steps: see `tools\phone.ps1`'s first lines.

## Bring to Claude
- A FAIL in the summary that its log doesn't explain.
- After the first boot on the phone: speed (pre-compiling the game's code), graphics glitches, crashes, controls.
- Multi-disc support (Parasite Eve), and any change to C/C++ or Java code.

## Writing new tools with the local model (optional)
Task cards in `tasks\` describe tools for the local model to write. If any card's check fails, `go.ps1` runs it first
(via `run.ps1` and LM Studio with qwen3.5-9b on port 1234). All current cards already pass. See README.md.
