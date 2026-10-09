# Copy each game's OWN files (what makes the recomp work, nothing from the disc) into games\<name>\,
# for the git repository. Hand-written, 2026-10-07. Run again after changing a game's config or seeds.
#   pwsh -File tools\export-games.ps1                   (every game)
#   pwsh -File tools\export-games.ps1 -Game x_recomp    (one game; "Add game" on the build PC uses this)
# Taken from recomps\<name>\ (and recomps-later\<name>\) : game.toml, seeds\, tools\, aot_exclude.txt, extra_discs.txt, README.md,
#   REFERENCE.md, VERSION, CMakeLists.txt, build.ps1, catalog_identity.json, disc_probe.json.
# Taken from android-recomp\<name>\build-android-overlays\ : play_captures.json (code ADDRESSES the game
#   ran while being played; lets the pre-compile on another PC cover the same code).
# NEVER taken: disc\, saves\, memcard-import\, generated\, psxrecomp\, build-release\, launcher_assets\
#   (box art), assets\, probe.log, anything else.
param([string]$Game = "")
. (Join-Path $PSScriptRoot "paths.ps1")
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root "games"
$recomps = Join-Path $DriveRoot "recomps"
$work = $DefaultWorkDir
$files = "game.toml", "aot_exclude.txt", "extra_discs.txt", "android-bios.txt", "boxart-name.txt", "README.md", "REFERENCE.md", "VERSION",
         "CMakeLists.txt", "build.ps1", "catalog_identity.json", "disc_probe.json"
$dirs = "seeds", "tools"
# One line per game for its README (update after testing). Games not listed: "Set up, not built yet."
$GameStatus = @{
    "atvracers_recomp"     = "Builds and installs (2026-10-07). Saves and save states work. Not play-tested further yet."
    "crash2_recomp"        = "Builds and installs (2026-10-07). First boot not checked yet."
    "crash3_recomp"        = "Builds and installs (2026-10-07). First boot not checked yet."
    "einhander_recomp"     = "Plays (2026-10-07): steady 60 fps on a Pixel 8 with the speed pre-compile."
    "ff7_recomp"           = "Plays (2026-10-07): about 50 fps in the opening on a Pixel 8. 3 discs."
    "legoisland2_recomp"   = "Builds and installs (2026-10-07). First boot not checked yet."
    "parasite_eve_recomp"  = "Plays (2026-10-07): steady 60 fps on a Pixel 8. Disc 1 only tested."
    "parasite_eve2_recomp" = "Plays (2026-10-07) on a Pixel 8. Known issue: no sound. Disc 1 only tested."
    "persona_recomp"       = "Plays (2026-10-07): steady 60 fps on a Pixel 8."
    "persona2_recomp"      = "Plays (2026-10-07): about 60 fps on a Pixel 8."
    "policenauts_recomp"   = "Plays (2026-10-07) with the touch trackpad (Sony Mouse). Known issue: slow opening (about 30 fps). Japanese release, 2 discs."
    "tomba_recomp"         = "Plays (2026-10-07): steady 60 fps on a Pixel 8."
    "tomba2_recomp"        = "Plays (2026-10-07) on a Pixel 8; GPU renderer recommended (menu > Display)."
    "gt2sim_recomp"        = "Builds and installs (2026-10-08, after the recompiler data-as-code fix: 32 MB of C). First boot not checked yet."
    "lod_recomp"           = "Code generation fixed (2026-10-08: 11 MB of C, was 1.45 GB). Not built yet. 4 discs."
    "gt2arcade_recomp"     = "Set aside (not built). Likely the same data-as-code problem as GT2 Simulation."
    "mizzurnafallsthechillingcut_recomp" = "Plays (2026-10-09) on a Pixel 8. Fan translation (Cirosan): needs Sony's BIOS SCPH1001 (android-bios.txt); on OpenBIOS it stops at New game."
    "racinglagoon_recomp"  = "Builds and installs (2026-10-09). Not play-tested yet."
}
# recomps-later\ holds games set aside from the pipeline for now; their setup is kept too.
$later = Join-Path $DriveRoot "recomps-later"
foreach ($g in @(Get-ChildItem $recomps -Directory) + @(Get-ChildItem $later -Directory -ErrorAction SilentlyContinue)) {
    if ($Game -and $g.Name -ne $Game) { continue }
    $dest = Join-Path $out $g.Name
    # A fresh copy each time (our own export). games\<name> is the game's own git repository (a submodule):
    # keep its .git link and .gitignore, replace everything else.
    New-Item -ItemType Directory -Force $dest | Out-Null
    Get-ChildItem $dest -Force | Where-Object { $_.Name -notin ".git", ".gitignore" } | Remove-Item -Recurse -Force
    foreach ($f in $files) {
        $src = Join-Path $g.FullName $f
        if (Test-Path -LiteralPath $src -PathType Leaf) { Copy-Item -LiteralPath $src $dest }
    }
    foreach ($d in $dirs) {
        $src = Join-Path $g.FullName $d
        if (Test-Path -LiteralPath $src -PathType Container) {
            Copy-Item -LiteralPath $src (Join-Path $dest $d) -Recurse
            Get-ChildItem (Join-Path $dest $d) -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
        }
    }
    # No paths from our PCs in the repositories (they may be public): an absolute disc path in game.toml
    # ("G:/ps1 ports/.../Game (USA).cue", only a note of where the disc was first read from) keeps its file name.
    # Same for the probe's JSON ("cue_path": "C:\\psx\\...\\Game (USA).cue", backslashes doubled there).
    foreach ($f in "game.toml", "disc_probe.json", "catalog_identity.json") {
        $p = Join-Path $dest $f
        if (-not (Test-Path $p)) { continue }
        $t = Get-Content $p -Raw
        $t2 = [regex]::Replace($t, '"[A-Za-z]:(?:/|\\{1,2})[^"]*(?:/|\\)([^"/\\]+)"', '"$1"')
        if ($t2 -ne $t) { Set-Content $p $t2 -Encoding utf8NoBOM -NoNewline }
    }
    $cap = Join-Path $work "$($g.Name)\build-android-overlays\play_captures.json"
    if (Test-Path $cap) { Copy-Item $cap (Join-Path $dest "play_captures.json") }

    # README for this game's own repository. An upstream README (a game first published by
    # someone else) is kept beside it as UPSTREAM-README.md.
    $readme = Join-Path $dest "README.md"
    if (Test-Path $readme) { Move-Item $readme (Join-Path $dest "UPSTREAM-README.md") -Force }
    $toml = Get-Content (Join-Path $dest "game.toml") -Raw
    $gameSec = if ($toml -match '(?ms)^\[game\](.*?)(^\[|\z)') { $Matches[1] } else { $toml }
    $title = if ($gameSec -match '(?m)^name\s*=\s*"([^"]+)"') { $Matches[1] -replace '(\s*\([^)]*\))+$', '' } else { $g.Name }
    $serial = if ($gameSec -match '(?m)^id\s*=\s*"([^"]+)"') { $Matches[1] } else { "?" }
    $cueNames = @()
    if ($gameSec -match '(?ms)^discs\s*=\s*\[(.*?)^\]') { $cueNames = @([regex]::Matches($Matches[1], '"([^"]+)"') | ForEach-Object { Split-Path $_.Groups[1].Value -Leaf }) }
    elseif ($gameSec -match '(?m)^disc\s*=\s*"([^"]+)"') { $cueNames = @(Split-Path $Matches[1] -Leaf) }
    $md5 = if ($toml -match '(?ms)^known_md5\s*=\s*\[\s*"([0-9a-f]{32})"') { $Matches[1] } else { "" }
    $short = $g.Name -replace '_recomp$', ''
    $pkg = "com.psxrecomp." + ($short.ToLower() -replace '[^a-z0-9]', '')
    $status = $GameStatus[$g.Name]; if (-not $status) { $status = "Set up, not built yet." }
    $discArg = (1..[Math]::Max(1, $cueNames.Count) | ForEach-Object { "`"D:\my discs\<disc $_>.cue`"" }) -join ","
    $md = @(
        "# $title for Android (psxrecomp)",
        "",
        "This repository holds only what makes **$title** run as a native Android app: its",
        "configuration, code entry points (seeds), helper tools and play captures. **It contains no game",
        "code or data.** You build the app on your own PC from **your own disc**; nothing from the disc is",
        "ever uploaded.",
        "",
        "Part of [psx-android](https://github.com/dguillot-gh/psx-android), which has the build scripts and",
        "the full how-to. Engine: [psxrecomp-android](https://github.com/dguillot-gh/psxrecomp-android)",
        "(mstan/psxrecomp + our Android layer; PolyForm Noncommercial: personal, non-commercial use only).",
        "",
        "## Status",
        $status,
        "",
        "## The disc you need",
        "- Serial **$serial**, $($cueNames.Count) disc(s), as ``.cue`` + ``.bin`` (a raw rip of your own copy).",
        ("- Tested with: " + (($cueNames | ForEach-Object { "``$_``" }) -join ", ") + " (your file names may differ, that's fine).")
    )
    if ($md5) { $md += "- Known-good dump, Track 1 MD5: ``$md5``. Other dumps of the same serial usually work too." }
    $md += @(
        "",
        "## Build it and put it on your phone",
        "Follow **Get a game on your phone** in the psx-android README once (PC setup), then:",
        "",
        "``````powershell",
        "pwsh -File go.ps1 -Game $($g.Name) -Disc $discArg -Speed",
        "``````",
        "",
        "List every disc's ``.cue`` in order, separated by commas. The app ($pkg) is installed on the phone",
        "over USB, and the disc is copied to the phone's ``Download\$($g.Name)`` folder. On the phone: open the app,",
        ("**Select game file**, side menu > your phone > Download > $($g.Name), pick the ``.cue``" +
            $(if ($cueNames.Count -gt 1) { " files (all of them)" } else { "" }) + ", then **Play**."),
        "",
        "## What's here",
        "| File | What |",
        "|---|---|",
        "| ``game.toml`` | the game's configuration (boot program, memory layout, controller, video) |",
        "| ``seeds/`` | code entry points the recompiler starts from |",
        "| ``play_captures.json`` | addresses of code the game loaded while being played; makes the speed pre-compile cover it |",
        "| ``tools/``, ``aot_exclude.txt`` | game-specific helpers / pieces kept off the pre-compile (when present) |"
    )
    Set-Content $readme $md -Encoding utf8NoBOM
    $n = @(Get-ChildItem $dest -Recurse -File).Count
    Write-Host ("{0,-24} {1,3} files" -f $g.Name, $n)
}
