# Retire the USB drive, part 2 (RUNNER.md): make this PC (the VM) the build PC, from the NAS copy that
# move-to-nas.ps1 made. Run in PowerShell opened with "Run as administrator", straight from the NAS
# (quotes needed when the path has spaces):
#   & "\\NAS\share\Android Recomp\build-kit\tools-cache\pwsh\pwsh.exe" -ExecutionPolicy Bypass -File "\\NAS\share\Android Recomp\build-kit\psx-android-tools\tools\setup-vm.ps1" -Nas "\\NAS\share\Android Recomp"
# Hand-written, 2026-10-08. Copies <Nas>\build-kit (about 7 GB: tools, engine, scripts, game setups; no
# discs) to -To (default C:\psx\recomp-backups), then runs that copy's setup-runner.ps1 with the discs in
# <Nas>\psx-discs. Safe to run again (copies only what's missing/changed).
param(
    [Parameter(Mandatory = $true)][string]$Nas,
    [string]$To = "C:\psx\recomp-backups",
    [switch]$NoService,
    [switch]$CopyOnly        # copy, but don't set up the runner
)
$ErrorActionPreference = "Stop"
# A mapped drive letter (Z:\...) is invisible to "Run as administrator" windows and to the runner service:
# use the network path it stands for (\\server\share\...).
if ($Nas -match '^([A-Za-z]):') {
    $letter = $Matches[1]
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${letter}:'" -ErrorAction SilentlyContinue
    if (-not $disk) {
        throw "${letter}: is a mapped network drive this window can't see. In a NORMAL PowerShell run  (Get-PSDrive $letter).DisplayRoot  and use that \\server\share path instead of ${letter}: (in quotes)."
    }
    if ($disk.DriveType -eq 4) {   # network drive: switch to the path it stands for
        $root = if ($disk.ProviderName) { $disk.ProviderName } else { (Get-PSDrive $letter).DisplayRoot }
        $Nas = $root.TrimEnd("\") + $Nas.Substring(2)
        Write-Host "Using the network path $Nas (for ${letter}:)"
    }
}
$kit = Join-Path $Nas "build-kit"
$discs = Join-Path $Nas "psx-discs"
foreach ($p in $kit, $discs) {
    if (-not (Test-Path -LiteralPath $p)) { throw "can't reach $p : run move-to-nas.ps1 first (until it says Done), and save the NAS password (RUNNER.md)" }
}
$drive = (Split-Path -Qualifier $To) + "\"
$free = (Get-PSDrive ($drive.Substring(0, 1))).Free / 1GB
Write-Host ("Free on {0} {1:N0} GB (needs about 7 GB, plus 1-7 GB while a game builds)" -f $drive, $free)
if ($free -lt 10) { throw "not enough space on $drive; pick another disk with -To" }

foreach ($d in "tools-cache", "framework", "psx-android-tools", "recomps") {
    Write-Host "Copying $d ..."
    robocopy (Join-Path $kit $d) (Join-Path $To $d) /E /XJ /R:2 /W:5 /NP /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "copying $d failed (robocopy $LASTEXITCODE); run again to retry" }
}
Write-Host "Copied to $To"
if ($CopyOnly) { exit 0 }

$setup = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $To "psx-android-tools\tools\setup-runner.ps1"), "-Discs", $discs)
if ($NoService) { $setup += "-NoService" }
& (Join-Path $To "tools-cache\pwsh\pwsh.exe") @setup
exit $LASTEXITCODE
