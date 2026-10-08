# The build PC: GitHub's "Build APK" button

GitHub's own machines have no discs, so they can't build the games. Instead, a PC at home (here: the
Windows VM on the Proxmox box) runs **GitHub's runner**: it waits for the button, builds the APK with
the scripts in this repository, signs it with the shared key, and puts it in a Release of the **private** repository
**psx-android-builds**. The discs stay on the NAS and the VM; nothing from them goes to GitHub. The VM only needs
to be on while a build runs (a job waits up to 24 hours for it).

Set up 2026-10-08. Files: `.github/workflows/build-apk.yml` in psx-android-builds (the button), `tools/ci-build.ps1` (what a
build does), `tools/setup-runner.ps1` (one-time setup). The signing key is the repository secret
`PSX_KEYSTORE_B64` (the drive's `tools-cache\debug.keystore`, base64).

## What goes where (the USB drive is retired after this)

The NAS gets only what matters (about 25 GB), not the whole 175 GB drive. Below, the NAS folder is
`\\NAS\share\Android Recomp`: use your own path, **in quotes** (it has a space).

```
NAS  ("\\NAS\share\Android Recomp")
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
E:\recomp-backups\tools-cache\pwsh\pwsh.exe -File E:\recomp-backups\psx-android-tools\tools\move-to-nas.ps1 -Nas "\\NAS\share\Android Recomp"
```

About 25 GB, so well under an hour. It only adds files, never deletes any; if it stops, run it again and it
continues. It ends with "Done: key, saves, N games' discs and the build kit are on the NAS." A folder
`recomp-backups-archive` from the earlier, unfinished full copy is not used any more: delete it yourself
when you like.

### 2. On the VM: save the NAS password
In PowerShell, as your normal Windows user (`NAS` = the NAS's name or IP exactly as in the path):

```powershell
cmdkey /add:NAS /user:<nas user> /pass
```

It asks for the password. Check: `dir "\\NAS\share\Android Recomp\psx-discs"` lists the game folders.

### 3. On the VM: copy and set up
Open PowerShell with **Run as administrator** (needed once, to add the background service), then:

```powershell
& "\\NAS\share\Android Recomp\build-kit\tools-cache\pwsh\pwsh.exe" -ExecutionPolicy Bypass -File "\\NAS\share\Android Recomp\build-kit\psx-android-tools\tools\setup-vm.ps1" -Nas "\\NAS\share\Android Recomp"
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

The APKs appear under **Releases** (private; they contain game code: don't share them). Install one on
the phone like any APK, or let Obtainium follow psx-android-builds' Releases (needs a GitHub token: the repository is private).

A Pixel 8 that has the games from the USB drive takes these as updates: same signing key.

## Good to know
- Each build first pulls the newest scripts, engine and game setups from GitHub, so save your changes
  to GitHub (easy menu option 9) before pressing the button. A changed recompiler is rebuilt automatically.
- A **new game**: add it as usual (go.ps1 -Disc on a PC with a copy of the project), save to GitHub, copy its `recomps\<game>`
  folder (without `disc`) to the VM and its `disc` folder to `psx-discs\<game>` on the NAS, and add its name to the `game:` list in
  `.github/workflows/build-apk.yml` in psx-android-builds.
- The build runs at low priority, inside the VM's 3 cores, so the other things on the Proxmox box keep running.
- Logs: the run's page on GitHub (Actions), and `psx-android-tools\progress.log` on the VM.
- **Public repositories:** psx-android, psxrecomp-android and the game repositories hold no game code and can
  be public. psx-android-builds must stay **private**: its Releases contain game code, and a self-hosted
  runner must never serve a public repository (anyone could make it run their code on the VM). Never add
  the runner, the workflow or the signing secret to a public repository.
