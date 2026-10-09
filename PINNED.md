# Pinned list (short version)

The one list of what's next. Details and history: CONTEXT.md (PINNED LIST section). Updated 2026-10-09.

## Next up
1. **Move to the personal laptop.** Right-click `COPY TO THIS PC.ps1` at the top of the drive > Run with PowerShell.
   Then PSX Manager > Tick all > **Overnight speed** > next day **Put on phone**. Every game needs this one rebuild
   to get the 2026-10-08/09 fixes (recompiler fix, controller, 16:9 stretch, crash reports, icons).
   Old save states won't load after it; memory-card saves carry over.
2. **Audio dies after another app interrupts** (all games). Reproduce with Report a problem, reopen the audio on resume.
3. **Roll back button** in PSX Manager (reinstall the previous APK; builds keep the newest 2).
4. **First play-tests:** GT2 Simulation (disc not on the phone yet), Legend of Dragoon, Racing Lagoon, Crash 2/3,
   LEGO Island 2, Gex 1-3.

## Known game issues
- Policenauts opening ~30 fps. Parasite Eve 2: no sound. Persona 2 / Tomba 2 cutscene lag (re-check).
- Mizzurna Falls needs Sony's BIOS (android-bios.txt = SCPH1001.BIN, done): the APK contains the BIOS, so don't share it.

## Later / ideas
- Save states that survive a rebuild.
- Real widescreen (FF7 battles + world map, Tomba 2). The 16:9 stretch is enough for now.
- Menu: analog on/off; keep video settings across a disc re-pick; built-in mods (fast loading, CD speed, PGXP).
- GPU speed work (Tomba 2 at 4x, threaded renderer).
- Shareable APK with no game code (build on the phone), GitHub Actions + Obtainium.
- **PS2 in PSX Manager** (2026-10-09 research): PS2Recomp (ran-j) has its own Android runner that builds with
  the same SDK/NDK/JDK we have. Adding a PS2 tab + Android builds to PSX Manager is small/medium work, BUT
  no PS2 game runs yet: Shadow of the Colossus (D:\ps2-recomp) has never built (last try 2026-10-08 on the
  other laptop: "build tools (ps2_recomp, ps2_analyzer)" failed). First get SotC (or an easier PS2 game)
  building and booting on PC; only then add PS2 to PSX Manager.

## Moving off a PC
A private checklist for clearing the project off a PC lives on the drive only, not on GitHub: LEAVING-WORK-LAPTOP.md at the top of the drive.
