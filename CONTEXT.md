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
2026-10-03\tomba_recomp\        newest WORKING game (framework, android app, overlays). Source of psxrecomp.
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
