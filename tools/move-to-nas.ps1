# Retire the USB drive, part 1 (RUNNER.md): copy what matters to the NAS (about 25 GB, not the whole drive).
# Run on the PC with the USB drive plugged in:
#   <drive>\recomp-backups\tools-cache\pwsh\pwsh.exe -File <drive>\recomp-backups\psx-android-tools\tools\move-to-nas.ps1
# The NAS folder defaults to ours ("\\192.168.0.194\windowsmedia\Android Recomp", Z: on our PCs); another
# with -Nas "<\\server\share\folder>".
# Hand-written, 2026-10-08 (slimmed the same day: the full 175 GB archive took too long). Makes on the NAS:
#   keys\debug.keystore   the signing key (the phone only takes updates signed with it)
#   psx-discs\<game>\     each game's disc folder, recomps\ and recomps-later\ (about 13 GB)
#   build-kit\            what the build PC needs: tools-cache, framework, psx-android-tools, recomps WITHOUT
#                         discs (about 7 GB; setup-vm.ps1 copies it to the VM)
#   saves\                memory cards and app-data backups: psx-android-tools\saves-backup, each game's
#                         saves\ and memcard-import\, 2026-10-03\phone-backup, and 2026-10-03's small files
#                         (keys.txt among them, copied as-is and never opened)
# NOT copied (rebuildable or duplicates): android-recomp* (build folders), apks\ (old builds; new ones are
# GitHub Releases), to-do\ (the same discs as psx-discs), 2026-10-03's old project snapshots and scratch,
# reference\ (on GitHub), git repos\, llm work\. They stay on the USB drive.
# Only ever ADDS or UPDATES files on the NAS (no /MIR: nothing there is deleted). Safe to run again: an
# interrupted copy continues where it stopped. The USB drive is only read.
param([string]$Nas = "\\192.168.0.194\windowsmedia\Android Recomp")
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")
if (-not (Test-Path -LiteralPath $Nas)) { throw "can't reach $Nas (check the path; Windows may ask for the NAS password in File Explorer first)" }
$failed = @()
function Copy-Tree([string]$from, [string]$to, [string[]]$extra = @()) {
    if (-not (Test-Path -LiteralPath $from)) { return }
    robocopy $from $to /E /COPY:DAT /XJ /R:2 /W:5 /NP /NFL /NDL /NJH /NJS @extra | Out-Host
    if ($LASTEXITCODE -ge 8) { $script:failed += "$from -> $to (robocopy $LASTEXITCODE)" }
}
$gameDirs = @("recomps", "recomps-later") | ForEach-Object { Get-ChildItem (Join-Path $DriveRoot $_) -Directory -ErrorAction SilentlyContinue }

Write-Host "1/4 Signing key -> $Nas\keys"
New-Item -ItemType Directory -Force (Join-Path $Nas "keys") | Out-Null
Copy-Item (Join-Path $ToolsCache "debug.keystore") (Join-Path $Nas "keys") -Force

Write-Host "2/4 Saves and backups -> $Nas\saves"
$saves = Join-Path $Nas "saves"
Copy-Tree (Join-Path $DriveRoot "psx-android-tools\saves-backup") (Join-Path $saves "saves-backup")
foreach ($g in $gameDirs) {
    foreach ($s in "saves", "memcard-import") { Copy-Tree (Join-Path $g.FullName $s) (Join-Path $saves "games\$($g.Name)\$s") }
}
$snap = Join-Path $DriveRoot "2026-10-03"
Copy-Tree (Join-Path $snap "phone-backup") (Join-Path $saves "2026-10-03\phone-backup")
Copy-Tree $snap (Join-Path $saves "2026-10-03") @("/LEV:1")   # its loose files only (keys.txt as-is), no folders

Write-Host "3/4 Discs -> $Nas\psx-discs (about 13 GB)"
foreach ($g in $gameDirs) {
    $d = Join-Path $g.FullName "disc"
    if (Test-Path -LiteralPath $d) { Write-Host "   $($g.Name)"; Copy-Tree $d (Join-Path $Nas "psx-discs\$($g.Name)") }
}

Write-Host "4/4 Build kit -> $Nas\build-kit (about 7 GB)"
$kit = Join-Path $Nas "build-kit"
# Exclusions as FULL paths (a bare name would also skip same-named folders deeper down).
Write-Host "   tools-cache"
Copy-Tree $ToolsCache (Join-Path $kit "tools-cache")
Write-Host "   framework\psxrecomp (the engine the builds use; not the -gpu / -next side copies)"
Copy-Tree (Join-Path $DriveRoot "framework\psxrecomp") (Join-Path $kit "framework\psxrecomp")
Write-Host "   psx-android-tools"
$t = Join-Path $DriveRoot "psx-android-tools"
Copy-Tree $t (Join-Path $kit "psx-android-tools") @("/XD", (Join-Path $t "logs"), (Join-Path $t "tmp"), (Join-Path $t "saves-backup"))
Write-Host "   recomps (without discs, saves, builds)"
$xd = @("/XD") + @(foreach ($g in Get-ChildItem (Join-Path $DriveRoot "recomps") -Directory) {
    foreach ($s in "disc", "saves", "memcard-import", "build-release", "generated.orig") { Join-Path $g.FullName $s } })
Copy-Tree (Join-Path $DriveRoot "recomps") (Join-Path $kit "recomps") $xd

Write-Host ""
if ($failed.Count) { Write-Host "Some copies FAILED (run this again to retry):" -ForegroundColor Red; $failed | ForEach-Object { Write-Host "  $_" }; exit 1 }
$n = @(Get-ChildItem (Join-Path $Nas "psx-discs") -Directory).Count
Write-Host "Done: key, saves, $n games' discs and the build kit are on the NAS." -ForegroundColor Green
Write-Host "Keep one more copy of $Nas\keys\debug.keystore somewhere else too (e.g. a password manager)."
Write-Host "Keep the USB drive until a build on the VM worked. Next, on the VM: RUNNER.md, step 2."
