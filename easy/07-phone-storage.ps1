# Phone storage: shows free space and the disc copies in the phone's Download folder. Each game app copies its
# disc into its own storage when you pick it, so a Download\<game> folder is a spare copy once that's done.
# Offers to delete ONLY those spare copies, one by one, after you type YES. Nothing else is ever touched.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Phone storage"
if (-not (Need-Phone)) { Pause-End; return }
$df = (& $Adb shell df -h /storage/emulated 2>$null | Select-Object -Last 1) -split '\s+'
if ($df.Count -ge 4) { Info "Free space: $($df[3]) of $($df[1])" }
$rows = @()
foreach ($g in Get-Games -IncludeLater) {
    $dl = "/sdcard/Download/$g"
    $size = ((& $Adb shell "du -sh '$dl' 2>/dev/null") -split '\s+')[0]
    if (-not $size) { continue }
    $pkg = Get-Package $g
    $inApp = @(& $Adb shell "run-as $pkg ls files/gamedata 2>/dev/null" | Where-Object { $_ -match '\.cue\s*$' }).Count
    $rows += [pscustomobject]@{ Game = $g; Download = $size; "App has its own copy" = if ($inApp) { "yes ($inApp disc)" } else { "NO - keep" } }
}
if (-not $rows) { Good "No game disc copies in Download."; Pause-End; return }
$rows | Format-Table -AutoSize | Out-Host
$spare = @($rows | Where-Object { $_."App has its own copy" -like "yes*" })
if (-not $spare) { Info "Nothing safe to remove: every copy is still needed (pick those discs in their apps first)."; Pause-End; return }
Warn "These Download folders are spare copies (the apps already have the discs):"
$spare | ForEach-Object { Warn "  Download\$($_.Game)  ($($_.Download))" }
Info "If you ever reinstall a game from scratch, menu option 4 copies its disc back."
$a = Read-Host "Type YES to delete these spare copies from the phone (anything else = keep them)"
if ($a -ceq "YES") {
    foreach ($r in $spare) { & $Adb shell "rm -r '/sdcard/Download/$($r.Game)'"; Good "  removed Download\$($r.Game)" }
    $df = (& $Adb shell df -h /storage/emulated 2>$null | Select-Object -Last 1) -split '\s+'
    if ($df.Count -ge 4) { Good "Free space now: $($df[3])" }
} else { Info "Kept everything." }
Pause-End
