# Start a NEW game from your own disc images: creates <drive>\recomp-backups\recomps\<Name>\ the way
# the existing recomps are laid out, so go.ps1 can port, generate, build and install it. Hand-written.
#   pwsh -File tools\new-recomp.ps1 -Name ff7_recomp -Disc "D:\games\FF7\Final Fantasy VII (USA) (Disc 1).cue"
#   several discs: list every disc's .cue in order, separated by commas:
#   pwsh -File tools\new-recomp.ps1 -Name ff7_recomp -Disc "...\(Disc 1).cue","...\(Disc 2).cue","...\(Disc 3).cue"
# Then:  pwsh -File go.ps1 -Game ff7_recomp            (first build; Claude takes over at first boot)
# What it does:
#  1. copies every disc's .cue and the track files it names into recomps\<Name>\disc\ (originals untouched);
#  2. runs the framework's disc probe (psxrecomp\tools\new_project_layout\probe_disc.py) on Disc 1:
#     game.toml (serial, boot program, entry point, sizes, disc list, digests of YOUR image, so modified
#     discs are fine), seeds\ghidra_funcs.txt (first list of code entry points) and the boot program;
#  3. adds the sections the Android port expects if the probe did not write them ([runtime], [controller]).
# The C code itself is generated later by go.ps1 (its REGEN step). Never overwrites an existing game.
# Disc file names often contain [ ] (wildcards to PowerShell): every path here is used with -LiteralPath.
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string[]]$Disc,
    [int]$Players = 1
)
. (Join-Path $PSScriptRoot "paths.ps1")
if ($Name -notmatch '^[a-z0-9_]+_recomp$') { Write-Host "FAIL: -Name must look like ff7_recomp (lowercase, ends in _recomp)"; exit 1 }
$py = Find-Python
if (-not $py) { Write-Host "FAIL: no Python (run tools\setup.ps1)"; exit 1 }
$probe = Join-Path $FrameworkDir "tools\new_project_layout\probe_disc.py"
$dest = Join-Path $DriveRoot "recomps\$Name"
if (Test-Path $dest) { Write-Host "FAIL: $dest already exists (pick another name, or ask Claude)"; exit 1 }

# 1. Check every disc first (nothing is created if a file is missing), then copy.
$copies = @()
foreach ($cue in $Disc) {
    if (-not (Test-Path -LiteralPath $cue -PathType Leaf) -or $cue -notmatch '\.cue$') { Write-Host "FAIL: not a .cue file: $cue"; exit 1 }
    $dir = Split-Path $cue -Parent
    $copies += (Get-Item -LiteralPath $cue).FullName
    foreach ($line in Get-Content -LiteralPath $cue) {
        if ($line -match '^\s*FILE\s+"([^"]+)"' -or $line -match '^\s*FILE\s+(\S+)') {
            $track = Join-Path $dir $Matches[1]
            if (-not (Test-Path -LiteralPath $track)) { Write-Host "FAIL: $cue needs $($Matches[1]), which is not next to it"; exit 1 }
            $copies += (Get-Item -LiteralPath $track).FullName
        }
    }
}
New-Item -ItemType Directory -Force (Join-Path $dest "disc"), (Join-Path $dest "seeds"), (Join-Path $dest "saves") | Out-Null
$total = ($copies | ForEach-Object { (Get-Item -LiteralPath $_).Length } | Measure-Object -Sum).Sum
Write-Host ("Copying {0} file(s), {1:N0} MB, into {2}\disc ..." -f $copies.Count, ($total / 1MB), $dest)
foreach ($f in $copies | Select-Object -Unique) { Copy-Item -LiteralPath $f (Join-Path $dest "disc") }

# 2. Probe Disc 1 (paths relative to the game folder, as in every recomp's game.toml).
$cues = @($Disc | ForEach-Object { "disc/" + (Split-Path $_ -Leaf) })
$probeArgs = @($probe, $cues[0], "--write-game-toml", "game.toml", "--write-seeds", "seeds/ghidra_funcs.txt",
               "--write-catalog", "catalog_identity.json", "--json-out", "disc_probe.json",
               "--disc-rel", $cues[0], "--out-dir", "disc", "--write-boot-exe", "disc", "--players", "$Players")
if ($cues.Count -gt 1) {
    $list = Join-Path $dest "extra_discs.txt"
    Set-Content $list ($cues | Select-Object -Skip 1) -Encoding utf8NoBOM
    $probeArgs += @("--extra-disc-list", $list)
}
Push-Location $dest
& $py @probeArgs *> (Join-Path $dest "probe.log")
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0 -or -not (Test-Path (Join-Path $dest "game.toml"))) {
    Write-Host "FAIL: the disc probe failed (exit $code). Last lines of $dest\probe.log:"
    Get-Content (Join-Path $dest "probe.log") -Tail 20 | ForEach-Object { Write-Host "  $_" }
    Write-Host "The copied discs are in $dest\disc. Bring probe.log to Claude."
    exit 1
}

# 3. Sections the Android port reads (only added when missing).
$toml = Get-Content (Join-Path $dest "game.toml") -Raw
$add = ""
if ($toml -notmatch '(?m)^\[runtime\]') { $add += "`n[runtime]`nmemcard_dir = `"saves`"`n" }
if ($toml -notmatch '(?m)^\[controller\]') { $add += "`n[controller]`ndefault_mode = `"digital`"`n" }
if ($add) { Add-Content (Join-Path $dest "game.toml") $add -Encoding utf8NoBOM }

# 4. A game this repository already knows (games\<Name>\, e.g. after cloning psx-android on another PC):
#    use ITS tuned game.toml, seeds, tools and play captures instead of the fresh probe's first guess.
#    Only the disc file names come from the user's own copy (theirs may be named differently).
$known = Join-Path $RepoRoot "games\$Name"
if (Test-Path (Join-Path $known "game.toml")) {
    $ours = Get-Content (Join-Path $known "game.toml") -Raw
    $probeId = if ($toml -match '(?m)^id\s*=\s*"([^"]+)"') { $Matches[1] } else { "" }
    $ourId = if ($ours -match '(?m)^id\s*=\s*"([^"]+)"') { $Matches[1] } else { "" }
    if ($probeId -and $ourId -and $probeId -ne $ourId) {
        Write-Host "FAIL: this disc is $probeId, but $Name is set up for $ourId (another region or version)."
        Write-Host "      Use the $ourId disc, or remove $dest and pick another -Name to start from scratch."
        exit 1
    }
    # [game]: drop the repo's disc/discs lines, put this PC's disc names right after `exe =`.
    $discLines = "discs = [`n" + (($cues | ForEach-Object { "  `"$_`"," }) -join "`n") + "`n]`ndisc = `"$($cues[0])`""
    $ours = [regex]::Replace($ours, '(?ms)^discs\s*=\s*\[.*?^\]\s*\r?\n', '')
    $ours = [regex]::Replace($ours, '(?m)^disc\s*=\s*".*"\s*\r?\n', '')
    $ours = [regex]::Replace($ours, '(?m)^(exe\s*=\s*".*")\s*$', { param($m) $m.Groups[1].Value + "`n" + $discLines }, 1)
    Set-Content (Join-Path $dest "game.toml") $ours -Encoding utf8NoBOM -NoNewline
    foreach ($d in "seeds", "tools") {
        $s = Join-Path $known $d
        if (Test-Path $s) { Copy-Item $s $dest -Recurse -Force }
    }
    foreach ($f in "aot_exclude.txt", "play_captures.json", "README.md") {
        $s = Join-Path $known $f
        if (Test-Path $s) { Copy-Item $s $dest -Force }
    }
    $toml = $ours
    Write-Host "Using this repository's setup for $Name (games\$Name): tuned config, seeds, tools, play captures."
}

$id = if ($toml -match '(?m)^id\s*=\s*"([^"]+)"') { $Matches[1] } else { "?" }
$exe = if ($toml -match '(?m)^exe\s*=\s*"([^"]+)"') { $Matches[1] } else { "?" }
$seeds = @(Get-Content (Join-Path $dest "seeds\ghidra_funcs.txt") | Where-Object { $_ -match '^0x' }).Count
Write-Host "OK: new game $Name in $dest"
Write-Host "    id $id, boot program $exe, $($cues.Count) disc(s), $seeds code entry points to start from"
Write-Host "Next: pwsh -File go.ps1 -Game $Name"
exit 0
