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
3. Run: pwsh -File go.ps1 -Game all
   It installs missing tools, then for every remaining game: ports it into <drive>:\recomp-backups\android-recomp,
   regenerates its code, builds the APK, copies the APK to <drive>:\recomp-backups\apks\<date>\, and, if the phone
   is connected, backs up its saves, installs the game, and copies the game's disc to the phone's Download folder.
   Each game's first build takes about 30 minutes, so this can take a few hours. Let it run to the end.
   I will watch it with watch.ps1 in another window; you don't need to report progress while it runs.
4. When it finishes, show me its SUMMARY. For any FAIL, read the log it names (build-android.log or
   regen.log) and explain the problem in plain words with its last 20 lines.
   If the phone wasn't connected, it's safe to run the same command again once it is: finished steps are skipped.

Never: write or edit .ps1 files, task cards, checks or fixtures; touch the recomps, framework or
2026-10-03 folders, disc images or memory cards (*.mcd) yourself; run adb uninstall; create .bat or .cmd files.
```
