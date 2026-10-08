# Retire the USB drive, part 2 (RUNNER.md): make this PC (the VM) the build PC, from the NAS copy.
# Run in PowerShell opened with "Run as administrator", straight from the NAS:
#   \\NAS\psx\recomp-backups-archive\tools-cache\pwsh\pwsh.exe -File \\NAS\psx\recomp-backups-archive\psx-android-tools\tools\setup-vm.ps1 -Nas \\NAS\psx
# Hand-written, 2026-10-08. Copies only what building needs (about 7 GB; no discs, no old builds) from
# <Nas>\recomp-backups-archive to -To (default C:\psx\recomp-backups), then runs that copy's
# setup-runner.ps1 with the discs in <Nas>\psx-discs. Safe to run again (copies only what's missing/changed).
param(
    [Parameter(Mandatory = $true)][string]$Nas,
    [string]$To = "C:\psx\recomp-backups",
    [switch]$NoService,
    [switch]$CopyOnly        # copy, but don't set up the runner
)
$ErrorActionPreference = "Stop"
$archive = Join-Path $Nas "recomp-backups-archive"
$discs = Join-Path $Nas "psx-discs"
foreach ($p in $archive, $discs) { if (-not (Test-Path -LiteralPath $p)) { throw "can't reach $p : run move-to-nas.ps1 first, and save the NAS password (RUNNER.md)" } }
$drive = (Split-Path -Qualifier $To) + "\"
$free = (Get-PSDrive ($drive.Substring(0, 1))).Free / 1GB
Write-Host ("Free on {0} {1:N0} GB (needs about 7 GB, plus 1-7 GB while a game builds)" -f $drive, $free)
if ($free -lt 10) { throw "not enough space on $drive; pick another disk with -To" }

foreach ($d in "tools-cache", "framework", "psx-android-tools") {
    Write-Host "Copying $d ..."
    robocopy (Join-Path $archive $d) (Join-Path $To $d) /E /XJ /R:2 /W:5 /NP /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "copying $d failed (robocopy $LASTEXITCODE); run again to retry" }
}
Write-Host "Copying recomps (each game's setup, without discs) ..."
robocopy (Join-Path $archive "recomps") (Join-Path $To "recomps") /E /XD disc /R:2 /W:5 /NP /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copying recomps failed (robocopy $LASTEXITCODE); run again to retry" }
Write-Host "Copied to $To"
if ($CopyOnly) { exit 0 }

$setup = @("-NoProfile", "-File", (Join-Path $To "psx-android-tools\tools\setup-runner.ps1"), "-Discs", $discs)
if ($NoService) { $setup += "-NoService" }
& (Join-Path $To "tools-cache\pwsh\pwsh.exe") @setup
exit $LASTEXITCODE
