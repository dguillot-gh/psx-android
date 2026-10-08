# easy: the PS1-on-Android jobs, without an AI

**Start here:** right-click **`MENU.ps1`** > **Run with PowerShell**. Pick a number. Every job explains itself
and asks before doing anything big. (Each menu entry is also its own script in this folder.)

The phone: plug it in with USB, unlock it, and tap **Allow** on the "USB debugging" prompt.
Watch a long build live from a second window: `pwsh -File ..\watch.ps1`.

## The menu

| # | Job | When |
|---|---|---|
| 1 | **Status** | What's built, what's on the phone, last test fps, free space. Changes nothing. |
| 2 | **Build or update games** | After an engine update, or to rebuild a game. One game at a time; asks the speed time limit. |
| 3 | **Add a new game** | You have a new disc (`.cue` + `.bin`). Pick the `.cue` file(s), give a short name. |
| 4 | **Put games on the phone** | Backs up saves, installs, copies the disc only if the app doesn't have it, quick test. |
| 5 | **Overnight speed** | Lets every game's speed pre-compile finish (up to 4 h each). Smoother games. No phone needed. |
| 6 | **Back up saves** | Copies every game's memory cards from the phone to `saves-backup\`. |
| 7 | **Phone storage** | Shows space; offers to delete only spare disc copies in `Download` (you type YES). |
| 8 | **Test a game** | Opens it, presses Play, records fps, screenshots, log. |
| 9 | **Save to GitHub** | Uploads every game's setup, the scripts and the engine to your private repositories. |
| 10 | **Update the engine** | Gets the newest psxrecomp, tests it on Einhänder first, switches only if you say yes. |

## Good habits
- **Saves are safe:** every install backs them up first (`saves-backup\<app>\<time>\`). Save **states** (the
  menu's quick saves) don't carry over to a rebuilt game; memory-card saves always do.
- **One job at a time.** Two builds at once crashed PowerShell; the scripts never do that.
- **A job stopped halfway is fine:** run it again and it continues where it left off.
- After **10 (engine update)** every game needs **5 (overnight)** then **4 (phone)**.
- Never share the APKs (they contain the games' code). Share the GitHub repositories instead.

## When something fails
- The job prints a **log file** path. The last 30 lines usually say why.
- "No phone found": cable, unlock, Allow the prompt; Settings > Developer options > USB debugging on.
- A build that failed on "Couldn't resolve host" / "download failed" was an internet drop: run it again.
- "this disc is X, but the game is set up for Y": another region/version of the game.

## Needs a programmer (scripts can't do these)
For whoever picks this up next (a person, or an AI model). Background for each is in `..\CONTEXT.md` (search
the words in bold) and the deep reference is `..\PS1-RECOMP-ANDROID-HANDBOOK.md`.

| Problem | Where to start |
|---|---|
| **New game doesn't boot / crashes** | `android-recomp\<game>\phone-test\...\logcat.txt`; missing code entry points go in the game's `seeds\ghidra_funcs.txt`, then rebuild. |
| **GT2 / Legend of Dragoon: ~5 GB of code** | Recompiler treats data in the boot program as code (CONTEXT: **data-as-code**). Needs code/data boundaries for those games. |
| **Parasite Eve 2 has no sound** | Runtime SPU/CD-XA audio path on Android. |
| **Sound dies after another app interrupts** | Android pause/resume of the SDL audio device (`runtime\src\main.cpp`, `PsxGameActivity.java`). |
| **Policenauts opening ~30 fps** | Profile with `files/runtime_env` `PSX_RUNTIME_PERF_DIAG=1`; which code runs interpreted. |
| **16:9, Analog on/off, keep display settings, built-in mods in the menu** | Menu is `runtime\android\java\com\psxrecomp\android\PsxMenu.java` in the engine. |
| **GPU renderer speed** | `runtime\src\gpu_gl_renderer.c` (CONTEXT: **GPU step 2b**, dual-source blending, threaded renderer). |
| **Engine update with conflicts** (option 10 stopped) | Merge `upstream/master` into branch `android` by hand; CONTEXT **2026-10-07 (Surface)** lists what our changes are and how the last merge was done. |
| **Shareable APK** (no game code inside, builds from the user's disc) | CONTEXT **PINNED LIST** item 18. |
