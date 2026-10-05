# Prompt for the other PC

Paste the text in the box into the assistant on the other PC (one that can run commands).
No assistant? Do it yourself: follow START-HERE.md (it's one command).
To watch progress yourself, open a second PowerShell window and run:  pwsh -File <drive>:\recomp-backups\psx-android-tools\watch.ps1

```
You are on my home PC. My USB drive has a folder recomp-backups (find its drive letter, e.g. J:).
Work only inside <drive>:\recomp-backups\psx-android-tools. Read START-HERE.md and AGENT.md there first.

Your job is to OPERATE the scripts unattended, not to write code:
1. If PowerShell 7 is missing, install it: winget install --id Microsoft.PowerShell -e
   Everything else (Java 17, the Android SDK, NDK and CMake) is downloaded automatically by go.ps1,
   onto the USB drive (recomp-backups\tools-cache), not onto this PC's C: drive.
2. If you can, ask me to turn on Wireless debugging on the phone first, so the games get installed at the end.
   If LM Studio has a model loaded, ask me to unload it: the build needs the PC's memory.
3. Run: pwsh -File go.ps1 -Game all
   It installs missing tools, then for every remaining game: ports it into <drive>:\recomp-backups\android-recomp,
   regenerates its code, builds the APK, copies the APK to <drive>:\recomp-backups\apks\<date>\, and, if the phone
   is connected, backs up its saves, installs the game, and copies the game's disc to the phone's Download folder.
   It continues where it left off: games and files that already finished are skipped.
   I will watch it with watch.ps1 in another window; you don't need to report progress while it runs.

What to expect while it runs:
- Each game's first build takes 30-60 minutes (longer for big games like Parasite Eve), so all five take a few hours.
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

4. When it finishes, show me its SUMMARY. For any FAIL, read the log it names (build-android.log or
   regen.log) and explain the problem in plain words with its last 20 lines.
   If the phone wasn't connected, it's safe to run the same command again once it is: finished steps are skipped.
5. Before I unplug the USB drive: make sure go.ps1 has finished or was stopped as above, then use
   "Safely remove hardware". Never let me pull the drive while a build is running.

Never: write or edit .ps1 files, task cards, checks or fixtures; touch the recomps, framework or
2026-10-03 folders, disc images or memory cards (*.mcd) yourself; run adb uninstall; create .bat or .cmd files.
```
