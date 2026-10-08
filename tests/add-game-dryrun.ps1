# Test of tools\add-game.ps1 -DryRun with a FAKE two-disc game (tests\fixtures\add-game: synthetic, no game
# data). Hand-written, 2026-10-08. Nothing goes to GitHub, the NAS or the real recomps folder: it builds a
# throwaway copy of the layout in %TEMP% and removes it at the end.
#   pwsh -File tests\add-game-dryrun.ps1 -Kit <recomp-backups folder>
# -Kit: a folder with tools-cache\python and framework\psxrecomp (the build PC's C:\psx\recomp-backups, or
#   the USB drive's recomp-backups); read only, nothing is written there.
param([string]$Kit = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$probe = Join-Path $Kit "framework\psxrecomp\tools\new_project_layout"
$py = Join-Path $Kit "tools-cache\python\tools"
foreach ($p in $probe, (Join-Path $py "python.exe")) { if (-not (Test-Path $p)) { throw "missing $p (pass -Kit <recomp-backups folder>)" } }

$t = Join-Path ([IO.Path]::GetTempPath()) ("add-game-test-" + (Get-Random))
$root = Join-Path $t "recomp-backups"
$tools = Join-Path $root "psx-android-tools"
$nas = Join-Path $t "psx-discs"
New-Item -ItemType Directory -Force (Join-Path $tools "games"), (Join-Path $root "recomps"), $nas | Out-Null
Copy-Item (Join-Path $repo "tools") $tools -Recurse
Copy-Item (Join-Path $repo ".gitmodules") $tools
New-Item -ItemType Directory -Force (Join-Path $root "framework\psxrecomp\tools") | Out-Null
Copy-Item $probe (Join-Path $root "framework\psxrecomp\tools") -Recurse
Copy-Item (Join-Path $PSScriptRoot "fixtures\add-game\nas\*") $nas -Recurse
$yml = Join-Path $t "build-apk.yml"
Copy-Item (Join-Path $PSScriptRoot "fixtures\add-game\build-apk.yml") $yml
New-Item -ItemType Directory -Force (Join-Path $nas "nocue_recomp") | Out-Null
$env:PATH = "$py;$env:PATH"   # the kit's Python (Find-Python falls back to python on PATH)

$script:failed = 0
function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "  PASS $what" } else { Write-Host "  FAIL $what"; $script:failed++ }
}
function Run([string]$game, [switch]$Dry) {
    $a = @("-NoProfile", "-File", (Join-Path $tools "tools\add-game.ps1"), "-Game", $game, "-Nas", $nas, "-WorkflowFile", $yml)
    if ($Dry) { $a += "-DryRun" }
    $out = & (Get-Process -Id $PID).Path @a 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Out = $out }
}
$g = "fakegame_recomp"
$dest = Join-Path $root "recomps\$g"
$exp = Join-Path $tools "games\$g"
try {
    Write-Host "== refusals"
    $r = Run "FakeGame" -Dry; Check ($r.Code -eq 1 -and $r.Out -match "must look like") "bad name refused"
    $r = Run "missing_recomp" -Dry; Check ($r.Code -eq 1 -and $r.Out -match "there is no folder") "missing NAS folder: clear message"
    $r = Run "nocue_recomp" -Dry; Check ($r.Code -eq 1 -and $r.Out -match "no \.cue file") "folder without .cue refused"
    $r = Run "gex_recomp" -Dry; Check ($r.Code -eq 1 -and $r.Out -match "already exists in psx-android") "existing game (gex_recomp) refused"

    Write-Host "== dry run, fake 2-disc game"
    $r = Run $g -Dry
    Write-Host ($r.Out -replace '(?m)^', '    ')
    Check ($r.Code -eq 0) "exit 0"
    $toml = Get-Content (Join-Path $dest "game.toml") -Raw
    Check ($toml -match 'id\s*=\s*"SLUS-99999"') "game.toml has the probed serial"
    Check ($toml -match '(?s)discs\s*=\s*\[\s*"disc/Fake Game \(USA\) \(Disc 1\)\.cue",\s*"disc/Fake Game \(USA\) \(Disc 2\)\.cue"') "both discs, in order"
    Check (-not (Test-Path (Join-Path $dest "disc"))) "local disc copy removed"
    Check (Test-Path (Join-Path $dest ".add-game-pending")) "marked as not finished (dry run)"
    Check (Test-Path -LiteralPath (Join-Path $nas "$g\SLUS_999.99")) "boot program saved next to the disc on the NAS"
    Check (@(Get-ChildItem -LiteralPath (Join-Path $nas $g) -Filter *.bin).Count -eq 2) "NAS discs untouched"
    foreach ($f in "game.toml", "README.md", ".gitignore", "seeds\ghidra_funcs.txt", "disc_probe.json", "extra_discs.txt") {
        Check (Test-Path (Join-Path $exp $f)) "games\$g\$f exported"
    }
    $all = @(Get-ChildItem $exp -Recurse -File -Force)
    Check (-not ($all | Where-Object { $_.Extension -in ".bin", ".cue" -or $_.Name -like "SLUS_*" })) "no disc files exported"
    Check (-not ($all | Where-Object { $_.Extension -in ".toml", ".json", ".txt" } | Select-String -Pattern '(?<![A-Za-z])[A-Za-z]:(\\|/)' -List)) "no PC paths exported"
    Check (-not (Test-Path (Join-Path $exp ".git"))) "no git repository made (dry run)"
    $opts = @((Get-Content $yml) -match '^\s+- \S+\s*$' | ForEach-Object { $_.Trim().Substring(2) })
    Check ($opts[0] -eq "all" -and $opts.IndexOf($g) -eq $opts.IndexOf("ff7_recomp") - 1) "Build APK list: added before ff7_recomp"
    Check ((Get-Content $yml -Raw) -match '(?m)^      speed:') "rest of build-apk.yml kept"

    Write-Host "== again (carries on)"
    $r = Run $g -Dry
    Check ($r.Code -eq 0 -and $r.Out -match "carrying on" -and $r.Out -match "already in the list") "second dry run carries on, list unchanged"
    Check (@((Get-Content $yml) -match "- $g").Count -eq 1) "listed once"

    Write-Host "== finished game is refused"
    Remove-Item (Join-Path $dest ".add-game-pending")
    $r = Run $g -Dry; Check ($r.Code -eq 1 -and $r.Out -match "already exists") "existing name refused"
} finally {
    Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ""
if ($script:failed) { Write-Host "FAILED: $script:failed check(s)"; exit 1 }
Write-Host "All checks passed."
exit 0
