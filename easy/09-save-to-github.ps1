# Save to GitHub (account dguillot-gh): the scripts and notes, and the engine. Game repositories are not
# touched (see step 1). Uploads only what's in git: never discs, saves, APKs or keys (see .gitignore).
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

# 1. The games: not saved from here any more. Since 2026-11-06 each game's public repository
#    (dguillot-gh/<name>-android) is a standalone build made from the ff7-android layout, with no play
#    captures (they carry the game's code). games\ is a local, git-ignored working copy: nothing in it is
#    committed or pushed, and no game repository is created from it.
Info "1. Games: each has its own repository, updated on its own (nothing pushed from games\)."
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
