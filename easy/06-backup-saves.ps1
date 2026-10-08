# Back up the memory-card saves of every game app on the phone to the drive (saves-backup\<app>\<time>\).
# Read-only on the phone. Installing a game (options 2, 3, 4) also does this first, automatically.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Back up all saves"
if (-not (Need-Phone)) { Pause-End; return }
$pkgs = @(& $Adb shell pm list packages com.psxrecomp 2>$null | ForEach-Object { if ($_ -match 'package:(\S+)') { $Matches[1] } })
if (-not $pkgs) { Warn "No game apps (com.psxrecomp.*) on the phone."; Pause-End; return }
foreach ($p in $pkgs) {
    Info "  $p"
    & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone.ps1") -Action backup-saves -Package $p | ForEach-Object { "    $_" }
}
Good "Backups are in $Tools\saves-backup (one folder per app, one subfolder per backup time)."
Pause-End
