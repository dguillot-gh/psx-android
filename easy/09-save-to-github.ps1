# Save everything to GitHub (your private repositories, account dguillot-gh): each game's setup, the scripts
# and notes, and the engine. Uploads only what's in git: never discs, saves, APKs or keys (see .gitignore).
# Needs the GitHub CLI signed in once on this PC: tools-cache\gh\bin\gh.exe auth login --web
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Save to GitHub"
if (-not (Test-Path $Gh)) { Bad "GitHub CLI missing at $Gh"; Pause-End; return }
& $Gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Warn "Not signed in to GitHub on this PC. Signing in now: a code is shown; enter it at github.com/login/device."
    & $Gh auth login --hostname github.com --git-protocol https --web
    & $Gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { Bad "Still not signed in."; Pause-End; return }
}
$cred = "credential.helper=!'" + ($Gh -replace '\\', '/') + "' auth git-credential"
function GitPush([string]$dir, [string]$branchSpec) {
    & git -C $dir -c credential.helper= -c $cred push -q origin $branchSpec 2>&1 | Where-Object { $_ -notmatch 'LF will be' }
}
function GitCommitAll([string]$dir, [string]$msg) {
    & git -C $dir add -A 2>&1 | Out-Null
    & git -C $dir diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { & git -C $dir -c user.name=psx -c user.email=psx@local commit -q -m $msg 2>&1 | Out-Null; return $true }
    return $false
}
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"

# 1. Refresh each game's folder (games\<name>, its own repository) from recomps\ and the latest play captures.
Info "1. Refreshing the games' setup files..."
& $Pwsh -NoProfile -File (Join-Path $Tools "tools\export-games.ps1") | Out-Null
foreach ($d in Get-ChildItem (Join-Path $Tools "games") -Directory) {
    if (-not (Test-Path (Join-Path $d.FullName ".git"))) {
        $n = (($d.Name -replace '_recomp$', '') -replace '_', '-') + "-android"
        Warn "  $($d.Name) has no GitHub repository yet; creating private dguillot-gh/$n"
        # Same ignore rules as every game repository (copied from an existing one).
        $ig = Get-ChildItem (Join-Path $Tools "games") -Directory | ForEach-Object { Join-Path $_.FullName ".gitignore" } | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($ig) { Copy-Item $ig (Join-Path $d.FullName ".gitignore") }
        & git -C $d.FullName init -q -b main
        & $Gh repo create "dguillot-gh/$n" --private | Out-Null
        & git -C $d.FullName remote add origin "https://github.com/dguillot-gh/$n.git"
        GitCommitAll $d.FullName "$($d.Name): config, seeds, tools, play captures (no game content)" | Out-Null
        GitPush $d.FullName "HEAD:main"
        & git -C $Tools -c credential.helper= -c $cred submodule add -q --force "https://github.com/dguillot-gh/$n.git" "games/$($d.Name)" 2>&1 | Out-Null
    }
    if (GitCommitAll $d.FullName "Update $($d.Name) setup ($stamp)") { GitPush $d.FullName "HEAD:main"; Good "  updated $($d.Name)" }
}
# 2. The engine (framework\psxrecomp, branch android) and its tag.
Info "2. Engine (psxrecomp-android)..."
$fw = Join-Path $DriveRoot "framework\psxrecomp"
if (Test-Path (Join-Path $fw ".git")) {
    if (GitCommitAll $fw "Engine changes ($stamp)") { Good "  committed engine changes" }
    GitPush $fw "android"
    $fwHead = (& git -C $fw rev-parse HEAD).Trim()
    & git -C $Tools update-index --cacheinfo "160000,$fwHead,framework"
}
# 3. This repository (scripts, notes, links to the games and engine).
Info "3. Scripts and notes (psx-android)..."
if (GitCommitAll $Tools "Save ($stamp)") { Good "  committed" }
GitPush $Tools "HEAD:main"
Good "Done. Your repositories: https://github.com/dguillot-gh?tab=repositories"
Pause-End
