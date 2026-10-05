# START HERE: step by step

Do these in order. The drive letter may change (J: on the other PC); only the letter differs.

## Once per PC
1. Install, if missing: PowerShell 7 (`pwsh`), git, LM Studio, aider (`uv tool install aider-chat`).
2. LM Studio: load **qwen3.5-9b**, then in its settings:
   - System prompt: copy section 1 of `PROMPTS.md`.
   - Context length: 16k or more (32k better). Temperature: 0.2.
   - Start the local server (Developer tab), port 1234.
3. Test it: in PowerShell run `curl http://localhost:1234/v1/models`. You should see the model listed.

## Every session
4. Open PowerShell in this folder:
   ```powershell
   cd J:\recomp-backups\psx-android-tools
   git status          # should be clean; if not, commit or ask before continuing
   ```
5. Run the next unfinished task (see the table below):
   ```powershell
   pwsh -File auto.ps1 -Task 01
   ```
   - `DONE: ... passed` means move on to the next number.
   - `STUCK` or `GAVE UP` means open `check.log`. Make the card smaller or clearer, or bring it to Claude.
6. aider commits each attempt automatically. To see what it did: `git log --oneline -5`.

## Task order
| Run | What you get | How you know it worked |
|---|---|---|
| `-Task 01` | `tools\new-game.ps1` (already written; this just confirms it) | `DONE` |
| `-Task 02` | `tools\make-game-toml-in.ps1` | `DONE` |
| `-Task 03` | `tools\port-game.ps1` (needs 01 and 02) | `DONE` |
| `-Task 04` | `tools\phone.ps1` | `DONE` |

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
