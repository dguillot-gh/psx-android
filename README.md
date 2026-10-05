# psx-android-tools: running the local model (Qwen 3.5 9B in LM Studio)

Small PowerShell tools that set up PS1 recomp games for Android, written by a local model one task at a time.
No aider or other tools needed: just PowerShell 7, git and LM Studio.

## Quick start
- `pwsh -File go.ps1 -Game all`: ports, regenerates and builds every remaining game into `..\android-recomp` on the drive, unattended.
  Watch it from a second window with `pwsh -File watch.ps1`.
- Step-by-step walkthrough: `START-HERE.md`. Prompt for an assistant on another PC: `PROMPT-FOR-OTHER-PC.md`.
- Hand-written tools (not model tasks): `tools\build.ps1` (Gradle build, finds Java and the SDK) and the per-game
  steps in `go.ps1`. The model-task tools 02-04 were filled in with tested versions so the pipeline runs today.

## How it works
- `tasks\NN-*.md`: one task card = one script to write. Short, exact, with a "DONE WHEN" line.
- `tools\check-NN.ps1`: the judge. It runs the model's script on fake test data in `tests\fixtures` and prints
  `FAIL: <reason>` lines or `OK`. The check is the real spec; the card explains it in words.
- `run.ps1 -Task NN`: sends AGENT.md + CONTEXT.md + the card + the current file + the last check output to LM Studio,
  saves the code block it replies with, runs the check, and repeats until OK. Stops with `STUCK` if the same failure
  repeats 3 times. `go.ps1` runs it for every unfinished card in order.
- `AGENT.md`: the rules sent to the model. Edit it to change how the model behaves.
- `CONTEXT.md`: the background the model gets (about 1k words). The full handbook is for humans.
- `logs\`: every model reply, one file per attempt. Each passing task is committed to git.

## Task queue
| # | Tool | What it does |
|---|---|---|
| 01 | `new-game.ps1` | Android app from the template (package id, strings, sticks). Already written; go.ps1 confirms it. |
| 02 | `make-game-toml-in.ps1` | Android `game.toml.in` from a game's `game.toml` (1 or more discs) |
| 03 | `port-game.ps1` | Full setup of one game: copy game + framework, run 01 and 02, write CMakeLists |
| 04 | `phone.ps1` | adb: devices, backup saves, install (always backs up first), launch |

After 03 passes, a real port is one line (see START-HERE.md step 7), then a Gradle build (first one about 30 minutes).

## Tips for a 9B model
- **Keep each card to one script and under about 15 instruction lines.** If it gets stuck, split the card (for example,
  "copy only" first, then "rename"), and add a check line for the part it keeps missing.
- **Write the check first**, using fake fixtures (tiny files, never real discs or saves). The model can only aim at what the check tests.
- **Give it the answer's shape:** example input to output (like `tests\fixtures\tomba\expected.game.toml.in`) beats prose.
- **LM Studio:** context length 16k or more (32k is better). run.ps1 sets temperature 0.2. If replies get cut off
  or ramble, turn off "thinking" for the model, or raise `-MaxTokens`.
- **Keep CONTEXT.md short.** Each attempt sends it plus the card and the file; the handbook would crowd that out.
- **Save a bigger model (Claude) for:** C/C++ runtime or recompiler changes, overlay miscompile bugs, Java/Android UI work
  (for example multi-disc support in the start menu, needed by both Parasite Eve games), and performance profiling.
- **Never run anything against the phone without `-DryRun` first.** Saves are backed up by `phone.ps1 install`.

## Known gaps for the next games
- Parasite Eve 1 and 2 list a Disc 2 in game.toml, but only Disc 1 images are on the drive. Dump Disc 2 first.
- The shared start menu (Java, in `psxrecomp\runtime\android`) fills only `@@DISC1@@` today. Multi-disc games need
  it extended (a Claude task).
- AOT overlays per game: `psxrecomp\tools\aot_overlay_spike\extract_generic.py` then the parallel compile
  (handbook section 6). Worth a task card once porting works.
