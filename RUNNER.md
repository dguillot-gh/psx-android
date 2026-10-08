# The build PC: GitHub's "Build APK" button

GitHub's own machines have no discs, so they can't build the games. Instead, a PC at home (here: the
Windows VM on the Proxmox box) runs **GitHub's runner**: it waits for the button, builds the APK with
the scripts in this repository, signs it with the shared key, and puts it in a **private Release** of
psx-android. The discs stay on the NAS and the VM; nothing from them goes to GitHub. The VM only needs
to be on while a build runs (a job waits up to 24 hours for it).

Set up 2026-10-08. Files: `.github/workflows/build-apk.yml` (the button), `tools/ci-build.ps1` (what a
build does), `tools/setup-runner.ps1` (one-time setup). The signing key is the repository secret
`PSX_KEYSTORE_B64` (the drive's `tools-cache\debug.keystore`, base64).

## One-time setup

### 1. Discs to the NAS
Make a share folder for the discs, e.g. `\\NAS\psx\psx-discs`, with **one folder per game, named like the
game folder**, holding what `recomps\<game>\disc\` holds on the USB drive. From the PC with the USB drive
(PowerShell; replace `E:` with the drive's letter and the NAS path with yours):

```powershell
$nas = "\\NAS\psx\psx-discs"
Get-ChildItem E:\recomp-backups\recomps -Directory | ForEach-Object {
    robocopy "$($_.FullName)\disc" "$nas\$($_.Name)" /E /NFL /NDL /NJH
}
```

About 10 GB in all (FF7 2 GB; most games 200-700 MB). Result: `\\NAS\psx\psx-discs\gex_recomp\Gex (USA) (Rev 1).cue`, etc.

### 2. The project to the VM (without discs and builds)
On the VM, pick a disk with **about 15 GB free** plus room for one game's build (2-5 GB; builds are
deleted afterwards unless you untick "Free disk space"). Copy from the USB drive (replace `E:` and `C:\psx`):

```powershell
robocopy E:\recomp-backups C:\psx\recomp-backups /E /XD disc android-recomp android-recomp-next apks `
    recomps-later "llm work" 2026-10-03 reference "git repos" to-do /XF keys.txt /NFL /NDL
```

That brings the tools (`tools-cache`, about 5 GB: Java, Android SDK/NDK, Python, PowerShell, GitHub CLI),
the engine (`framework`), the scripts (`psx-android-tools`) and each game's setup (`recomps`, without discs).

### 3. The NAS password, saved for your Windows account (on the VM)
So builds can read the share without asking. In PowerShell, as your normal user:

```powershell
cmdkey /add:NAS /user:<nas user> /pass
```

(It asks for the password; `NAS` = the NAS's name or IP exactly as in the share path.) Check that
`dir \\NAS\psx\psx-discs` lists the game folders.

### 4. The runner (on the VM)
Open PowerShell with **Run as administrator** (needed once, to add the background service), then:

```powershell
C:\psx\recomp-backups\tools-cache\pwsh\pwsh.exe -File C:\psx\recomp-backups\psx-android-tools\tools\setup-runner.ps1 -Discs \\NAS\psx\psx-discs
```

It asks you twice: a **GitHub code** (type it at github.com/login/device, account dguillot-gh) and your
**Windows password** (the service runs as you, so it uses your GitHub sign-in and saved NAS password).
At the end, github.com/dguillot-gh/psx-android > Settings > Actions > Runners lists the VM as **Idle**.

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
- A **new game**: add it as usual on the PC with the USB drive, save to GitHub, copy its `recomps\<game>`
  folder (without `disc`) to the VM and its disc to the NAS, and add its name to the `game:` list in
  `.github/workflows/build-apk.yml`.
- The build runs at low priority, inside the VM's 3 cores, so the other things on the Proxmox box keep running.
- Logs: the run's page on GitHub (Actions), and `psx-android-tools\progress.log` on the VM.
- Making repositories public later: first move the button and the Releases to a separate **private**
  repository (a self-hosted runner must not serve a public repository, and the APKs contain game code).
