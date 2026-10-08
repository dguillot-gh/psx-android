# The build that GitHub's "Build APK" button runs on the build PC (the self-hosted runner, see RUNNER.md).
# Hand-written, 2026-10-08. Not for daily use on your own PC (use go.ps1 or the easy menu there).
#   pwsh -File tools\ci-build.ps1 -Game tomba2_recomp [-Speed] [-Release] [-Clean]
# 1. Brings this copy up to date from GitHub: the scripts (psx-android), the engine (psxrecomp-android)
#    and each game's setup (the <game>-android repositories, copied into recomps\<game>; the disc
#    names in game.toml stay this PC's own). Discs never move: they are already on this PC.
# 2. Rebuilds the recompiler when the engine update changed it.
# 3. go.ps1 -NoPhone -NoTasks (no phone, no local model), at low priority so the PC stays usable.
# 4. -Release: one Release per game in the private psx-android-builds, uploaded as soon as that game is built.
# -Clean: removes each game's work folder afterwards (frees 1-5 GB per game; the next build starts from scratch).
# Signing: the workflow puts the shared key in a temporary file and passes it as PSX_KEYSTORE (build.ps1).
param(
    [Parameter(Mandatory = $true)][string]$Game,
    [switch]$Speed,
    [int]$SpeedMinutes = 0,
    [switch]$Release,
    [switch]$Clean,          # delete each game's work folder after its build (little disk space)
    [switch]$NoUpdate
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")
$tools = Split-Path -Parent $PSScriptRoot
$recomps = Join-Path $DriveRoot "recomps"
$gh = Join-Path $ToolsCache "gh\bin\gh.exe"
$started = Get-Date
function Step([string]$m) { Write-Host ""; Write-Host "== $m" }

# Low priority: Windows gives the build only what other programs leave over. Child processes
# (pwsh, Gradle, clang) inherit it.
try { (Get-Process -Id $PID).PriorityClass = "BelowNormal" } catch { Write-Host "NOTE: could not lower the priority" }
# The portable PowerShell on the drive, for go.ps1's own "pwsh" calls (the PC may have none installed).
$pwshDir = Join-Path $ToolsCache "pwsh"
if (Test-Path (Join-Path $pwshDir "pwsh.exe")) { $env:PATH = "$pwshDir;$env:PATH" }
# git: the PC's own, else the portable MinGit setup-runner.ps1 puts on the drive.
$minGit = Join-Path $ToolsCache "mingit\cmd"
if (-not (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path $minGit)) { $env:PATH = "$minGit;$env:PATH" }
# git reaches the private repositories through the GitHub CLI's sign-in on this PC (setup-runner.ps1).
$cred = "credential.helper=!'" + ($gh -replace '\\', '/') + "' auth git-credential"
function Git-Must([string]$dir) {
    & git -C $dir -c credential.helper= -c $cred @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed in $dir" }
}

if (-not $NoUpdate) {
    # --- 1a. Scripts --------------------------------------------------------------------------------------
    Step "Updating the games list (psx-android submodules)"
    # (The scripts themselves were updated by the workflow's step before this one.)
    Git-Must $tools submodule update -q --init --force -- games
    # --- 1b. Engine -----------------------------------------------------------------------------------------
    Step "Updating the engine (psxrecomp-android, branch android)"
    $fw = Join-Path $DriveRoot "framework\psxrecomp"
    $before = (& git -C $fw rev-parse HEAD).Trim()
    Git-Must $fw fetch -q origin android
    Git-Must $fw merge -q --ff-only origin/android
    $after = (& git -C $fw rev-parse HEAD).Trim()
    if ($before -ne $after) {
        Write-Host "Engine: $($before.Substring(0,8)) -> $($after.Substring(0,8))"
        $changed = @(& git -C $fw diff --name-only $before $after -- recompiler)
        if ($changed.Count) {
            Step "The recompiler changed: rebuilding it (5-10 min)"
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot "build-recompiler.ps1") -Force
            if ($LASTEXITCODE -ne 0) { throw "could not rebuild the recompiler" }
        }
    } else { Write-Host "Engine: already up to date ($($after.Substring(0,8)))" }
    # --- 1c. Each game's setup: games\<name> (its repository) -> recomps\<name> --------------------------
    # The reverse of export-games.ps1. game.toml keeps this PC's disc file names (disc / discs lines).
    Step "Updating each game's setup from its repository"
    foreach ($src in Get-ChildItem (Join-Path $tools "games") -Directory) {
        $dest = Join-Path $recomps $src.Name
        if (-not (Test-Path (Join-Path $dest "game.toml"))) { continue }   # not on this PC (no disc here)
        $theirs = Join-Path $src.FullName "game.toml"
        if (Test-Path $theirs) {
            $ours = Get-Content (Join-Path $dest "game.toml") -Raw
            $new = Get-Content $theirs -Raw
            # Only inside [game] (other sections, like [prepare_disc], have their own discs lists).
            $sec = '(?ms)^\[game\][ \t]*\r?\n.*?(?=^\[|\z)'
            $ourGame = [regex]::Match($ours, $sec).Value
            $discs = [regex]::Match($ourGame, '(?ms)^discs\s*=\s*\[.*?^\]\s*\r?\n').Value + [regex]::Match($ourGame, '(?m)^disc\s*=\s*".*"\s*\r?\n').Value
            $theirGame = [regex]::Match($new, $sec)
            if ($ourGame -and $discs -and $theirGame.Success) {
                $g2 = [regex]::Replace($theirGame.Value, '(?ms)^discs\s*=\s*\[.*?^\]\s*\r?\n', '')
                $g2 = [regex]::Replace($g2, '(?m)^disc\s*=\s*".*"\s*\r?\n', '')
                $g2 = ([regex]'(?m)^exe\s*=\s*".*"\s*\r?\n').Replace($g2, { param($m) $m.Value + $discs }, 1)
                $new = $new.Substring(0, $theirGame.Index) + $g2 + $new.Substring($theirGame.Index + $theirGame.Length)
            } else { $new = $ours }   # unexpected layout: keep this PC's file
            if ($new -ne $ours) { Set-Content (Join-Path $dest "game.toml") $new -Encoding utf8NoBOM -NoNewline; Write-Host "  $($src.Name): game.toml updated" }
        }
        foreach ($f in "aot_exclude.txt", "extra_discs.txt", "VERSION", "CMakeLists.txt", "build.ps1", "catalog_identity.json", "disc_probe.json", "play_captures.json") {
            $s = Join-Path $src.FullName $f
            if (Test-Path $s) { Copy-Item $s $dest -Force }
        }
        foreach ($d in "seeds", "tools") {
            $s = Join-Path $src.FullName $d
            if (Test-Path $s) { Copy-Item $s $dest -Recurse -Force }
        }
        # Play captures go where the speed pre-compile reads them, when the repository's copy is newer.
        $caps = Join-Path $src.FullName "play_captures.json"
        $work = Join-Path $DefaultWorkDir "$($src.Name)\build-android-overlays\play_captures.json"
        if ((Test-Path $caps) -and (Test-Path (Split-Path $work)) -and
            (-not (Test-Path $work) -or (Get-Item $caps).Length -gt (Get-Item $work).Length)) { Copy-Item $caps $work -Force }
    }
}

# --- 3. Build -----------------------------------------------------------------------------------------------
# Discs on a NAS (PSX_DISCS, set in the runner's .env by setup-runner.ps1): <share>\<game>\ holds what
# recomps\<game>\disc\ holds on the drive (the .cue/.bin plus the files read from it). Each game's disc
# is copied in just before its build and removed right after, so only one disc is on this PC at a time.
# Without PSX_DISCS the discs are expected in recomps\<game>\disc\ as on the drive.
$games = if ($Game -eq "all") { @(Get-ChildItem $recomps -Directory | ForEach-Object { $_.Name }) } else { @($Game -split "," | ForEach-Object { $_.Trim() }) }
$nas = $env:PSX_DISCS
if ($nas -and -not (Test-Path -LiteralPath $nas)) { throw "PSX_DISCS is set to $nas, but this PC can't reach it" }
$goExit = 0
$missing = @()
$stage = Join-Path $ToolsCache ("ci-apks-" + $started.ToString("yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force $stage | Out-Null

# -Release: ONE Release per game, uploaded as soon as that game is built (an "all" run doesn't wait for
# the last game). Title = the game's name + date, tag = <game>-<yyyyMMdd-HHmm>. RELEASE_TOKEN is the
# workflow's own token (it may write releases of psx-android-builds only); git above keeps using this PC's
# sign-in. The Releases stay in the PRIVATE psx-android-builds: the APKs contain game code.
$releaseRepo = if ($env:RELEASE_REPO) { $env:RELEASE_REPO } else { "dguillot-gh/psx-android-builds" }
$buildInfo = @(
    "Built on the build PC from its own disc$(if ($Speed) { ', with the speed pre-compile' }). Private: contains game code, don't share.",
    "",
    "Engine: $((& git -C (Join-Path $DriveRoot 'framework\psxrecomp') log -1 --format='%h %s'))",
    "Scripts: $((& git -C $tools log -1 --format='%h %s'))"
) -join "`n"
$published = @(); $publishFailed = @()
function Publish-Apk([string]$g, [string]$apkPath) {
    $title = $g -replace '_recomp$', ''
    $toml = Join-Path $recomps "$g\game.toml"
    if ((Test-Path $toml) -and ((Get-Content $toml -Raw) -match '(?m)^name\s*=\s*"([^"]+)"')) { $title = $Matches[1] -replace '(\s*\([^)]*\))+$', '' }
    $when = Get-Date
    $tag = (($g -replace '_recomp$', '') -replace '_', '-') + "-" + $when.ToString("yyyyMMdd-HHmm")
    $name = "$title - " + $when.ToString("yyyy-MM-dd HH:mm") + $(if ($Speed) { " (speed)" } else { "" })
    Step "Uploading $g to GitHub Release '$name'"
    $env:GH_TOKEN = $env:RELEASE_TOKEN
    & $gh release create $tag --repo $releaseRepo --title $name --notes $buildInfo $apkPath
    $code = $LASTEXITCODE
    Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue
    if ($code -eq 0) { $script:published += $name } else { $script:publishFailed += $g; Write-Host "UPLOAD FAILED for $g (gh exit $code)" }
}

foreach ($g in $games) {
    # Two places read the disc: recomps\<game>\disc (a first port copies it from there) and the game's
    # work folder android-recomp\<game>\disc (code generation and the speed pre-compile read that one).
    $discDirs = @((Join-Path $recomps "$g\disc"))
    if (Test-Path (Join-Path $DefaultWorkDir $g)) { $discDirs += Join-Path $DefaultWorkDir "$g\disc" }
    $fromNas = $nas -and -not (Test-Path (Join-Path $discDirs[-1] "*.cue"))
    if ($fromNas) {
        $src = Join-Path $nas $g
        if (-not (Test-Path -LiteralPath $src)) { Write-Host "SKIP $g : no disc in $src"; $goExit = 1; $missing += $g; continue }
        Step "Copying $g's disc from the NAS"
        $ok = $true
        foreach ($d in $discDirs) {
            robocopy $src $d /E /NFL /NDL /NJH /NJS /R:3 /W:10 | Out-Null
            if ($LASTEXITCODE -ge 8) { $ok = $false }
        }
        if (-not $ok) { Write-Host "SKIP $g : copying the disc failed"; $goExit = 1; $discDirs | ForEach-Object { Remove-Item -LiteralPath $_ -Recurse -Force -ErrorAction SilentlyContinue }; continue }
    }
    try {
        Step "Building $g$(if ($Speed) { ' (with the speed pre-compile)' })"
        $goArgs = @("-NoProfile", "-File", (Join-Path $tools "go.ps1"), "-Game", $g, "-NoPhone", "-NoTasks")
        if ($Speed) { $goArgs += "-Speed" }
        if ($SpeedMinutes -gt 0) { $goArgs += @("-SpeedMinutes", "$SpeedMinutes") }
        & pwsh @goArgs
        if ($LASTEXITCODE -ne 0) { $goExit = $LASTEXITCODE }
        # Keep this run's APK aside (the work folder may be removed below).
        $apk = Get-ChildItem (Join-Path $DefaultWorkDir "$g\apk") -Filter *.apk -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $started } | Sort-Object LastWriteTime | Select-Object -Last 1
        if ($apk) {
            Copy-Item $apk.FullName $stage
            if ($Release) { Publish-Apk $g $apk.FullName }
        } else { $missing += $g }
    } finally {
        # A first port made the work folder (and its disc copy) during this build: remove that one too.
        if ($fromNas) {
            @($discDirs + (Join-Path $DefaultWorkDir "$g\disc")) | Select-Object -Unique |
                ForEach-Object { Remove-Item -LiteralPath $_ -Recurse -Force -ErrorAction SilentlyContinue }
        }
        # -Clean: free the space. The next build of this game starts from scratch (port, code, compile).
        if ($Clean) { Remove-Item -LiteralPath (Join-Path $DefaultWorkDir $g) -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
# go.ps1 also keeps a copy of every APK in apks\<date>; on the build PC the Release is the copy.
Get-ChildItem (Join-Path $DriveRoot "apks") -Recurse -Filter *.apk -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $started } | Remove-Item -Force -ErrorAction SilentlyContinue

$apks = @(Get-ChildItem $stage -Filter *.apk)
Step "Built $($apks.Count) of $($games.Count) APK(s)"
$apks | ForEach-Object { Write-Host "  $($_.Name)  ($([math]::Round($_.Length / 1MB)) MB)" }
if ($missing.Count) { Write-Host "  no APK for: $($missing -join ', ') (see the log above)" }

# --- 4. Summary -------------------------------------------------------------------------------------------------
if ($Release) {
    if ($published.Count) { Write-Host "Released (github.com/$releaseRepo/releases):"; $published | ForEach-Object { Write-Host "  $_" } }
    if ($publishFailed.Count) { Write-Host "Upload failed for: $($publishFailed -join ', ')" }
}
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
if ($goExit -ne 0 -or $missing.Count -or $publishFailed.Count) { exit 1 }
exit 0
