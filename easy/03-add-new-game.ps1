# Add a NEW game from your own disc: pick its .cue file(s), give it a short name, and the pipeline sets it up,
# builds it and (optional) installs it. A brand-new game may still need a programmer before it plays right;
# see README.md "When a new game doesn't work".
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Add a new game"
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = "Pick the game's .cue file (several discs: select them all, Ctrl+click)"
$dlg.Filter = "Disc images (*.cue)|*.cue"
$dlg.Multiselect = $true
if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Info "Cancelled."; Pause-End; return }
$cues = @($dlg.FileNames | Sort-Object)
Info "Discs, in this order:"
$cues | ForEach-Object { Info "  $_" }
if (-not (Ask-YesNo "Is that the right disc order (Disc 1 first)?" $true)) { Info "Rename or pick them one at a time in order, then try again."; Pause-End; return }
$suggest = ((Split-Path $cues[0] -Leaf) -replace '\(.*$', '' -replace '[^A-Za-z0-9]', '').ToLower()
do {
    $name = Read-Host "Short name, lowercase letters/numbers only (Enter = $suggest)"
    if (-not $name) { $name = $suggest }
    $name = $name.ToLower() -replace '[^a-z0-9]', ''
} while (-not $name)
$game = "${name}_recomp"
if (Test-Path (Join-Path $Recomps $game)) { Warn "$game already exists; it will be built from its existing setup." }
$extra = @("-Speed", "-NoInstall", "-NoPhone", "-Disc") + $cues
$r = Run-Go $game $extra
if ($r -match ': ok') {
    Good "$game is built. Its app id is $(Get-Package $game)."
    if ((Ask-YesNo "Put it on the phone now?" $true) -and (Need-Phone)) {
        & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone-pass.ps1") -TestSeconds 30 -Game $game
        Info "On the phone: open the app, Select game file > side menu > your phone > Download > $game > the .cue, then Play."
    }
} else {
    Warn "The build did not finish. The game's folder is $Recomps\$game; logs are in $WorkDir\$game."
    Warn "Most often a brand-new game needs a programmer's look (see README.md)."
}
Pause-End
