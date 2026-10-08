# Overnight job: give every game's speed pre-compile time to finish (up to 4 hours each), one game at a time.
# Faster games afterwards. Needs no phone. Leave the PC plugged in; it stays awake by itself.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Overnight: finish the speed pre-compile"
$games = Pick-Games (Get-Games) "Which games? ('all' is normal)"
if (-not $games) { Pause-End; return }
Info "Starting $($games.Count) game(s) at $(Get-Date -Format 'HH:mm'). This can take many hours; leave it running."
$results = foreach ($g in $games) { Run-Go $g @("-Speed", "-SpeedMinutes", "240", "-NoPhone") }
Title "Overnight results"
$results | ForEach-Object { if ($_ -match ': ok') { Good $_ } else { Bad $_ } }
Info "Next: menu option 4 puts the updated games on the phone."
Pause-End
