param([string]$Name, [string]$SourceDir, [string]$Framework, [string]$OutRoot)
$ErrorActionPreference = "Stop"
$dest = Join-Path $OutRoot $Name
if (Test-Path $dest) { Write-Host "FAIL: $dest exists"; exit 1 }
robocopy (Join-Path $SourceDir $Name) $dest /E /XD build-release psxrecomp /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Host "FAIL: copy game"; exit 1 }
robocopy $Framework (Join-Path $dest "psxrecomp") /E /XD (Join-Path $Framework "recompiler\build") /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Host "FAIL: copy framework"; exit 1 }
$sec = ""; $v = @{}
foreach ($l in Get-Content (Join-Path $dest "game.toml")) {
    $t = $l.Trim()
    if ($t -match '^\[([^\]]+)\]$') { $sec = $Matches[1]; continue }
    if ($t -match '^(\w+)\s*=\s*"([^"]*)"') { if (-not $v.ContainsKey("$sec.$($Matches[1])")) { $v["$sec.$($Matches[1])"] = $Matches[2] } }
}
$short = ($Name -replace '_recomp$','').ToLower() -replace '[^a-z0-9]',''
$title = $v["game.name"] -replace '(\s*\([^)]*\))+$',''
$exe = Split-Path $v["game.exe"] -Leaf
$project = $short.Substring(0,1).ToUpper() + $short.Substring(1) + "Recomp"
$ng = @{ GameName=$Name; PackageId="com.psxrecomp.$short"; GameId=$v["game.id"]; Title=$title; OutDir=$dest }
if ($v["controller.default_mode"] -eq "analog") { $ng.AnalogSticks = $true }
& (Join-Path $PSScriptRoot "new-game.ps1") @ng
& (Join-Path $PSScriptRoot "make-game-toml-in.ps1") -GameToml (Join-Path $dest "game.toml") -Out (Join-Path $dest "android\app\src\main\assets\game.toml.in")
$cm = Get-Content (Join-Path $PSScriptRoot "..\template\CMakeLists.txt.in") | Select-Object -Skip 4
$cm = $cm | ForEach-Object { $_.Replace("@@PROJECT@@",$project).Replace("@@TITLE@@",$title).Replace("@@EXE@@",$exe) }
Set-Content (Join-Path $dest "CMakeLists.txt") $cm -Encoding utf8NoBOM
Write-Host "ported $Name -> $dest"; exit 0
