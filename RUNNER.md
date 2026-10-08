# The build PC: GitHub's "Build APK" button

GitHub's own machines have no discs, so they can't build the games. Instead, a PC at home (here: the
Windows VM on the Proxmox box) runs **GitHub's runner**: it waits for the button, builds the APK with
the scripts in this repository, signs it with the shared key, and puts it in a Release of the **private** repository
**psx-android-builds**. The discs stay on the NAS and the VM; nothing from them goes to GitHub. The VM only needs
to be on while a build runs (a job waits up to 24 hours for it).

Set up 2026-10-08. Files: `.github/workflows/build-apk.yml` and `add-game.yml` in psx-android-builds (the buttons), `tools/ci-build.ps1` and `tools/add-game.ps1` (what a
build does), `tools/setup-runner.ps1` (one-time setup). The signing key is the repository secret
`PSX_KEYSTORE_B64` (the drive's `tools-cache\debug.keystore`, base64).

## What goes where (the USB drive is retired after this)

The NAS gets only what matters (about 25 GB), not the whole 175 GB drive. The NAS folder is
`\\192.168.0.194\windowsmedia\Android Recomp` (`Z:\Android Recomp` on our PCs). It is built into
the scripts; for another folder add `-Nas "<\\server\share\folder>"` (in quotes).
The VM and the build service need this `\\192.168.0.194\...` form: a mapped letter like `Z:` is invisible
to "Run as administrator" windows and to the service.

```
NAS  ("\\192.168.0.194\windowsmedia\Android Recomp")
├── keys\debug.keystore         the signing key (keep one more copy off the NAS)
├── saves\                      memory cards and app-data backups (saves-backup, each game's saves and
│                               memcard-import, 2026-10-03\phone-backup, 2026-10-03's loose files incl. keys.txt)
├── psx-discs\                  what the VM builds from (about 13 GB)
│   ├── gex_recomp\             Gex (USA) (Rev 1).cue + .bin + the files read from the disc
│   ├── ff7_recomp\             3 discs
│   └── ... one folder per game (recomps-later games too)
└── build-kit\                  what the VM copies (about 7 GB)
    ├── tools-cache\            Java, Android SDK/NDK, Python, PowerShell, GitHub CLI
    ├── framework\psxrecomp\    the engine
    ├── psx-android-tools\      the scripts
    └── recomps\<game>\         each game's setup, without disc and saves

VM  (C:\psx\recomp-backups: about 7 GB, plus one game's build at a time)
├── tools-cache\, framework\psxrecomp\, psx-android-tools\, recomps\    (copied from build-kit)
├── actions-runner\             GitHub's runner (made by setup-runner.ps1)
└── android-recomp\<game>\      build folder, 1-7 GB, deleted after each build ("Free disk space")

GitHub  (already there, nothing to copy)
├── psx-android                 scripts and guides (public)
├── psxrecomp-android           the engine (public)
├── <game>-android              each game's setup (public)
└── psx-android-builds          PRIVATE: the "Build APK" button, the runner, Releases (the APKs)
```

**Not copied** (they stay on the USB drive; rebuildable or duplicates): `android-recomp*` (build folders, 55 GB),
`apks\` (old builds; new ones are GitHub Releases), `to-do\` (the same disc rips as psx-discs), 2026-10-03's
old project snapshots and scratch, `reference\` (on GitHub), `git repos\`, `llm work\`.

GitHub's secret has the signing key too, but a secret can't be downloaded back: if every other copy of
`debug.keystore` is lost, the phone refuses updates to the installed games.

## One-time setup
Two scripts do the copying; you run one command on each machine. Keep the USB drive until a test build
on the VM worked.

### 1. On the PC with the USB drive: copy to the NAS
Check you can open the NAS folder in File Explorer. Then in PowerShell (replace `E:` with the drive's letter):

```powershell
E:\recomp-backups\tools-cache\pwsh\pwsh.exe -File E:\recomp-backups\psx-android-tools\tools\move-to-nas.ps1
```

About 25 GB, so well under an hour. It only adds files, never deletes any; if it stops, run it again and it
continues. It ends with "Done: key, saves, N games' discs and the build kit are on the NAS." A folder
`recomp-backups-archive` from the earlier, unfinished full copy is not used any more: delete it yourself
when you like.

### 2. On the VM: save the NAS password
In PowerShell, as your normal Windows user:

```powershell
cmdkey /add:192.168.0.194 /user:<your nas user> /pass
```

It asks for the password. Check: `dir "\\192.168.0.194\windowsmedia\Android Recomp\psx-discs"` lists the game folders.

### 3. On the VM: copy and set up
Open PowerShell with **Run as administrator** (needed once, to add the background service), then:

```powershell
& "\\192.168.0.194\windowsmedia\Android Recomp\build-kit\tools-cache\pwsh\pwsh.exe" -ExecutionPolicy Bypass -File "\\192.168.0.194\windowsmedia\Android Recomp\build-kit\psx-android-tools\tools\setup-vm.ps1"
```

(`-ExecutionPolicy Bypass` only lets this one run start a script from the network share.) It copies the
build kit to `C:\psx\recomp-backups` (about 7 GB; add `-To D:\psx\recomp-backups` for another disk),
then sets up the runner. It asks you twice: a **GitHub code** (type it at github.com/login/device, account
dguillot-gh) and your **Windows password** (the service runs as you, so it uses your GitHub sign-in and the
saved NAS password). At the end, github.com/dguillot-gh/psx-android-builds > Settings > Actions > Runners lists
the VM as **Idle**. Then press the button once with gex_recomp (smallest game) to check.

## Building
github.com/dguillot-gh/psx-android-builds > **Actions** > **Build APK** > **Run workflow** (also in the GitHub app):
- **Game**: one game, or `all`.
- **Speed pre-compile**: off for a normal build; on for the fast play version (hours per game on the VM,
  best overnight). With "Free disk space" on, it starts over each time, so for the speed build untick it.
- **Free disk space**: on (default) deletes the game's build folder afterwards; the next build of that game
  starts from scratch (slower, always works). Off keeps it (faster rebuilds, 2-5 GB per game).

The APKs appear under **Releases** of psx-android-builds (github.com/dguillot-gh/psx-android-builds/releases):
**one Release per game**, named after the game and the date (e.g. "Tomba! 2 - The Evil Swine Return -
2026-10-08 22:10"), uploaded as soon as that game is built, so with `all` they arrive one by one.
Private: they contain game code, don't share them. Install one on
the phone like any APK, or let Obtainium follow psx-android-builds' Releases (needs a GitHub token: the repository is private).

A Pixel 8 that has the games from the USB drive takes these as updates: same signing key.

## A new game
1. On the NAS, make the folder `psx-discs\<name>_recomp` (lowercase, e.g. `tomba3_recomp`) and put the game's
   `.cue` and `.bin` files in it, every disc (disc order = file name order: "(Disc 1)", "(Disc 2)", ...).
2. github.com/dguillot-gh/psx-android-builds > **Actions** > **Add game** > **Run workflow**: type the name; tick
   **Build the APK afterwards** to build it right away. (**Test only** reads the discs and sets up on the VM
   without creating anything on GitHub; run it again without the tick to finish.)
3. The game is then in Build APK's list. Its first boot may need work (seeds, overlays): bring the log to Claude.

What it does (`tools/add-game.ps1`, run on the VM): reads the disc (`tools/new-recomp.ps1`: game.toml, seeds,
boot program), puts the files read from the disc (like `SLUS_123.45`) next to the `.cue`/`.bin` on the NAS
(that folder is what builds copy in), makes the game's **public** setup repository `dguillot-gh/<name>-android`
(only its own files, checked for disc files and PC paths first: `tools/export-games.ps1 -Game`), adds it to
psx-android as `games\<name>_recomp`, and adds the name to Build APK's list. Discs never go to GitHub.
It stops with a clear message, before changing anything, when the NAS folder or its `.cue` is missing or the
name is already used. A run that stopped halfway can simply be run again: it carries on.

**Once on the VM** (VMs set up before Add game existed): the VM's GitHub sign-in needs the "workflow"
permission to change Build APK's list. Add game says so when it is missing; then, in PowerShell on the VM:

```powershell
C:\psx\recomp-backups\tools-cache\gh\bin\gh.exe auth refresh -h github.com -s workflow
```

and type the code it shows at github.com/login/device. (`setup-runner.ps1` asks for it on new setups.)

Test without the VM or GitHub (a fake 2-disc game, `tests\fixtures\add-game`):
`pwsh -File tests\add-game-dryrun.ps1 -Kit <a recomp-backups folder with tools-cache\python and framework>`.

## Good to know
- Each build first pulls the newest scripts, engine and game setups from GitHub, so save your changes
  to GitHub (easy menu option 9) before pressing the button. A changed recompiler is rebuilt automatically.
- A **new game**: see "A new game" below.
- The build runs at low priority, inside the VM's 3 cores, so the other things on the Proxmox box keep running.
- Logs: the run's page on GitHub (Actions), and `psx-android-tools\progress.log` on the VM.
- **Public repositories:** psx-android, psxrecomp-android and the game repositories hold no game code and can
  be public. psx-android-builds must stay **private**: its Releases contain game code, and a self-hosted
  runner must never serve a public repository (anyone could make it run their code on the VM). Never add
  the runner, the workflow or the signing secret to a public repository.
