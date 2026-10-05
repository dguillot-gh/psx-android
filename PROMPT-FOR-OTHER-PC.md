# Prompt for the other PC

Paste the text in the box into the assistant on the other PC (one that can run commands).
No assistant? Do it yourself: follow START-HERE.md (it's one command).

```
You are on my home PC. My USB drive has a folder recomp-backups (find its drive letter, e.g. J:).
Work only inside <drive>:\recomp-backups\psx-android-tools. Read START-HERE.md and AGENT.md there first.

Your job is to OPERATE the scripts unattended, not to write code:
1. Check the setup from START-HERE.md "Once per PC": pwsh 7, git, Java 17, Android SDK with
   NDK 28.2.13676358 and CMake 3.22.1. (LM Studio is only needed if a task card fails.)
   Tell me what is missing and how to install it. Don't install anything without asking me.
2. Run: pwsh -File go.ps1 -Status, then pwsh -File go.ps1 -Game all
   It ports, regenerates and builds every remaining game into C:\recomp. Each game's first build takes
   about 30 minutes, so this can take a few hours. Let it run to the end; don't interrupt it.
3. When it finishes, show me its SUMMARY. For any FAIL, read the log it names (build-android.log or
   regen.log) and explain the problem in plain words with its last 20 lines.
4. Stop there. Only install to the phone if I ask; then use tools\phone.ps1 exactly as START-HERE.md says.

Never: write or edit .ps1 files, task cards, checks or fixtures; touch the recomps, framework or
2026-10-03 folders, disc images or memory cards (*.mcd); run adb uninstall; create .bat or .cmd files.
```
