# Copy each game's OWN files (what makes the recomp work, nothing from the disc) into games\<name>\,
# for the git repository. Hand-written, 2026-10-07. Run again after changing a game's config or seeds.
#   pwsh -File tools\export-games.ps1
# Taken from recomps\<name>\ (and recomps-later\<name>\) : game.toml, seeds\, tools\, aot_exclude.txt, extra_discs.txt, README.md,
#   REFERENCE.md, VERSION, CMakeLists.txt, build.ps1, catalog_identity.json, disc_probe.json.
# Taken from android-recomp\<name>\build-android-overlays\ : play_captures.json (code ADDRESSES the game
#   ran while being played; lets the pre-compile on another PC cover the same code).
# NEVER taken: disc\, saves\, memcard-import\, generated\, psxrecomp\, build-release\, launcher_assets\
#   (box art), assets\, probe.log, anything else.
. (Join-Path $PSScriptRoot "paths.ps1")
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root "games"
$recomps = Join-Path $DriveRoot "recomps"
$work = $DefaultWorkDir
$files = "game.toml", "aot_exclude.txt", "extra_discs.txt", "README.md", "REFERENCE.md", "VERSION",
         "CMakeLists.txt", "build.ps1", "catalog_identity.json", "disc_probe.json"
$dirs = "seeds", "tools"
# recomps-later\ holds games set aside from the pipeline for now; their setup is kept too.
$later = Join-Path $DriveRoot "recomps-later"
foreach ($g in @(Get-ChildItem $recomps -Directory) + @(Get-ChildItem $later -Directory -ErrorAction SilentlyContinue)) {
    $dest = Join-Path $out $g.Name
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }   # a fresh copy each time (our own export)
    New-Item -ItemType Directory -Force $dest | Out-Null
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
    $cap = Join-Path $work "$($g.Name)\build-android-overlays\play_captures.json"
    if (Test-Path $cap) { Copy-Item $cap (Join-Path $dest "play_captures.json") }
    $n = @(Get-ChildItem $dest -Recurse -File).Count
    Write-Host ("{0,-24} {1,3} files" -f $g.Name, $n)
}
