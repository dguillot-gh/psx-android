# AGENT.md: instructions for the AI model working in this folder

You are working in `psx-android-tools`, a folder of small PowerShell 7 tools that set up PS1 games as Android apps.
Read `CONTEXT.md` first (rules, folder layout, game facts). Then follow these steps exactly.

## Steps
1. Find the next job: run `pwsh -File go.ps1 -Status`.
   It prints PASS or TODO for each card in `tasks\`. The first TODO is your job. If all PASS, go to step 6.
2. Open that card (`tasks\NN-*.md`). It names ONE file to write (`Task: write tools\X.ps1`)
   and ONE check (`DONE WHEN tools\check-NN.ps1 exits 0`).
3. Write the whole file `tools\X.ps1` exactly as the card says. Nothing else: do not edit cards, checks,
   templates, fixtures, CONTEXT.md, or this file.
4. Run the check: `pwsh -NoProfile -File tools\check-NN.ps1`.
   - `OK` means the card is done. Go back to step 1.
   - `FAIL: ...` lines mean fix exactly those problems in `tools\X.ps1`, then run the check again.
5. If the same FAIL line comes back 3 times, stop. Report the card name and the FAIL line, and say
   "STUCK: needs a smaller card or a bigger model". Do not try workarounds.
6. When every card passes, say "ALL TASKS PASS" and stop. Do not start porting games or using the phone on your own.

## Never
- Delete or change disc images, memory cards (`*.mcd`), the `recomps` or `2026-10-03` folders, or anything on the phone.
- Write `.bat` or `.cmd` files, or run `adb uninstall`.
- Edit C/C++, Java, or `generated\` code. That is for a bigger model.
- Guess. If the card leaves something out, write `UNKNOWN: <what you need>` and stop.
