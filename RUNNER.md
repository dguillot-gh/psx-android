# The build PC: GitHub's "Build APK" button

GitHub's own machines have no discs, so they can't build the games. Instead, a PC at home (here: the
Windows VM on the Proxmox box) runs **GitHub's runner**: it waits for the button, builds the APK with
the scripts in this repository, signs it with the shared key, and puts it in a **private Release** of
psx-android. The discs stay on the NAS and the VM; nothing from them goes to GitHub. The VM only needs
to be on while a build runs (a job waits up to 24 hours for it).

Set up 2026-10-08. Files: `.github/workflows/build-apk.yml` (the button), `tools/ci-build.ps1` (what a
build does), `tools/setup-runner.ps1` (one-time setup). The signing key is the repository secret
`PSX_KEYSTORE_B64` (the drive's `tools-cache\debug.keystore`, base64).

## What goes where (the USB drive is retired after this)

```
NAS  (\NAS\psx)
├── recomp-backups-archive\     the whole USB drive, copied once, as-is (safety net, never touched)
│   ├── 2026-10-03\             (keys.txt inside, left alone)
│   └── apks\, android-recomp\, saves backups, reference\, llm work\, ... everything
├── psx-discs\                  what the VM builds from (about 10 GB)
│   ├── gex_recomp\             Gex (USA) (Rev 1).cue + .bin + the files read from the disc
│   ├── ff7_recomp\             3 discs
│   └── ... one folder per game
└── keys\debug.keystore         the signing key (keep one more copy off the NAS)

VM  (C:\psx\recomp-backups: about 7 GB, plus one game's build at a time)
├── tools-cache\                Java, Android SDK/NDK, Python, PowerShell, GitHub CLI (4.8 GB)
├── framework\psxrecomp\        the engine (updated from GitHub at each build)
├── psx-android-tools\          the scripts (updated from GitHub at each build)
├── recomps\<game>\             each game's setup, WITHOUT its disc folder (1.4 GB in all)
├── actions-runner\             GitHub's runner (made by setup-runner.ps1)
└── android-recomp\<game>\      build folder, 1-7 GB, deleted after each build ("Free disk space")

GitHub  (private; already there, nothing to copy)
├── psx-android                 scripts, the "Build APK" button, Releases (the APKs)
├── psxrecomp-android           the engine
└── <game>-android              each game's setup
```

GitHub's secret has the signing key too, but a secret can't be downloaded back: if every other copy of
`debug.keystore` is lost, the phone refuses updates to the installed games.

## One-time setup
Two scripts do the copying; you run one command on each machine. Only wipe or reuse the USB drive after
a test build on the VM worked.

### 1. On the PC with the USB drive: copy it to the NAS
Make a share on the NAS (here `\NAS\psx`; use yours) and check you can open it in File Explorer. Then in
PowerShell (replace `E:` with the drive's letter):

```powershell
E:\recomp-backups\tools-cache\pwsh\pwsh.exe -File E:\recomp-backups\psx-android-tools\tools\move-to-nas.ps1 -Nas \NAS\psx
```

It makes `keys\debug.keystore`, `psx-discs\<game>` (about 10 GB) and `recomp-backups-archive` (the whole
drive, about 175 GB: around 2 hours). It only adds files, never deletes any; if it stops, run it again and
it continues. Afterwards keep one more copy of the key off the NAS (e.g. a password manager).

### 2. On the VM: save the NAS password
In PowerShell, as your normal Windows user (`NAS` = the NAS's name or IP exactly as in `\NAS\psx`):

```powershell
cmdkey /add:NAS /user:<nas user> /pass
```

It asks for the password. Check: `dir \NAS\psx\psx-discs` lists the game folders.

### 3. On the VM: copy and set up
Open PowerShell with **Run as administrator** (needed once, to add the background service), then:

```powershell
\NAS\psx\recomp-backups-archive\tools-cache\pwsh\pwsh.exe -File \NAS\psx\recomp-backups-archive\psx-android-tools\tools\setup-vm.ps1 -Nas \NAS\psx
```

It copies what building needs to `C:\psx\recomp-backups` (about 7 GB; `-To D:\somewhere` for another disk),
then sets up the runner. It asks you twice: a **GitHub code** (type it at github.com/login/device, account
dguillot-gh) and your **Windows password** (the service runs as you, so it uses your GitHub sign-in and the
saved NAS password). At the end, github.com/dguillot-gh/psx-android > Settings > Actions > Runners lists
the VM as **Idle**. Then press the button once with gex_recomp (smallest game) to check.

## Building
github.com/dguillot-gh/psx-android > **Actions** > **Build APK** > **Run workflow**:
- **Game**: one game, or `all`.
- **Speed pre-compile**: off for a normal build; on for the fast play version (hours per game on the VM,
  best overnight). With "Free disk space" on, it starts over each time, so for the speed build untick it.
- **Free disk space**: on (default) deletes the game's build folder afterwards; the next build of that game
  starts from scratch (slower, always works). Off keeps it (faster rebuilds, 2-5 GB per game).

The APKs appear under **Releases** (private; they contain game code: don't share them). Install one on
the phone like any APK, or let Obtainium follow this repository's Releases.

A Pixel 8 that has the games from the USB drive takes these as updates: same signing key.

## Good to know
- Each build first pulls the newest scripts, engine and game setups from GitHub, so save your changes
  to GitHub (easy menu option 9) before pressing the button. A changed recompiler is rebuilt automatically.
- A **new game**: add it as usual (go.ps1 -Disc on a PC with a copy of the project), save to GitHub, copy its `recomps\<game>`
  folder (without `disc`) to the VM and its `disc` folder to `psx-discs\<game>` on the NAS, and add its name to the `game:` list in
  `.github/workflows/build-apk.yml`.
- The build runs at low priority, inside the VM's 3 cores, so the other things on the Proxmox box keep running.
- Logs: the run's page on GitHub (Actions), and `psx-android-tools\progress.log` on the VM.
- Making repositories public later: first move the button and the Releases to a separate **private**
  repository (a self-hosted runner must not serve a public repository, and the APKs contain game code).
