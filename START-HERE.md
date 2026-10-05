# START HERE: step by step

Do these in order. The drive letter may change (J: on the other PC); only the letter differs.

## Once per PC
1. Install, if missing: PowerShell 7 (`pwsh`), git, LM Studio. Nothing else is needed for the tasks.
2. LM Studio: load **qwen3.5-9b**, set context length to 16k or more (32k better), and start the local server
   (Developer tab, port 1234). No system prompt needed: the scripts send `AGENT.md`.
   If replies come back cut off or full of reasoning, turn off "thinking" for the model.
3. Test it: in PowerShell run `curl http://localhost:1234/v1/models`. You should see the model listed.

## Every session
4. Open PowerShell in this folder:
   ```powershell
   cd J:\recomp-backups\psx-android-tools
   git status          # should be clean; if not, commit or ask before continuing
   ```
5. Run it:
   ```powershell
   pwsh -File go.ps1               # does every unfinished task, in order
   pwsh -File go.ps1 -Status       # just lists PASS / TODO
   pwsh -File run.ps1 -Task 02     # just one task
   ```
   go.ps1 sends AGENT.md, CONTEXT.md and one task card at a time to LM Studio, saves the code the model writes,
   runs that task's check, and repeats until it passes. Then it moves to the next task.
   - `ALL TASKS PASS` means you're done; go to step 7.
   - `STUCK`, `GAVE UP` or `MODEL NEEDS INFO` means it stopped. Look at the last reply in `logs\` and the FAIL lines.
     Make the card smaller or clearer, or bring it to Claude.
6. Each passing task is committed to git automatically. Every model reply is kept in `logs\`.

## Task order (go.ps1 does these for you)
| Card | What you get |
|---|---|
| 01 | `tools\new-game.ps1` (already written; go.ps1 just confirms it passes) |
| 02 | `tools\make-game-toml-in.ps1` |
| 03 | `tools\port-game.ps1` (uses 01 and 02) |
| 04 | `tools\phone.ps1` |

## After all four pass: port a game (Tomba 2 is the easiest next one)
7. Pick a work folder outside the backups, for example `C:\recomp`:
   ```powershell
   pwsh -File tools\port-game.ps1 -Name tomba2_recomp -SourceDir ..\recomps -Framework ..\2026-10-03\tomba_recomp\psxrecomp -OutRoot C:\recomp
   ```
8. Build (needs JDK 17 and the Android SDK with NDK 28.2.13676358 and CMake 3.22.1):
   ```powershell
   cd C:\recomp\tomba2_recomp\android
   Set-Content local.properties "sdk.dir=C:/Users/<you>/AppData/Local/Android/Sdk"
   .\gradlew.bat :app:assembleDebug        # first build takes about 30 minutes
   ```
9. Phone (wireless debugging on): back up saves and install, then launch:
   ```powershell
   cd J:\recomp-backups\psx-android-tools
   pwsh -File tools\phone.ps1 -Action devices
   pwsh -File tools\phone.ps1 -Action install -Package com.psxrecomp.tomba2 -Apk C:\recomp\tomba2_recomp\android\app\build\outputs\apk\debug\app-debug.apk
   pwsh -File tools\phone.ps1 -Action launch -Package com.psxrecomp.tomba2
   ```
   On the phone: Select game file, then pick the .cue and the .bin files together, then Play.

## Bring to Claude instead
- Any change to C/C++ (`psxrecomp\runtime`, `psxrecomp\recompiler`) or Java (start menu, touch pad).
- Multi-disc support (needed for both Parasite Eve games) and pre-compiling overlays for speed.
- Graphics glitches, crashes, or the game running under 60 fps.
