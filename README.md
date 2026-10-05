# psx-android-tools: running the local model (Qwen 3.5 9B)

Small PowerShell tools that set up PS1 recomp games for Android, written by a local model one task at a time.

## How it works
- `tasks\NN-*.md`: one task card = one script to write. Short, exact, with a "DONE WHEN" line.
- `tools\check-NN.ps1`: the judge. It runs the model's script on fake test data in `tests\fixtures` and prints
  `FAIL: <reason>` lines or `OK`. The check is the real spec; the card explains it in words.
- `auto.ps1 -Task NN`: loops aider + LM Studio until the check prints OK. It stops early with `STUCK` if the same
  failure repeats 3 times (make the card smaller or clearer, then rerun).
- `CONTEXT.md`: the only background the model reads (about 1k words). The full handbook is for humans.

## Run a task
```powershell
cd J:\recomp-backups\psx-android-tools      # whatever letter the drive has
pwsh -File auto.ps1 -Task 02
```
aider commits each attempt to git, so `git log` shows what it did and `git checkout <commit> -- tools\x.ps1` undoes it.

## Task queue
| # | Tool | What it does | Status |
|---|---|---|---|
| 01 | `new-game.ps1` | Android app from the template (package id, strings, sticks) | written; run `pwsh -File tools\check-01.ps1` to confirm |
| 02 | `make-game-toml-in.ps1` | Android `game.toml.in` from a game's `game.toml` (1 or more discs) | ready to run |
| 03 | `port-game.ps1` | Full setup of one game: copy game + framework, run 01 and 02, write CMakeLists | ready (needs 01 + 02) |
| 04 | `phone.ps1` | adb: devices, backup saves, install (always backs up first), launch | ready |

After 03 passes, a real port is one line, e.g. Tomba 2:
```powershell
pwsh -File tools\port-game.ps1 -Name tomba2_recomp -SourceDir ..\recomps -Framework ..\2026-10-03\tomba_recomp\psxrecomp -OutRoot <work folder>
```
Then build with Gradle (see CONTEXT.md). The first full native build takes about 30 minutes.

## Tips for a 9B model
- **Keep each card to one script and under about 15 instruction lines.** If it gets stuck, split the card (for example,
  "copy only" first, then "rename"), and add a check line for the part it keeps missing.
- **Write the check first**, using fake fixtures (tiny files, never real discs or saves). The model can only aim at what the check tests.
- **Give it the answer's shape:** example input to output (like `tests\fixtures\tomba\expected.game.toml.in`) beats prose.
- **LM Studio:** context length 16k or more (32k is better), temperature 0.2. If replies get cut off or ramble,
  turn off "thinking" for the model. Keep `--map-tokens 0` and `--edit-format whole` (already in auto.ps1).
- **Only `--read` CONTEXT.md and the card.** Adding the handbook or many files crowds out its working space.
- **Save a bigger model (Claude) for:** C/C++ runtime or recompiler changes, overlay miscompile bugs, Java/Android UI work
  (for example multi-disc support in the start menu, needed by both Parasite Eve games), and performance profiling.
- **Never let it run anything against the phone without `-DryRun` first.** Saves are backed up by `phone.ps1 install`.

## Known gaps for the next games
- Parasite Eve 1 and 2 list a Disc 2 in game.toml, but only Disc 1 images are on the drive. Dump Disc 2 first.
- The shared start menu (Java, in `psxrecomp\runtime\android`) fills only `@@DISC1@@` today. Multi-disc games need
  it extended (a Claude task).
- AOT overlays per game: `psxrecomp\tools\aot_overlay_spike\extract_generic.py` then the parallel compile
  (handbook section 6). Worth a task card once porting works.
