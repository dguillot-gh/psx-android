# Pre-compile a game's overlay code for the phone ("AOT overlays"). Hand-written.
#   pwsh -File tools\speed.ps1 -GameDir <drive>\recomp-backups\android-recomp\tomba2_recomp [-Package com.psxrecomp.tomba2] [-NoPhone]
# PS1 games load extra code from the disc while they run. Without this step that code runs on the
# slow interpreter. Steps (everything under <GameDir>\build-android-overlays):
#  1. disc_captures.json : code found on the disc itself (extract_generic.py, seconds, no playing).
#     game_captures.json : the game's own extractor, if it has one (<GameDir>\tools\overlay_extract.py; FF7).
#  2. play_captures.json : code the phone recorded while the game was played (pulled read-only,
#     merged with earlier pulls). This is how games with unusual disc layouts get covered.
#  3. aot_all.json       : both merged; split into one group per CPU core (par\gNN.json).
#  4. compile_overlays.py per group, in parallel, with the NDK's clang (minutes to ~30 min).
#     Heartbeat every minute in progress.log.
#  5. cache\<game id>\gcc\linux-arm64\ : the result. The app build bundles it (build.ps1 -Play).
# Skips the compile when the captures haven't changed since the last good compile.
# Exit 0 = cache ready (or nothing to compile), 1 = failed.
param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [string]$Package = "",
    [int]$Groups = 0,
    [switch]$NoPhone
)
. (Join-Path $PSScriptRoot "paths.ps1")
$tools = $PSScriptRoot
$progress = Join-Path (Split-Path -Parent $PSScriptRoot) "progress.log"
function Say([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $progress -Value $line
}

$py = Find-Python
$ndk = Find-Ndk
if (-not $py) { Say "SPEED: FAIL no Python (run tools\setup.ps1)"; exit 1 }
if (-not $ndk) { Say "SPEED: FAIL no NDK $NdkVersion (run tools\setup.ps1)"; exit 1 }
$tomlIn = Join-Path $GameDir "android\app\src\main\assets\game.toml.in"
if (-not (Test-Path $tomlIn)) { Say "SPEED: FAIL no Android app in $GameDir (port it first)"; exit 1 }
$gameId = if ((Get-Content $tomlIn -Raw) -match '(?m)^id\s*=\s*"([^"]+)"') { $Matches[1] } else { "" }
if (-not $gameId) { Say "SPEED: FAIL no game id in $tomlIn"; exit 1 }
if (-not $Package) { $Package = "com.psxrecomp." + (((Split-Path $GameDir -Leaf) -replace '_recomp$', '').ToLower() -replace '[^a-z0-9]', '') }
if ($Groups -le 0) {
    # One group per core, leaving two for the PC; 2..12. (Plain operators: works in constrained PowerShell too.)
    $Groups = [int]$env:NUMBER_OF_PROCESSORS - 2
    if ($Groups -gt 12) { $Groups = 12 }
    if ($Groups -lt 2) { $Groups = 2 }
}

$recompiler = Join-Path $GameDir "psxrecomp\recompiler\build-mingw\psxrecomp-game.exe"
$W = Join-Path $GameDir "build-android-overlays"
New-Item -ItemType Directory -Force $W | Out-Null
$disc = Join-Path $W "disc_captures.json"
$play = Join-Path $W "play_captures.json"
$all = Join-Path $W "aot_all.json"

# 1. From the disc. A failure here is not fatal: play captures may still cover the game.
Push-Location $GameDir
& $py psxrecomp\tools\aot_overlay_spike\extract_generic.py --game-toml game.toml --recompiler $recompiler --out $disc --tmp (Join-Path $W "tmp") *> (Join-Path $W "extract.log")
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { Say "SPEED: NOTE finding code on the disc failed (see $W\extract.log); using play captures only"; Remove-Item $disc -ErrorAction SilentlyContinue }

# 1b. A game's OWN extractor, when it has one (<GameDir>\tools\overlay_extract.py, e.g. FF7's, which
#     unpacks FF7's compressed modules and checks each one at its load address). Same interface:
#     --game-toml game.toml --out <file> --framework psxrecomp.
$gameX = Join-Path $GameDir "tools\overlay_extract.py"
$gameCaps = Join-Path $W "game_captures.json"
if (Test-Path $gameX) {
    Push-Location $GameDir
    & $py $gameX --game-toml game.toml --out $gameCaps --framework psxrecomp *> (Join-Path $W "game_extract.log")
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -eq 0) { Say ("SPEED: game extractor: " + ((Get-Content (Join-Path $W "game_extract.log") | Select-String 'module\(s\) kept' | Select-Object -Last 1).Line)) }
    else { Say "SPEED: NOTE the game's own extractor failed (see $W\game_extract.log)"; Remove-Item $gameCaps -ErrorAction SilentlyContinue }
}

# 2. From play on the phone (read-only pull; merged with what earlier runs pulled).
if (-not $NoPhone) {
    $new = Join-Path $W "play_new.json"
    pwsh -NoProfile -File (Join-Path $tools "phone.ps1") -Action pull-captures -Package $Package -To $new | Out-Host
    if ($LASTEXITCODE -eq 0) { & $py (Join-Path $tools "captures.py") merge --out $play $play $new | Out-Host }
    Remove-Item $new -ErrorAction SilentlyContinue
}

# 3. Merge, and stop early when there is nothing new.
& $py (Join-Path $tools "captures.py") merge --out $all $disc $gameCaps $play | Out-Host
$count = @(& $py -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" $all)[0]
$digest = @(& $py (Join-Path $tools "captures.py") digest $all)[0]
$hash = (@(& $recompiler --codegen-hash) -join "").Trim()
$cache = Join-Path $W "cache\$gameId\gcc\linux-arm64"
$stamp = Join-Path $W "compiled.digest"
Say "SPEED: $count piece(s) of game code to pre-compile (disc + play), codegen $hash"
if ([int]$count -eq 0) { Say "SPEED: nothing found yet. Play the game a little on the phone, then run again."; exit 0 }
$have = @(Get-ChildItem $cache -Directory -Filter "cg*_$($hash)_*" -ErrorAction SilentlyContinue)
if ($have.Count -and (Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq "$digest $hash")) {
    Say "SPEED: already pre-compiled (no new code since the last run)"; exit 0
}

# The phone-side config the shards are keyed to (the app's game.toml.in with a placeholder disc).
$phoneToml = Join-Path $W "phone-game.toml"
$lines = Get-Content $tomlIn | ForEach-Object {
    if ($_ -match '^\s*@@DISC1@@') { '  "disc/game.cue",' } elseif ($_ -match '@@DISC\d+@@') { } else { $_ } }
Set-Content -Path $phoneToml -Value $lines -Encoding utf8NoBOM

# 4. Compile, one process per group.
$par = Join-Path $W "par"
Get-ChildItem $par -Directory -Filter "out_g*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
& $py (Join-Path $tools "captures.py") split --in $all --groups $Groups --outdir $par | Out-Host
$procs = @()
foreach ($g in Get-ChildItem $par -Filter "g??.json" | Sort-Object Name) {
    $n = $g.BaseName
    $a = @("psxrecomp\tools\compile_overlays.py", "--captures", "`"$($g.FullName)`"", "--game-toml", "`"$phoneToml`"",
           "--recompiler", "`"$recompiler`"", "--runtime-include", "psxrecomp\runtime\include",
           "--out-dir", "`"$(Join-Path $par "out_$n")`"", "--gcc", "`"$(Join-Path $ndk 'bin\clang.exe')`"",
           "--target-os", "android", "--target-arch", "arm64", "--android-sysroot", "`"$(Join-Path $ndk 'sysroot')`"",
           "--cps", "--jobs", "1")
    $procs += Start-Process -FilePath $py -ArgumentList $a -WorkingDirectory $GameDir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $par "$n.log") -RedirectStandardError (Join-Path $par "$n.err.log")
}
Say "SPEED: compiling in $($procs.Count) parallel group(s) (minutes to about 30 min)"
$started = Get-Date
while (@($procs | Where-Object { -not $_.HasExited }).Count) {
    Start-Sleep -Seconds 60
    $left = @($procs | Where-Object { -not $_.HasExited }).Count
    $so = @(Get-ChildItem $par -Recurse -Filter *.so -ErrorAction SilentlyContinue).Count
    Say ("SPEED: still compiling, {0} min so far: {1} of {2} groups finished, {3} pieces compiled" -f [int]((Get-Date) - $started).TotalMinutes, ($procs.Count - $left), $procs.Count, $so)
}
$ok = 0; $bad = 0
foreach ($l in Get-ChildItem $par -Filter "g??.log") {
    foreach ($r in Select-String -Path $l.FullName -Pattern 'PSX_SHARD_RESULT ok=(\d+) failed=(\d+)') {
        $ok += [int]$r.Matches[0].Groups[1].Value; $bad += [int]$r.Matches[0].Groups[2].Value
    }
}

# 5. Merge the groups into the cache the app build bundles (rebuilt fresh each time).
if (Test-Path (Join-Path $W "cache\$gameId")) { Remove-Item (Join-Path $W "cache\$gameId") -Recurse -Force }
New-Item -ItemType Directory -Force $cache | Out-Null
foreach ($o in Get-ChildItem $par -Directory -Filter "out_g*") {
    $src = Join-Path $o.FullName "$gameId\gcc\linux-arm64"
    if (Test-Path $src) { robocopy $src $cache /E /XF ".*" /NFL /NDL /NJH /NJS | Out-Null }
}
$so = @(Get-ChildItem $cache -Recurse -Filter *.so).Count
if ($so -eq 0) { Say "SPEED: FAIL nothing compiled ($bad failed; logs in $par)"; exit 1 }
Set-Content $stamp "$digest $hash"
Get-ChildItem $par -Directory -Filter "out_g*" | Remove-Item -Recurse -Force   # scratch, ~1-2 GB
$note = if ($bad) { ", $bad failed (those parts stay on the interpreter; logs in $par)" } else { "" }
Say "SPEED: done, $so compiled pieces ready ($ok ok$note)"
exit 0
