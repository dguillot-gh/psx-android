# Prompts

You don't need to type any prompt. `go.ps1` (and `run.ps1` for one task) sends the model everything:
the rules in `AGENT.md` (below its --- line), `CONTEXT.md`, one task card, the current file and the last check output.

- To change how the model behaves, edit `AGENT.md`.
- To give it more facts, edit `CONTEXT.md` (keep it short).

## By hand in the LM Studio chat window (only if the scripts can't be used)
1. Paste the text of AGENT.md below the --- line as the system prompt.
2. In the chat, paste CONTEXT.md, then the task card, then: "Write the complete tools\<file>.ps1 now."
3. Save the code block to that file and run `pwsh -NoProfile -File tools\check-NN.ps1`.
4. Paste the FAIL lines back with: "Fix exactly these FAIL lines and nothing else. Send the whole file again."

One task per chat; start a fresh chat for the next card (old turns eat the small context).
