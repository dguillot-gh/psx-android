# Retire the USB drive, part 1 (RUNNER.md): copy it to the NAS. Run on the PC with the USB drive plugged in:
#   <drive>\recomp-backups\tools-cache\pwsh\pwsh.exe -File <drive>\recomp-backups\psx-android-tools\tools\move-to-nas.ps1 -Nas \\NAS\psx
# Hand-written, 2026-10-08. Makes on the NAS:
#   recomp-backups-archive\   the whole drive folder, as-is (keys.txt included, never opened)
#   psx-discs\<game>\         each game's disc folder (what the build PC reads)
#   keys\debug.keystore       the signing key
# Only ever ADDS or UPDATES files on the NAS (no /MIR: nothing there is deleted). Safe to run again: an
# interrupted copy continues where it stopped. The USB drive is only read.
param([Parameter(Mandatory = $true)][string]$Nas)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")
if (-not (Test-Path -LiteralPath $Nas)) { throw "can't reach $Nas (check the path; Windows may ask for the NAS password in File Explorer first)" }
$archive = Join-Path $Nas "recomp-backups-archive"
$discs = Join-Path $Nas "psx-discs"
$keys = Join-Path $Nas "keys"
$failed = @()
function Copy-Tree([string]$from, [string]$to, [string[]]$extra = @()) {
    robocopy $from $to /E /COPY:DAT /R:2 /W:5 /NP /NFL /NDL /NJH @extra | Out-Host
    if ($LASTEXITCODE -ge 8) { $script:failed += "$from -> $to (robocopy $LASTEXITCODE)" }
}

Write-Host "1/3 Signing key -> $keys"
New-Item -ItemType Directory -Force $keys | Out-Null
Copy-Item (Join-Path $ToolsCache "debug.keystore") $keys -Force

Write-Host "2/3 Discs -> $discs (about 10 GB)"
foreach ($dir in "recomps", "recomps-later") {
    foreach ($g in Get-ChildItem (Join-Path $DriveRoot $dir) -Directory -ErrorAction SilentlyContinue) {
        $d = Join-Path $g.FullName "disc"
        if (Test-Path -LiteralPath $d) { Write-Host "   $($g.Name)"; Copy-Tree $d (Join-Path $discs $g.Name) }
    }
}

Write-Host "3/3 The whole drive folder -> $archive (about 175 GB; hours over USB)"
Copy-Tree $DriveRoot $archive @("/XJ")   # /XJ: skip links (e.g. a test copy's link to tools-cache)

Write-Host ""
if ($failed.Count) { Write-Host "Some copies FAILED (run this again to retry):" -ForegroundColor Red; $failed | ForEach-Object { Write-Host "  $_" }; exit 1 }
$n = @(Get-ChildItem $discs -Directory).Count
Write-Host "Done: archive, $n games' discs in psx-discs, and the signing key are on the NAS." -ForegroundColor Green
Write-Host "Keep one more copy of $keys\debug.keystore somewhere else too (e.g. a password manager)."
Write-Host "Next, on the VM: RUNNER.md, 'On the VM'."
