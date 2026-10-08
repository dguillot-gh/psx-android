# PS1 games on Android: the menu. Right-click this file > "Run with PowerShell".
# Every option is also its own script in this folder (01-....ps1 and so on); see README.md here.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    # Windows' built-in PowerShell 5: restart in the portable PowerShell 7 on the drive (or an installed one).
    $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $p7 = Join-Path $root "tools-cache\pwsh\pwsh.exe"
    if (-not (Test-Path $p7)) { $p7 = (Get-Command pwsh -ErrorAction SilentlyContinue).Source }
    if (-not $p7) { Write-Host "PowerShell 7 is needed: run  winget install Microsoft.PowerShell  then try again."; Read-Host "Press Enter"; exit 1 }
    & $p7 -NoProfile -File $PSCommandPath
    exit $LASTEXITCODE
}
$items = [ordered]@{
    "1"  = @("01-status.ps1",               "What's built, what's on the phone, last test results")
    "2"  = @("02-build-games.ps1",          "Build or update games (and put them on the phone)")
    "3"  = @("03-add-new-game.ps1",         "Add a NEW game from your disc")
    "4"  = @("04-put-games-on-phone.ps1",   "Put already-built games on the phone (install + disc + quick test)")
    "5"  = @("05-overnight-speed.ps1",      "Overnight: finish every game's speed pre-compile")
    "6"  = @("06-backup-saves.ps1",         "Back up all memory-card saves from the phone")
    "7"  = @("07-phone-storage.ps1",        "Phone storage: show space, clean up disc copies")
    "8"  = @("08-test-game.ps1",            "Test a game on the phone (fps, screenshots, log)")
    "9"  = @("09-save-to-github.ps1",       "Save everything to GitHub (your private repositories)")
    "10" = @("10-update-psxrecomp.ps1",     "Update the engine to the newest psxrecomp (careful, guided)")
}
while ($true) {
    Clear-Host
    Write-Host "PS1 games on Android" -ForegroundColor Cyan
    Write-Host "--------------------" -ForegroundColor Cyan
    foreach ($k in $items.Keys) { Write-Host ("  {0,2}. {1}" -f $k, $items[$k][1]) }
    Write-Host "   q. Quit"
    $c = Read-Host "Pick a number"
    if ($c -eq "q" -or $c -eq "Q") { break }
    if ($items.Contains($c)) {
        & (Join-Path $PSScriptRoot $items[$c][0])
    }
}
