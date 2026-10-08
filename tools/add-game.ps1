# What GitHub's "Add game" button runs on the build PC (psx-android-builds, see RUNNER.md "A new game"):
# sets up a NEW game from its discs on the NAS, no USB drive needed. Hand-written, 2026-10-08.
#   pwsh -File tools\add-game.ps1 -Game tomba3_recomp [-DryRun]
# Before: the game's .cue + .bin files (every disc) in <NAS>\psx-discs\<game>\ (PSX_DISCS on the build PC).
#  1. new-recomp.ps1 makes recomps\<game> from those discs (disc probe: game.toml, seeds, boot program).
#  2. The files read from the disc (e.g. SLUS_xxx.xx) go next to the .cue/.bin on the NAS, so that folder is
#     what ci-build.ps1 copies in for a build; the local disc copy is then removed (little disk on the VM).
#  3. export-games.ps1 -Game: games\<game> = the game's own files (no disc, no PC paths), checked.
#  4. Creates the PUBLIC repository dguillot-gh/<short>-android, pushes it, adds it to psx-android (games\<game>).
#  5. Adds the game to the Build APK list (.github/workflows/build-apk.yml in psx-android-builds).
# -DryRun: steps 1-3 and a preview of 5; nothing on GitHub. A later run without -DryRun carries on from there,
# and so does a run after one that stopped halfway (recomps\<game>\.add-game-pending). Any other existing
# game of that name is refused. git and gh use this PC's GitHub sign-in (the workflow's own token can't
# create or write other repositories); changing the Build APK list also needs its "workflow" permission.
param(
    [Parameter(Mandatory = $true)][string]$Game,
    [string]$Nas = $env:PSX_DISCS,     # the NAS's psx-discs folder (one subfolder per game)
    [switch]$DryRun,
    [string]$WorkflowFile = ""         # tests: change this local copy of build-apk.yml instead of GitHub's
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")
$tools = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $DriveRoot "recomps\$Game"
$pending = Join-Path $dest ".add-game-pending"
$exp = Join-Path $tools "games\$Game"
$owner = "dguillot-gh"
$repoName = (($Game -replace '_recomp$', '') -replace '_', '-') + "-android"
$repoUrl = "https://github.com/$owner/$repoName.git"
$buildsRepo = "$owner/psx-android-builds"   # PRIVATE (the runner and the APKs): never a public one
$gh = Join-Path $ToolsCache "gh\bin\gh.exe"
$pwshExe = (Get-Process -Id $PID).Path
function Step([string]$m) { Write-Host ""; Write-Host "== $m" }
function Fail([string]$m) { Write-Host ""; Write-Host "STOPPED: $m"; exit 1 }
$minGit = Join-Path $ToolsCache "mingit\cmd"
if (-not (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path $minGit)) { $env:PATH = "$minGit;$env:PATH" }
$cred = "credential.helper=!'" + ($gh -replace '\\', '/') + "' auth git-credential"
function Git-Must([string]$dir) {
    & git -C $dir -c credential.helper= -c $cred -c user.name=psx -c user.email=psx@local @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed in $dir" }
}

# Puts $name in the `game:` choice list of build-apk.yml: "all" stays first, the new one goes before the
# first name that sorts after it. Returns $null when the name is already there.
function Add-ToGameList([string]$yml, [string]$name) {
    $nl = if ($yml -match "`r`n") { "`r`n" } else { "`n" }
    $lines = [Collections.Generic.List[string]]($yml -split '\r?\n')
    $g = $lines.FindIndex({ param($l) $l -match '^\s+game:\s*$' })
    if ($g -lt 0) { throw "build-apk.yml: no 'game:' input" }
    $o = $lines.FindIndex($g, { param($l) $l -match '^\s+options:\s*$' })
    if ($o -lt 0) { throw "build-apk.yml: the 'game:' input has no options list" }
    $at = -1; $indent = ""; $i = $o + 1
    for (; $i -lt $lines.Count -and $lines[$i] -match '^(\s+)- (\S+)\s*$'; $i++) {
        $indent = $Matches[1]
        if ($Matches[2] -eq $name) { return $null }
        if ($at -lt 0 -and $Matches[2] -ne "all" -and [string]::CompareOrdinal($Matches[2], $name) -gt 0) { $at = $i }
    }
    if (-not $indent) { throw "build-apk.yml: the 'game:' options list is empty" }
    if ($at -lt 0) { $at = $i }
    $lines.Insert($at, "$indent- $name")
    return $lines -join $nl
}

# --- Checks first: nothing is changed when one fails ---------------------------------------------------------
Step "Checking"
if ($Game -notmatch '^[a-z0-9_]+_recomp$') { Fail "the name must look like tomba3_recomp: lowercase letters, digits and _, ending in _recomp." }
$resume = Test-Path -LiteralPath $pending
$modules = Join-Path $tools ".gitmodules"
$inPsxAndroid = (Test-Path $modules) -and ((Get-Content $modules -Raw) -match "(?m)^\s*path\s*=\s*games/$Game\s*$")
if (-not $resume) {
    if ($inPsxAndroid -or (Test-Path -LiteralPath $exp)) { Fail "$Game already exists in psx-android (games\$Game). Pick another name, or build it with Build APK." }
    foreach ($p in $dest, (Join-Path $DriveRoot "recomps-later\$Game")) {
        if (Test-Path -LiteralPath $p) { Fail "$Game already exists on this PC ($p). Pick another name, or build it with Build APK." }
    }
}
if (-not $Nas) { Fail "PSX_DISCS is not set on this PC (the NAS's psx-discs folder: RUNNER.md, one-time setup)." }
if (-not (Test-Path -LiteralPath $Nas)) { Fail "can't reach $Nas (NAS off, or its password not saved on this PC: RUNNER.md step 2)." }
$src = Join-Path $Nas $Game
if (-not (Test-Path -LiteralPath $src -PathType Container)) {
    Fail "there is no folder $src. Make it on the NAS, put the game's .cue and .bin files in it (every disc), then press Add game again."
}
# Disc order = name order, numbers compared as numbers ("Disc 2" before "Disc 10").
$cues = @(Get-ChildItem -LiteralPath $src -Filter *.cue -File |
    Sort-Object { [regex]::Replace($_.Name, '\d+', { param($m) $m.Value.PadLeft(6, '0') }) })
if (-not $cues.Count) { Fail "no .cue file in $src. Put the game's .cue and .bin files there (every disc)." }
$repoExists = $false
if (-not $DryRun) {
    if (-not (Test-Path $gh)) { Fail "the GitHub CLI is missing ($gh)." }
    $auth = (& $gh auth status 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { Fail "this PC is not signed in to GitHub. Once, in PowerShell on this PC: & '$gh' auth login --web" }
    if ($auth -notmatch "'workflow'") {
        Fail ("this PC's GitHub sign-in can't change the Build APK list yet. Once, in PowerShell on this PC:`n" +
              "  & '$gh' auth refresh -h github.com -s workflow`n" +
              "(it shows a code to type at github.com/login/device), then press Add game again.")
    }
    & $gh repo view "$owner/$repoName" --json name *> $null
    $repoExists = $LASTEXITCODE -eq 0
    if ($repoExists -and -not $resume) { Fail "github.com/$owner/$repoName already exists. Pick another name." }
}
Write-Host "OK: $Game, $($cues.Count) disc(s) in $src$(if ($resume) { ' (carrying on from an earlier run)' })"
$cues | ForEach-Object { Write-Host "  $($_.Name)" }

# --- 1. Read the discs ---------------------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $dest "game.toml"))) {
    Step "1. Reading the disc(s) (copy + probe)"
    $newRecomp = Join-Path $PSScriptRoot "new-recomp.ps1"
    & { $ErrorActionPreference = "Continue"; & $newRecomp -Name $Game -Disc @($cues | ForEach-Object { $_.FullName }) }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $dest "game.toml"))) {
        # This run made the folder (it didn't exist before): remove it so the next try starts clean.
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        Fail "reading the disc failed (see above). Check the files in $src (a .cue with its .bin files next to it)."
    }
    Set-Content $pending "Add game started $(Get-Date -Format s). Remove this folder to start over." -Encoding utf8NoBOM
} else { Write-Host "1. Disc already read (recomps\$Game)" }

# --- 2. The NAS folder = what recomps\<game>\disc holds ------------------------------------------------------
$disc = Join-Path $dest "disc"
if (Test-Path -LiteralPath $disc) {
    Step "2. Saving the files read from the disc on the NAS ($src)"
    foreach ($f in Get-ChildItem -LiteralPath $disc -Recurse -File) {
        $rel = $f.FullName.Substring($disc.Length + 1)
        $to = Join-Path $src $rel
        if (-not (Test-Path -LiteralPath $to)) {
            New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
            Copy-Item -LiteralPath $f.FullName $to
            Write-Host "  added $rel"
        }
        if ((Get-Item -LiteralPath $to).Length -ne $f.Length) { Fail "$to differs from the copy read here; nothing removed. Check the NAS folder." }
    }
    # Builds copy the disc in from the NAS (ci-build.ps1) and remove it afterwards: no copy kept here.
    Remove-Item -LiteralPath $disc -Recurse -Force
    Write-Host "OK: $src is ready for builds"
} else { Write-Host "2. NAS folder already done" }

# --- 3. The game's own files, for its repository --------------------------------------------------------------
Step "3. The game's setup for GitHub (games\$Game)"
& $pwshExe -NoProfile -File (Join-Path $PSScriptRoot "export-games.ps1") -Game $Game
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $exp "game.toml"))) { Fail "export-games.ps1 failed (see above)." }
# Same ignore rules as every game repository: never anything from the disc, saves, builds or keys.
Set-Content (Join-Path $exp ".gitignore") @(
    "# Never in this repository: anything from the disc, saves, builds, keys.",
    "disc/", "*.bin", "*.BIN", "*.cue", "*.iso", "*.chd", "*.img", "*.ecm", "*.pbp",
    "saves/", "memcard-import/", "*.mcd", "*.pst",
    "generated/", "generated.orig/", "psxrecomp/", "build*/", "android/", "launcher_assets/",
    "*.apk", "*.keystore", "*.jks", "keys.txt", "__pycache__/") -Encoding utf8NoBOM
# Double check before anything goes public: no disc files, no boot program, nothing big, no PC paths in the
# data files (the README's example command names "D:\my discs" on purpose).
$files = @(Get-ChildItem -LiteralPath $exp -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
$bad = @($files | Where-Object {
    $_.Extension -match '^\.(bin|cue|iso|img|chd|ecm|pbp|mcd|pst|exe|apk|keystore|jks)$' -or
    $_.Name -match '^[A-Z]{4}_\d{3}\.\d{2}' -or $_.Length -gt 10MB })
if ($bad.Count) { Fail "games\$Game has files that may come from the disc: $(($bad | ForEach-Object Name) -join ', '). Nothing was uploaded; ask Claude." }
$paths = @($files | Where-Object { $_.Extension -in ".toml", ".json", ".txt" } | Select-String -Pattern '(?<![A-Za-z])[A-Za-z]:(\\|/)' -List)
if ($paths.Count) { Fail "games\$Game still names folders of this PC: $(($paths | ForEach-Object { "$($_.Filename): $($_.Line.Trim())" }) -join '; '). Nothing was uploaded; ask Claude." }
Write-Host "OK: $($files.Count) files, nothing from the disc:"
$files | ForEach-Object { Write-Host ("  {0} ({1:N0} bytes)" -f $_.FullName.Substring($exp.Length + 1), $_.Length) }

# --- 5 (preview in a dry run). The Build APK list -----------------------------------------------------------
function Update-GameList([string]$path) {
    $yml = Get-Content -LiteralPath $path -Raw
    $new = Add-ToGameList $yml $Game
    if ($null -eq $new) { Write-Host "  $Game is already in the list"; return $false }
    Set-Content -LiteralPath $path $new -Encoding utf8NoBOM -NoNewline
    Write-Host "  added $Game to the game list"
    return $true
}

if ($DryRun) {
    Step "Test only: what Build APK's game list would become"
    $preview = Join-Path ([IO.Path]::GetTempPath()) "add-game-build-apk.yml"
    if ($WorkflowFile) { Copy-Item -LiteralPath $WorkflowFile $preview -Force }
    elseif (Test-Path $gh) {
        & $gh api "repos/$buildsRepo/contents/.github/workflows/build-apk.yml" -H "Accept: application/vnd.github.raw" 2>$null | Set-Content $preview -Encoding utf8NoBOM
        if ($LASTEXITCODE -ne 0) { Write-Host "  (could not read it from GitHub; skipped)"; $preview = "" }
    } else { $preview = "" }
    if ($preview) {
        Update-GameList $preview | Out-Null
        $opts = (Get-Content $preview) -match '^\s+- \S+\s*$' | ForEach-Object { $_.Trim().Substring(2) }
        Write-Host "  list: $($opts -join ', ')"
        if ($WorkflowFile) { Copy-Item $preview $WorkflowFile -Force }   # tests check the result
        Remove-Item $preview -Force
    }
    Write-Host ""
    Write-Host "Test OK: the discs read fine and the setup is ready (recomps\$Game, games\$Game). Nothing was created on GitHub."
    Write-Host "Press Add game again WITHOUT 'test only' to finish (it carries on from here)."
    exit 0
}

# --- 4. GitHub: the game's public repository, and psx-android's link to it -----------------------------------
Step "4. GitHub repository $owner/$repoName (public: no game code in it)"
if (-not $repoExists) {
    & $gh repo create "$owner/$repoName" --public --description "Android port setup for $Game (psxrecomp). No game code: build it from your own disc with psx-android."
    if ($LASTEXITCODE -ne 0) { Fail "could not create github.com/$owner/$repoName (see above)." }
}
if (-not (Test-Path (Join-Path $exp ".git"))) {
    Git-Must $exp init -q -b main
    Git-Must $exp remote add origin $repoUrl
}
Git-Must $exp add -A
& git -C $exp diff --cached --quiet
if ($LASTEXITCODE -ne 0) { Git-Must $exp commit -q -m "$Game`: config, seeds (no game content)" }
Git-Must $exp push -q origin HEAD:main
Write-Host "OK: https://github.com/$owner/$repoName"

if (-not $inPsxAndroid) {
    Step "Adding it to psx-android (games\$Game)"
    Git-Must $tools fetch -q origin main
    Git-Must $tools merge -q --ff-only origin/main
    Git-Must $tools submodule add -q --force $repoUrl "games/$Game"
    Git-Must $tools commit -q -m "Add $Game (games/$Game, from the Add game button)" -- .gitmodules "games/$Game"
    & git -C $tools -c credential.helper= -c $cred push -q origin HEAD:main
    if ($LASTEXITCODE -ne 0) {
        # Leave this copy exactly as on GitHub, so the next build's update works; the next Add game run retries.
        & git -C $tools reset -q --hard origin/main
        Fail "could not push psx-android (see above). Press Add game again to retry."
    }
    Write-Host "OK: psx-android has games\$Game"
}

# --- 5. The Build APK list ------------------------------------------------------------------------------------
Step "5. Build APK's game list (psx-android-builds)"
if ($WorkflowFile) { Update-GameList $WorkflowFile | Out-Null }
else {
    $tmp = Join-Path $ToolsCache "add-game-builds"
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    & git -c credential.helper= -c $cred clone -q --depth 1 "https://github.com/$buildsRepo.git" $tmp
    if ($LASTEXITCODE -ne 0) { Fail "could not download psx-android-builds (see above)." }
    try {
        if (Update-GameList (Join-Path $tmp ".github\workflows\build-apk.yml")) {
            Git-Must $tmp commit -q -a -m "Build APK: add $Game (from the Add game button)"
            & git -C $tmp -c credential.helper= -c $cred push -q origin HEAD:main
            if ($LASTEXITCODE -ne 0) { Fail "could not save the Build APK list (see above). Press Add game again to retry." }
        }
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Remove-Item -LiteralPath $pending -Force
Write-Host ""
Write-Host "Done: $Game is set up. Build it with Actions > Build APK > $Game."
Write-Host "Its first boot may need work (seeds, overlays): bring the build's log to Claude if it doesn't start."
exit 0
