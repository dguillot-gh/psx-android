# Copy what's needed to build and install the games from this drive onto a PC's own disk (much faster than
# building on the USB drive, and the drive can then be unplugged). Hand-written, 2026-10-09.
# Start it with "COPY TO THIS PC.ps1" at the top of the drive (right-click > Run with PowerShell).
# Runs in the Windows PowerShell built into Windows: nothing to install.
#   1. Pick where to put it (a "recomp-backups" folder is made there).
#   2. Pick which games to bring (each game's setup + disc; all ticked by default).
#   3. Copies: tools-cache (Android SDK, Java, compilers, signing key), framework\psxrecomp (the engine and
#      your BIOS files), psx-android-tools (scripts, game setups, play recordings, save backups), PSX-Manager,
#      and the chosen games from recomps\ (and recomps-later\). NOT copied: android-recomp\ (old build
#      files; every game is rebuilt anyway), apks\, old backups.
#   4. Puts a "PSX Manager" shortcut on the desktop.
# Safe to run again: robocopy only copies what changed. A copy cut off by the drive dropping out resumes.
param([string]$Destination = "")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$src = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)          # ...\recomp-backups on the drive
function Say([string]$t, [string]$c = "Gray") { Write-Host $t -ForegroundColor $c }
function FolderGB([string]$p) {
    if (-not (Test-Path $p)) { return 0 }
    $s = (Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($s) { return [math]::Round($s / 1GB, 2) } else { return 0 }
}
Say "PSX Android: copy to this PC" "Cyan"
Say "From: $src"

# --- 1. Where -------------------------------------------------------------------------------------------
if (-not $Destination) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Pick where to put the project. A 'recomp-backups' folder is made inside it (e.g. pick C:\ for C:\recomp-backups)."
    $dlg.SelectedPath = "C:\"
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Say "Cancelled." "Yellow"; exit 1 }
    $Destination = $dlg.SelectedPath
}
$dest = if ((Split-Path $Destination -Leaf) -eq "recomp-backups") { $Destination } else { Join-Path $Destination "recomp-backups" }
if ($dest.TrimEnd('\') -ieq $src.TrimEnd('\')) { Say "That's the drive itself. Pick a folder on this PC." "Red"; exit 1 }
$drive = New-Object System.IO.DriveInfo((Split-Path -Qualifier $dest))
Say "To:   $dest  ($([math]::Round($drive.AvailableFreeSpace / 1GB, 1)) GB free on $($drive.Name))"

# --- 2. Which games ---------------------------------------------------------------------------------------
Say "Measuring the games (a few seconds)..."
$games = @()
foreach ($root in "recomps", "recomps-later") {
    foreach ($g in Get-ChildItem (Join-Path $src $root) -Directory -ErrorAction SilentlyContinue) {
        $games += [pscustomobject]@{ Root = $root; Name = $g.Name; GB = (FolderGB $g.FullName) }
    }
}
$coreGB = (FolderGB (Join-Path $src "tools-cache")) + (FolderGB (Join-Path $src "framework\psxrecomp")) +
          (FolderGB (Join-Path $src "psx-android-tools")) + (FolderGB (Join-Path $src "PSX-Manager"))

$form = New-Object System.Windows.Forms.Form
$form.Text = "Which games to copy?"; $form.Width = 560; $form.Height = 620; $form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 36); $form.ForeColor = [System.Drawing.Color]::White
$info = New-Object System.Windows.Forms.Label
$info.Dock = "Top"; $info.Height = 60; $info.Padding = New-Object System.Windows.Forms.Padding(8)
$list = New-Object System.Windows.Forms.CheckedListBox
$list.Dock = "Fill"; $list.CheckOnClick = $true
$list.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 50); $list.ForeColor = [System.Drawing.Color]::White
foreach ($g in $games) {
    $label = "{0}   ({1:N1} GB){2}" -f ($g.Name -replace '_recomp$', ''), $g.GB, $(if ($g.Root -eq "recomps-later") { "  [set aside]" } else { "" })
    [void]$list.Items.Add($label, ($g.Root -eq "recomps"))
}
$bar = New-Object System.Windows.Forms.FlowLayoutPanel
$bar.Dock = "Bottom"; $bar.Height = 48; $bar.FlowDirection = "RightToLeft"
$ok = New-Object System.Windows.Forms.Button; $ok.Text = "Copy"; $ok.Width = 110; $ok.Height = 34
$cancel = New-Object System.Windows.Forms.Button; $cancel.Text = "Cancel"; $cancel.Width = 90; $cancel.Height = 34
$none = New-Object System.Windows.Forms.Button; $none.Text = "Untick all"; $none.Width = 90; $none.Height = 34
$all = New-Object System.Windows.Forms.Button; $all.Text = "Tick all"; $all.Width = 90; $all.Height = 34
foreach ($b in $ok, $cancel, $none, $all) { $b.ForeColor = [System.Drawing.Color]::Black; [void]$bar.Controls.Add($b) }
$update = {
    $sum = $coreGB
    for ($i = 0; $i -lt $games.Count; $i++) { if ($list.GetItemChecked($i)) { $sum += $games[$i].GB } }
    $info.Text = ("Tools, engine, scripts and PSX Manager: {0:N1} GB (always copied).`r`nWith the ticked games: {1:N1} GB.   Free on {2}: {3:N1} GB. Builds need extra room: about 2-4 GB per game while it builds." -f $coreGB, $sum, $drive.Name, ($drive.AvailableFreeSpace / 1GB))
    $ok.Enabled = ($sum * 1GB) -lt $drive.AvailableFreeSpace
}
$list.add_ItemCheck({ $form.BeginInvoke([Action]$update) | Out-Null })
$all.add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })
$none.add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $false) } })
$ok.add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::OK; $form.Close() })
$cancel.add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
$form.Controls.Add($list); $form.Controls.Add($info); $form.Controls.Add($bar)
& $update
if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Say "Cancelled." "Yellow"; exit 1 }
$chosen = @(); for ($i = 0; $i -lt $games.Count; $i++) { if ($list.GetItemChecked($i)) { $chosen += $games[$i] } }

# --- 3. Copy -----------------------------------------------------------------------------------------------
New-Item -ItemType Directory -Force $dest | Out-Null
$logFile = Join-Path $dest "copy-log.txt"
Add-Content $logFile "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm') copy from $src ====="
function Copy-Part([string]$from, [string]$to, [string[]]$extra = @()) {
    # /Z restartable, /R /W retry a file when the drive drops out; whole-run retries cover the folder vanishing.
    for ($try = 1; $try -le 30; $try++) {
        if (-not (Test-Path $from)) { Say "   waiting for the drive..." "Yellow"; Start-Sleep -Seconds 10; continue }
        $rcArgs = @($from, $to, "/E", "/Z", "/R:20", "/W:5", "/NP", "/NDL", "/NFL", "/XJ", "/LOG+:$logFile") + $extra
        & robocopy @rcArgs | Out-Null
        if ($LASTEXITCODE -lt 8) { return $true }
        Say "   copy interrupted (robocopy $LASTEXITCODE); retrying ($try)..." "Yellow"; Start-Sleep -Seconds 10
    }
    return $false
}
$parts = @(
    @{ Name = "tools-cache (Android SDK, Java, compilers, signing key)"; From = "tools-cache"; Extra = @("/XD", "ci-apks*") },
    @{ Name = "framework\psxrecomp (the engine)"; From = "framework\psxrecomp"; Extra = @() },
    @{ Name = "psx-android-tools (scripts, game setups, recordings, save backups)"; From = "psx-android-tools"; Extra = @("/XD", (Join-Path $src "psx-android-tools\tmp")) },
    @{ Name = "PSX-Manager"; From = "PSX-Manager"; Extra = @() }
)
foreach ($g in $chosen) {
    $gs = Join-Path $src "$($g.Root)\$($g.Name)"
    $parts += @{ Name = "game: $($g.Name -replace '_recomp$', '')"; From = "$($g.Root)\$($g.Name)"; Extra = @("/XD", (Join-Path $gs "build-release"), (Join-Path $gs "generated.orig")) }
}
$n = 0; $failed = @()
foreach ($p in $parts) {
    $n++
    Say ("[{0}/{1}] {2}" -f $n, $parts.Count, $p.Name) "Cyan"
    if (-not (Copy-Part (Join-Path $src $p.From) (Join-Path $dest $p.From) $p.Extra)) { $failed += $p.Name; Say "   FAILED (see $logFile)" "Red" }
}

# --- 4. Desktop shortcut -----------------------------------------------------------------------------------
$exe = Join-Path $dest "PSX-Manager\PSX-Manager.exe"
if (Test-Path $exe) {
    $lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "PSX Manager.lnk"
    $sh = New-Object -ComObject WScript.Shell
    $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = $exe; $s.WorkingDirectory = Split-Path $exe; $s.Description = "PSX Manager: PS1 games on Android"
    $s.Save()
    Say "Desktop shortcut: $lnk" "Green"
}
Add-Content $logFile "===== done $(Get-Date -Format 'HH:mm'), failed: $($failed -join ', ') ====="
if ($failed.Count) {
    Say "Some parts did not copy: $($failed -join ', '). Run this again to finish them (it continues where it stopped)." "Red"
} else {
    Say "Done. Open 'PSX Manager' on the desktop. Every game needs one build (Tick all > Overnight speed)." "Green"
}
Read-Host "Press Enter to close"
