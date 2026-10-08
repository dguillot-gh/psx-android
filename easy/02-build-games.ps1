# Build or update games, one at a time, with the speed pre-compile; then (optional) put them on the phone.
# Safe to stop and run again: finished work is kept and the next run continues.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Build or update games"
$games = Pick-Games (Get-Games) "Which games to build?"
if (-not $games) { Pause-End; return }
$cap = Read-Host "Speed pre-compile time limit per game in minutes (Enter = 45; more = faster game, longer build)"
$extra = @("-Speed", "-NoInstall")
if ($cap -match '^\d+$') { $extra += @("-SpeedMinutes", $cap) }
$phoneNow = Ask-YesNo "Is the phone plugged in? (it lets the build read what you played; not required)" $false
if (-not $phoneNow) { $extra += "-NoPhone" }
$install = Ask-YesNo "Put each finished game on the phone afterwards?" $phoneNow
Info "Building $($games.Count) game(s). The PC stays awake; you can leave it."
$ok = @()
foreach ($g in $games) {
    $r = Run-Go $g $extra
    if ($r -match ': ok') { $ok += $g }
}
if ($install -and $ok.Count) {
    if (Need-Phone) {
        & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone-pass.ps1") -TestSeconds 30 -Game ($ok -join ",")
    }
}
Pause-End
