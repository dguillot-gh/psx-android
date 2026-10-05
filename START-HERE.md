# START HERE: step by step

The drive letter may change (J: on the other PC); only the letter differs.
What this does: turns the PS1 recomp games in `..\recomps` into Android apps (APKs), copies them to the drive,
and installs them on the phone, unattended.

## 1. Before you start
- PowerShell 7 must be installed (`pwsh`). If it isn't: `winget install --id Microsoft.PowerShell -e`
- Everything else is installed automatically on the first run: git and Java 17 (via winget), and the Android SDK
  with NDK 28.2.13676358 and CMake 3.22.1 (downloaded from Google, a few GB).
- To have the games installed on the phone at the end: turn on Developer options > Wireless debugging on the phone,
  and pair it with this PC once (`adb pair <ip:port>` with the pairing code the phone shows).
  Without the phone the APKs are still built and copied to the drive.

## 2. Run it
```powershell
cd J:\recomp-backups\psx-android-tools
pwsh -File go.ps1 -Game all
```
For each game in `..\recomps` (except Tomba, already done) it:
- copies the game into `C:\recomp\<game>`, with the newest framework from `..\framework`;
- creates its Android app (own package name, title and config);
- regenerates its C code with the new recompiler (the original stays in `generated.orig`);
- builds the APK into `C:\recomp\<game>\apk\`. The first build of each game takes about 30 minutes;
- copies the APK to `..\apks\<date>\` on the drive;
- if the phone is connected: backs up the app's memory cards, installs it, and copies the game's disc
  to the phone's `Download\<game>` folder.

It skips anything already done, so rerunning is always safe (for example once the phone is connected).
It ends with a SUMMARY: one line per game and per phone step.
- One game only: `pwsh -File go.ps1 -Game tomba2_recomp`
- Somewhere other than C:\recomp: add `-WorkDir D:\recomp`
- Don't touch the phone: add `-NoPhone`. Install but don't copy discs: add `-NoDiscPush`.
- Port and regenerate only, no build: add `-SkipBuild`

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
