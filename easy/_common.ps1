# Shared helpers for the easy\ scripts (dot-sourced; not run on its own). Hand-written, 2026-10-07.
$ErrorActionPreference = "Continue"
$Tools = Split-Path -Parent $PSScriptRoot                      # ...\psx-android-tools
. (Join-Path $Tools "tools\paths.ps1")                         # $DriveRoot, $ToolsCache, $FrameworkDir, Find-Adb ...
$Recomps = Join-Path $DriveRoot "recomps"
$Later = Join-Path $DriveRoot "recomps-later"
$WorkDir = $DefaultWorkDir
$Pwsh = Join-Path $ToolsCache "pwsh\pwsh.exe"
if (-not (Test-Path $Pwsh)) { $Pwsh = "pwsh" }
$Adb = Find-Adb
$Gh = Join-Path $ToolsCache "gh\bin\gh.exe"
Set-Location $Tools

function Title([string]$t) { Write-Host ""; Write-Host ("=" * 70) -ForegroundColor Cyan; Write-Host " $t" -ForegroundColor Cyan; Write-Host ("=" * 70) -ForegroundColor Cyan }
function Info([string]$t) { Write-Host $t }
function Good([string]$t) { Write-Host $t -ForegroundColor Green }
function Warn([string]$t) { Write-Host $t -ForegroundColor Yellow }
function Bad([string]$t) { Write-Host $t -ForegroundColor Red }

function Ask-YesNo([string]$q, [bool]$default = $false) {
    $hint = if ($default) { "[Y/n]" } else { "[y/N]" }
    $a = Read-Host "$q $hint"
    if (-not $a) { return $default }
    return $a.Trim().ToLower().StartsWith("y")
}

# PSX_GUI: run by PSX Manager (no console to wait in).
function Pause-End { if ($env:PSX_GUI) { return }; Write-Host ""; Read-Host "Done. Press Enter to close" | Out-Null }

# Package id of a game folder name, exactly as go.ps1 makes it.
function Get-Package([string]$game) { "com.psxrecomp." + (($game -replace '_recomp$', '').ToLower() -replace '[^a-z0-9]', '') }

# The games in recomps\ (the pipeline's list). -IncludeLater adds recomps-later\ (set-aside games).
function Get-Games([switch]$IncludeLater) {
    $g = @(Get-ChildItem $Recomps -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    if ($IncludeLater) { $g += @(Get-ChildItem $Later -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) }
    $g
}

# Numbered list; the user types numbers like "1,3,5", a range "2-4", or "all". Returns the chosen names.
function Pick-Games([string[]]$games, [string]$prompt = "Which games?") {
    if (-not $games.Count) { Warn "No games found."; return @() }
    for ($i = 0; $i -lt $games.Count; $i++) { Write-Host ("  {0,2}. {1}" -f ($i + 1), $games[$i]) }
    $a = Read-Host "$prompt (numbers like 1,3,5 or 2-4, or 'all'; Enter = cancel)"
    if (-not $a) { return @() }
    if ($a.Trim().ToLower() -eq "all") { return $games }
    $picked = @()
    foreach ($part in $a -split ",") {
        $p = $part.Trim()
        if ($p -match '^(\d+)-(\d+)$') { $picked += $games[([int]$Matches[1] - 1)..([int]$Matches[2] - 1)] }
        elseif ($p -match '^\d+$' -and [int]$p -ge 1 -and [int]$p -le $games.Count) { $picked += $games[[int]$p - 1] }
    }
    $picked | Select-Object -Unique
}

function Phone-Connected {
    $lines = @(& $Adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice$' })
    return ($lines.Count -gt 0)
}

function Need-Phone {
    if (Phone-Connected) { return $true }
    Warn "No phone found. Plug it in with USB, unlock it, and tap Allow on the 'USB debugging' prompt."
    Read-Host "Press Enter to check again" | Out-Null
    if (Phone-Connected) { return $true }
    Bad "Still no phone. (Settings > System > Developer options > USB debugging must be on.)"
    return $false
}

# Run go.ps1 for ONE game at a time (two at once crashed PowerShell on 2026-10-07).
function Run-Go([string]$game, [string[]]$extra) {
    $log = Join-Path $Tools ("logs\easy-{0}-{1}.log" -f $game, (Get-Date -Format "yyyyMMdd-HHmm"))
    Info "  building $game (log: $log; watch live with: pwsh -File watch.ps1)"
    & $Pwsh -NoProfile -File (Join-Path $Tools "go.ps1") -Game $game @extra *> $log
    $line = Get-Content $log | Where-Object { $_ -match "^\[.*\] $game : " } | Select-Object -Last 1
    if ($line -match ': ok') { Good "  $line" } elseif ($line) { Bad "  $line" } else { Bad "  $game : no result line (see $log)" }
    return $line
}
