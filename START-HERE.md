# START HERE: step by step

The drive letter may change (J: on the other PC); only the letter differs.
What this does: turns the PS1 recomp games in `..\recomps` into Android apps (APKs) for the phone, unattended.

## Once per PC
1. Install, if missing:
   - PowerShell 7 (`pwsh`) and git.
   - Java 17: `winget install Microsoft.OpenJDK.17` (Android Studio's built-in Java also works).
   - Android Studio. Open it once so it installs the Android SDK. Then go to Settings > Languages & Frameworks >
     Android SDK > SDK Tools, tick "Show Package Details", and install **NDK 28.2.13676358** and **CMake 3.22.1**.
   - Only for writing new tools with the local model: LM Studio with **qwen3.5-9b** loaded, context 16k or more,
     local server on port 1234 (Developer tab). Not needed for porting or building.
2. Check: `pwsh -File go.ps1 -Status` should list PASS for every task card.

## Port and build every game (the main job)
3. Open PowerShell in this folder and run:
   ```powershell
   cd J:\recomp-backups\psx-android-tools
   pwsh -File go.ps1 -Game all
   ```
   For each game in `..\recomps` (except Tomba, already done) it:
   - copies the game into `C:\recomp\<game>`, with the newest framework from `..\framework`;
   - creates its Android app (own package name, title and config);
   - regenerates its C code with the new recompiler (the original stays in `generated.orig`);
   - builds the APK into `C:\recomp\<game>\apk\`. The first build of each game takes about 30 minutes.

   It skips anything already done, so rerunning is always safe. It ends with a SUMMARY: one line per game.
   - One game only: `pwsh -File go.ps1 -Game tomba2_recomp`
   - Somewhere other than C:\recomp: add `-WorkDir D:\recomp`
   - Port and regenerate without building: add `-SkipBuild`

## Put a game on the phone
4. Turn on wireless debugging on the phone (pair it once with `adb pair`), then:
   ```powershell
   pwsh -File tools\phone.ps1 -Action devices
   pwsh -File tools\phone.ps1 -Action install -Package com.psxrecomp.tomba2 -Apk C:\recomp\tomba2_recomp\apk\<newest>.apk
   pwsh -File tools\phone.ps1 -Action launch -Package com.psxrecomp.tomba2
   ```
   install always backs up the app's memory cards first (into `saves-backup\`). On the phone: tap Select game file,
   pick the .cue and the .bin files together, then tap Play.
   Package names: `com.psxrecomp.` + the folder name without `_recomp` and underscores
   (tomba2, persona, persona2, parasiteeve, parasiteeve2).

## Notes per game
- Tomba 2: the disc has two track files; select the .cue and both .bins together.
- Parasite Eve 1 and 2: only Disc 1 is on the drive, so only Disc 1 plays for now (the menu takes one disc).

## Bring to Claude
- A FAIL in the summary that its log doesn't explain.
- After the first boot on the phone: speed (pre-compiling the game's code), graphics glitches, crashes, controls.
- Multi-disc support (Parasite Eve), and any change to C/C++ or Java code.

## Writing new tools with the local model (optional)
Task cards in `tasks\` describe tools for the local model to write. If any card's check fails, `go.ps1` runs it first
(via `run.ps1` and LM Studio). All current cards already pass. See README.md to add new ones.
