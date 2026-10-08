# Put already-built games on the phone: back up saves, install the newest APK, copy the disc only if the app
# doesn't have it yet, and a quick 30-second test run. Hands off the phone while it runs.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Put games on the phone"
if (-not (Need-Phone)) { Pause-End; return }
$built = @(Get-Games | Where-Object { Get-ChildItem (Join-Path $DriveRoot "apks") -Recurse -Filter "$_-play-*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1 })
$games = Pick-Games $built "Which games to put on the phone?"
if (-not $games) { Pause-End; return }
# phone-pass.ps1 takes the newest APK of one date folder: find each game's newest date.
foreach ($g in $games) {
    $apk = Get-ChildItem (Join-Path $DriveRoot "apks") -Recurse -Filter "$g-play-*.apk" | Sort-Object LastWriteTime | Select-Object -Last 1
    & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone-pass.ps1") -TestSeconds 30 -Game $g -Date $apk.Directory.Name
}
Pause-End
