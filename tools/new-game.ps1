param(
    [Parameter(Mandatory=$true)][string]$GameName,
    [Parameter(Mandatory=$true)][string]$PackageId,
    [Parameter(Mandatory=$true)][string]$GameId,
    [Parameter(Mandatory=$true)][string]$Title,
    [switch]$AnalogSticks,
    [Parameter(Mandatory=$true)][string]$OutDir
)
$ErrorActionPreference = "Stop"

$template = (Resolve-Path (Join-Path $PSScriptRoot "..\template\android")).Path
$dest = Join-Path ([IO.Path]::GetFullPath($OutDir)) "android"
if ($dest.StartsWith($template, [StringComparison]::OrdinalIgnoreCase)) { throw "OutDir must not be inside the template" }

New-Item -ItemType Directory -Force $dest | Out-Null
robocopy $template $dest /E /R:1 /W:1 /XD build .cxx .gradle /XF local.properties /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }

$old = [regex]::Escape("com.psxrecomp.tomba")
$textExt = ".gradle", ".xml", ".properties", ".java", ".kts", ".txt"
Get-ChildItem $dest -Recurse -File |
    Where-Object { $textExt -contains $_.Extension -and $_.Name -ne "game.toml.in" } |
    ForEach-Object {
        $c = Get-Content $_.FullName -Raw
        if ($c -match $old) { Set-Content $_.FullName ($c -replace $old, $PackageId) -NoNewline }
    }

$values = Join-Path $dest "app\src\main\res\values"
function Set-StringRes([string]$file, [string]$name, [string]$value) {
    $c = Get-Content $file -Raw
    $esc = [System.Security.SecurityElement]::Escape($value)
    $pat = '(<string\s+name="' + [regex]::Escape($name) + '"[^>]*>)[^<]*(</string>)'
    if ($c -notmatch $pat) { throw "string '$name' not found in $file" }
    $new = [regex]::Replace($c, $pat, { param($m) $m.Groups[1].Value + $esc + $m.Groups[2].Value })
    Set-Content $file $new -NoNewline
}
$strings = Join-Path $values "strings.xml"
Set-StringRes $strings "app_name" $Title
Set-StringRes $strings "psx_game_title" $Title
Set-StringRes $strings "psx_game_id" $GameId

$bools = Join-Path $values "bools.xml"
$b = Get-Content $bools -Raw
$val = if ($AnalogSticks) { "true" } else { "false" }
$pat = '(<bool\s+name="psx_analog_sticks"[^>]*>)\s*(true|false)\s*(</bool>)'
if ($b -notmatch $pat) { throw "psx_analog_sticks not found in bools.xml" }
Set-Content $bools ($b -replace $pat, ('${1}' + $val + '${3}')) -NoNewline

Write-Host "Created $dest"
exit 0
