# Prompt for the other PC

Only for an assistant that can run commands (for example Claude Code). Copy everything in the box and paste it.
If the other PC only has Qwen in LM Studio, there's no prompt: open PowerShell in this folder and run `pwsh -File go.ps1`.

```
You are on my home PC. My USB drive has a folder recomp-backups (find its drive letter, e.g. J:).
Work only inside <drive>:\recomp-backups\psx-android-tools. Read START-HERE.md and AGENT.md there first.

Goal: get every task card to pass using the local model in LM Studio (qwen3.5-9b, server on port 1234).
1. Check setup: pwsh 7, git and LM Studio's server are working (curl http://localhost:1234/v1/models). Tell me if anything is missing.
2. Run: pwsh -File go.ps1 -Status, then pwsh -File go.ps1.
3. If it stops with STUCK, GAVE UP or MODEL NEEDS INFO, read the newest file in logs\ and the FAIL lines,
   explain the problem to me in plain words, and suggest how to make that task card smaller or clearer.
   Don't write the tool yourself, and don't edit the check scripts or test fixtures.
4. When it says ALL TASKS PASS, tell me, then stop.

Never touch the recomps or 2026-10-03 folders, disc images, memory cards (*.mcd), or the phone.
No .bat or .cmd files.
```
