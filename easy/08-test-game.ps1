# Test a game on the phone: opens it, presses Play, and records the game's fps, three screenshots and its log
# (in android-recomp\<game>\phone-test\<time>\). The game needs its disc picked once in the app first.
# Tip: turn on the FPS counter in the game's menu (Display) so the game's own fps gets logged.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Test a game on the phone"
if (-not (Need-Phone)) { Pause-End; return }
$installed = @{}
foreach ($l in & $Adb shell pm list packages com.psxrecomp 2>$null) { if ($l -match 'package:(\S+)') { $installed[$Matches[1]] = $true } }
$games = Pick-Games @(Get-Games -IncludeLater | Where-Object { $installed[(Get-Package $_)] }) "Which game to test?"
if (-not $games) { Pause-End; return }
$sec = Read-Host "How many seconds? (Enter = 90)"
if ($sec -notmatch '^\d+$') { $sec = "90" }
foreach ($g in $games) {
    $out = Join-Path $WorkDir ("$g\phone-test\" + (Get-Date -Format "yyyyMMdd-HHmm"))
    Info "Testing $g for $sec s; hands off the phone."
    & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone.ps1") -Action play-test -Package (Get-Package $g) -OutDir $out -Seconds $sec
    if ($LASTEXITCODE -eq 2) { Warn "  Pick the disc once in the app (Select game file), then test again." }
    elseif (Test-Path (Join-Path $out "summary.txt")) { Good ("  " + (Get-Content (Join-Path $out "summary.txt") -Raw).Trim()); Info "  Screenshots and log: $out" }
    & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone.ps1") -Action home | Out-Null
}
Pause-End
