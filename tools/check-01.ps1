$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$tpl  = Join-Path $repo "template\android"
$out  = Join-Path $env:TEMP "newgame-check"
$script = Join-Path $PSScriptRoot "new-game.ps1"
if (-not (Test-Path $script) -or (Get-Item $script).Length -lt 50) { Write-Host "FAIL: tools\new-game.ps1 missing or empty"; exit 1 }
if (Test-Path $out) { Remove-Item $out -Recurse -Force }

& $script -GameName persona -PackageId com.psxrecomp.persona -GameId SLPS-01234 -Title "Persona" -AnalogSticks -OutDir $out

$android = Join-Path $out "android"
if (-not (Test-Path $android)) { Write-Host "FAIL: $android missing"; exit 1 }
$fail = @()
foreach ($d in "app\build", ".cxx", ".gradle") {
    if (Test-Path (Join-Path $android $d)) { $fail += "copied build folder $d" }
}
$ext = ".gradle",".xml",".java",".kts",".properties"
$new = Get-ChildItem $android -Recurse -File | Where-Object { $ext -contains $_.Extension }
$old = Get-ChildItem $tpl     -Recurse -File | Where-Object { $ext -contains $_.Extension }
function Hits($p, $f) { ($f | Select-String -Pattern $p -SimpleMatch | Measure-Object).Count }

if ((Hits "com.psxrecomp.tomba"   $new) -gt 0) { $fail += "old package id still present" }
if ((Hits "com.psxrecomp.persona" $new) -eq 0) { $fail += "new package id missing" }
foreach ($keep in "com.psxrecomp.android","org.libsdl.app") {
    if ((Hits $keep $old) -ne (Hits $keep $new)) { $fail += "shared id changed: $keep" }
}
$res = Join-Path $android "app\src\main\res\values"
$str = Join-Path $res "strings.xml"
$boo = Join-Path $res "bools.xml"
if (-not (Test-Path $str) -or -not (Test-Path $boo)) { $fail += "strings.xml or bools.xml missing" }
else {
    $s = Get-Content $str -Raw
    if ($s -notmatch 'psx_game_id"[^>]*>SLPS-01234<')  { $fail += "psx_game_id not set" }
    if ($s -notmatch 'psx_game_title"[^>]*>Persona<')  { $fail += "psx_game_title not set" }
    if ($s -match 'Tomba')                             { $fail += "Tomba still in strings.xml" }
    if ((Get-Content $boo -Raw) -notmatch 'psx_analog_sticks"[^>]*>\s*true') { $fail += "psx_analog_sticks not true" }
}
if ($fail.Count) { $fail | ForEach-Object { Write-Host "FAIL: $_" }; exit 1 }
Write-Host "OK"; exit 0
