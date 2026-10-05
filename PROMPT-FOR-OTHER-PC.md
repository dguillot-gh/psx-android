# Prompt for the other PC

Paste the text in the box into the assistant on the other PC (one that can run commands).
No assistant? Do it yourself: follow START-HERE.md (it's one command).
To watch progress yourself, open a second PowerShell window and run:  pwsh -File <drive>:\recomp-backups\psx-android-tools\watch.ps1
Live compiler view (which file each clang compiles, CPU/RAM, then linker/Gradle), in a third window:
  pwsh -File <drive>:\recomp-backups\psx-android-tools\watch-compile.ps1

```
You are on my home PC. My USB drive has a folder recomp-backups (find its drive letter, e.g. J:).
Work only inside <drive>:\recomp-backups\psx-android-tools. Read START-HERE.md and AGENT.md there first.

Your job is to OPERATE the scripts unattended, not to write code:
1. If PowerShell 7 is missing, install it: winget install --id Microsoft.PowerShell -e
   Everything else (Java 17, the Android SDK, NDK, CMake and Python 3) is downloaded automatically by go.ps1,
   onto the USB drive (recomp-backups\tools-cache), not onto this PC's C: drive. This PC has no Python and
   doesn't need one: the scripts use the portable copy on the drive. Never install Python on the PC.
2. Ask me to turn on Wireless debugging on the phone first: the fast builds read what the phone recorded
   and test each game on it at the end. If LM Studio has a model loaded, ask me to unload it: the build needs the memory.
3. Run: pwsh -File go.ps1 -Game all -Speed
   (the FAST builds; START-HERE.md "Fast builds" explains each step). For every game it: updates the game's
   framework copy and regenerates its code when needed; pre-compiles the code the game loads from the disc while
   it runs (found on the disc, plus what the phone recorded while I played), using all CPU cores; builds the fast
   "play" version; copies the APK to <drive>:\recomp-backups\apks\<date>\. Then, on the phone: backs up saves,
   installs each game, copies its disc, and test-runs it for 90 s (fps, screenshots, log in
   android-recomp\<game>\phone-test\). Tell me not to use the phone during the test runs at the end.
   It continues where it left off; it only recompiles when there is new code.
   I will watch it with watch.ps1 (and watch-compile.ps1) in other windows; you don't need to report progress while it runs.

What to expect while it runs:
- Per game: pre-compiling takes a few minutes up to ~30 min (heartbeat "SPEED: still compiling, N min so far: x of y
  groups finished, z pieces compiled"), then the play build 10-30 min (heartbeat "BUILD: still working ..."). All
  five games take a few hours. "SPEED: nothing found yet" or "already pre-compiled" is normal, not an error.
  Pieces reported as failed only stay slower; the build continues. Never try to fix them: they are Claude's job.
- The build log (build-android.log) can stay silent for a long time while the C code compiles. That is normal.
- Every minute the build prints a heartbeat line, also in progress.log:
    BUILD: still working, 12 min so far: 3 clang compiling, 410/429 files compiled
  As long as heartbeats keep coming, it is working. Do not stop it.
- At the end of a build the heartbeat says "all N files compiled, linking": that last step can take several minutes.
- Generated C files are normally 1-2 MB each. Empty areas of a game used to come out as one giant file (up to 20 MB)
  that took hours and ran the PC out of memory; the recompiler was fixed on 2026-10-05 and go.ps1 regenerates every
  game with it automatically (also games regenerated before, whenever the recompiler is newer).
  If progress.log ever shows "WARNING: oversized generated file", the build still continues (that file is compiled
  without optimisation so it finishes). Don't try to fix it: tell me, and keep the line for Claude.
- Memory: a build can use most of the PC's RAM. Close LM Studio, browsers and games while it runs. If the build
  dies with no error and nothing more is written (no heartbeat, no FAIL line), the PC most likely ran out of memory:
  close more programs and run the same command again; it resumes where it stopped.
- Only if there has been NO heartbeat for 15 minutes, or every heartbeat for 30+ minutes shows the same
  "x/y files compiled" with no clang compiling: tell me. To stop safely, press Ctrl+C in the go.ps1 window and wait
  until no clang.exe is left in Task Manager. Running the same command again resumes.

4. When it finishes, show me its SUMMARY, including each game's "test" line (its fps). For any FAIL, read the log
   it names (build-android.log, regen.log, or the logs in build-android-overlays\par\) and explain the problem in
   plain words with its last 20 lines. "test: not run, pick the disc once" means I must select that game's disc in
   the app once (Select game file > side menu > Pixel 8 > Download > <game>); then run the same command again.
   If the phone wasn't connected, it's safe to run the same command again once it is: finished steps are skipped.
5. Before I unplug the USB drive: make sure go.ps1 has finished or was stopped as above, then use
   "Safely remove hardware". Never let me pull the drive while a build is running.

A NEW game (only when I ask, e.g. "add FF7"): ask me for the path of every disc's .cue, then run
   pwsh -File tools\new-recomp.ps1 -Name <short>_recomp -Disc "<disc 1 .cue>","<disc 2 .cue>",...
and then pwsh -File go.ps1 -Game <short>_recomp -Speed. Show me its output. (START-HERE.md "A NEW game".)

Never: write or edit .ps1 files, task cards, checks or fixtures; touch the recomps, framework or
2026-10-03 folders, disc images or memory cards (*.mcd) yourself (the scripts may); run adb uninstall;
create .bat or .cmd files; install Python or anything else on this PC.
```
