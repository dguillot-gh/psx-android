# Update the engine to the newest psxrecomp from GitHub (mstan/psxrecomp), keeping our Android work. Guided,
# and safe: the update is prepared in a SEPARATE copy (framework\psxrecomp-next) and tested on one game first.
# Nothing you use today changes unless every step passes AND you say yes at the end.
# If upstream changed the same code we changed, the merge stops with "conflicts": that needs a programmer
# (see README.md); nothing is changed then either.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Update the engine (psxrecomp)"
$fw = Join-Path $DriveRoot "framework\psxrecomp"
$next = Join-Path $DriveRoot "framework\psxrecomp-next"
if (-not (Test-Path (Join-Path $fw ".git"))) { Bad "No engine git repository at $fw"; Pause-End; return }

# 1. Fetch upstream and see what's new.
Info "1. Checking GitHub for psxrecomp updates..."
& git -C $fw fetch -q upstream 2>&1 | Where-Object { $_ -notmatch 'warning:' }
$new = [int](& git -C $fw rev-list --count android..upstream/master)
if ($new -eq 0) { Good "Already up to date with psxrecomp."; Pause-End; return }
Info "   $new new upstream change(s) since our last update. Latest:"
& git -C $fw log --oneline -5 upstream/master | ForEach-Object { Info "     $_" }
if (-not (Ask-YesNo "Prepare the update in a separate copy and test it?" $true)) { Pause-End; return }

# 2. Fresh separate copy on a new branch, merge upstream into it.
Info "2. Merging into a separate copy ($next)..."
& git -C $fw worktree remove --force $next 2>$null
& git -C $fw branch -D android-next 2>$null | Out-Null
& git -C $fw worktree add -q -b android-next $next android
& git -C $next -c user.name=psx -c user.email=psx@local merge --no-edit -X renormalize -X ignore-space-at-eol upstream/master 2>&1 | Select-Object -Last 3 | ForEach-Object { Info "   $_" }
$conflicts = @(& git -C $next diff --name-only --diff-filter=U)
if ($conflicts.Count) {
    & git -C $next merge --abort 2>$null
    Bad "   The update touches code we changed too (conflicts in $($conflicts.Count) file(s)):"
    $conflicts | ForEach-Object { Bad "     $_" }
    Bad "   Nothing was changed. This needs a programmer: see README.md, 'Engine update with conflicts'."
    Pause-End; return
}
Good "   Merged cleanly."

# 3. Build the new recompiler in the separate copy.
Info "3. Building the new recompiler (5-10 minutes)..."
& $Pwsh -NoProfile -File (Join-Path $Tools "tools\build-recompiler.ps1") -Force -Framework $next 2>&1 | Select-Object -Last 3 | ForEach-Object { Info "   $_" }
if (-not (Test-Path (Join-Path $next "recompiler\build-mingw\psxrecomp-game.exe"))) { Bad "   The recompiler did not build. Nothing was changed; needs a programmer."; Pause-End; return }

# 4. Test-build one known-good game on the new copy, in its own work folder.
$testGame = "einhander_recomp"
Info "4. Test build of $testGame on the new engine (20-40 minutes)..."
$r = Run-Go $testGame @("-Framework", $next, "-WorkDir", (Join-Path $DriveRoot "android-recomp-next"), "-NoPhone")
if ($r -notmatch ': ok') { Bad "   The test build failed. Nothing was changed; needs a programmer (log above)."; Pause-End; return }
if ((Ask-YesNo "Install this test build on the phone to try it? (replaces the installed $testGame; saves are backed up)" $true) -and (Need-Phone)) {
    $apk = Get-ChildItem (Join-Path $DriveRoot "apks") -Recurse -Filter "$testGame-debug-*.apk" | Sort-Object LastWriteTime | Select-Object -Last 1
    & $Pwsh -NoProfile -File (Join-Path $Tools "tools\phone.ps1") -Action install -Package (Get-Package $testGame) -Apk $apk.FullName
    Info "   Play it for a few minutes: start, sound, controls, menu, save + load state."
}
if (-not (Ask-YesNo "Did the test game work well? Switch everything to the new engine?" $false)) {
    Info "Kept the old engine. The prepared update stays in $next (menu option 10 redoes it next time)."
    Pause-End; return
}

# 5. Switch: the android branch moves to the tested merge; rebuild the recompiler in place; tag the old one.
$tag = "android-before-" + (Get-Date -Format "yyyyMMdd")
& git -C $fw tag -f $tag android | Out-Null
& git -C $next checkout -q --detach
& git -C $fw merge -q --ff-only android-next
Copy-Item (Join-Path $next "recompiler\build-mingw") (Join-Path $fw "recompiler") -Recurse -Force
Good "Switched. The old engine is saved as git tag $tag."
Warn "Every game must now be rebuilt (menu option 5 overnight, then option 4 to install)."
Warn "Save states made before this update won't load in the rebuilt games (memory-card saves are fine)."
Pause-End
