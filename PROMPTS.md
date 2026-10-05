# Prompts for the local model

## 1. LM Studio system prompt (set once, in the model's settings)
```
You write small PowerShell 7 scripts for a Windows project. Follow the task card exactly.
Output the complete file every time. No .bat or .cmd. Do not explain unless asked.
If information is missing, write "UNKNOWN: <what you need>" and stop instead of guessing.
Never delete or change disc images, memory cards (*.mcd), or anything outside the output folder.
A check script decides if you are done. When it prints FAIL lines, fix exactly those and nothing else.
```
Settings: context length 16k or more (32k better), temperature 0.2. Turn off "thinking" if replies get cut off.

## 2. Automatic (recommended): no prompt needed
```powershell
cd <drive>:\recomp-backups\psx-android-tools
pwsh -File auto.ps1 -Task 02
```
auto.ps1 gives the model CONTEXT.md and the card, and sends it the check's errors each round.

## 3. By hand in aider
Start it in the repo folder:
```powershell
cd <drive>:\recomp-backups\psx-android-tools
aider --model openai/qwen/qwen3.5-9b --openai-api-base http://localhost:1234/v1 --openai-api-key lm-studio --no-show-model-warnings --map-tokens 0 --edit-format whole --read CONTEXT.md --read tasks\02-game-toml-in.md --file tools\make-game-toml-in.ps1
```
First message (swap the card name, file name and check number for other tasks):
```
Do the task in tasks\02-game-toml-in.md. Write the whole of tools\make-game-toml-in.ps1.
Use only what CONTEXT.md and the task card say. When done, I will run tools\check-02.ps1.
```
Then after each attempt:
```
/run pwsh -NoProfile -File tools\check-02.ps1
```
and, if it failed, reply only:
```
Fix exactly these FAIL lines and nothing else. Send the whole file again.
```

## 4. Plain LM Studio chat (no aider)
Paste in this order: the full text of CONTEXT.md, then the full task card, then:
```
Write the complete tools\make-game-toml-in.ps1 for this task card. Output only the file in one code block.
```
Save its answer to the file yourself, run the check, and paste the FAIL lines back with
"Fix exactly these FAIL lines and nothing else. Send the whole file again."

## Rules of thumb
- One task per chat. Start a fresh chat for the next card (old turns eat the small context).
- Never paste the handbook. CONTEXT.md is the short version made for this.
- If it fails the same way three times, the card is too big or unclear: split it, or hand it to Claude.
