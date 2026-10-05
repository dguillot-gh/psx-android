# Check for tasks\03-port-game.md. Exit 0 = done. Uses small fake fixtures only.
param([string]$Script = (Join-Path $PSScriptRoot "port-game.ps1"))
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$fx   = Join-Path $repo "tests\fixtures\port"
$src  = Join-Path $fx "src"
$fw   = Join-Path $fx "framework\psxrecomp"
$out  = Join-Path $env:TEMP "check-03"
if (-not (Test-Path $Script) -or (Get-Item $Script).Length -lt 50) { Write-Host "FAIL: $Script missing or empty"; exit 1 }
foreach ($need in "new-game.ps1", "make-game-toml-in.ps1") {
    if (-not (Test-Path (Join-Path $PSScriptRoot $need))) { Write-Host "FAIL: tools\$need missing (finish tasks 01 and 02 first)"; exit 1 }
}
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory $out | Out-Null

function Snapshot($dir) {
    Get-ChildItem $dir -Recurse -File | ForEach-Object { $_.FullName.Substring($dir.Length) + "|" + (Get-FileHash $_.FullName).Hash } | Sort-Object
}
$srcBefore = Snapshot $src
$fwBefore  = Snapshot $fw

& $Script -Name tomba2_recomp -SourceDir $src -Framework $fw -OutRoot $out
$rc = $LASTEXITCODE
$fail = @()
if ($rc -ne 0) { $fail += "port-game.ps1 exited $rc" }
$d = Join-Path $out "tomba2_recomp"
$fail += @(Compare-Object $srcBefore (Snapshot $src) | ForEach-Object { "source fixture changed: $($_.InputObject)" })
$fail += @(Compare-Object $fwBefore (Snapshot $fw) | ForEach-Object { "framework fixture changed: $($_.InputObject)" })

foreach ($f in "game.toml", "seeds\ghidra_funcs.txt", "generated\SCUS_944.54_dispatch.c", "disc\fake.cue", "disc\fake.bin",
               "psxrecomp\runtime\runtime.cmake", "psxrecomp\recompiler\build-mingw\psxrecomp-game.exe",
               "psxrecomp\runtime\android\java\com\psxrecomp\android\PsxInput.java",
               "android\app\build.gradle", "android\app\src\main\assets\game.toml.in", "CMakeLists.txt") {
    if (-not (Test-Path (Join-Path $d $f))) { $fail += "missing $f" }
}
foreach ($f in "saves\card1.mcd", "saves\card2.mcd") {
    $a = Join-Path $src "tomba2_recomp\$f"; $b = Join-Path $d $f
    if (-not (Test-Path $b) -or (Get-FileHash $a).Hash -ne (Get-FileHash $b).Hash) { $fail += "$f not copied byte-identical" }
}
foreach ($f in "build-release", "psxrecomp\recompiler\build") {
    if (Test-Path (Join-Path $d $f)) { $fail += "$f must not be copied" }
}
$str = Join-Path $d "android\app\src\main\res\values\strings.xml"
if (Test-Path $str) {
    $s = Get-Content $str -Raw
    if ($s -notmatch 'psx_game_id"[^>]*>SCUS-94454<') { $fail += "strings.xml psx_game_id wrong" }
    if ($s -notmatch 'psx_game_title"[^>]*>Tomba! 2 - The Evil Swine Return<') { $fail += "strings.xml psx_game_title wrong" }
}
$gradle = Join-Path $d "android\app\build.gradle"
if ((Test-Path $gradle) -and -not (Select-String -Path $gradle -SimpleMatch 'namespace = "com.psxrecomp.tomba2"' -Quiet)) { $fail += "namespace is not com.psxrecomp.tomba2" }
$boo = Join-Path $d "android\app\src\main\res\values\bools.xml"
if ((Test-Path $boo) -and ((Get-Content $boo -Raw) -notmatch 'psx_analog_sticks"[^>]*>\s*false')) { $fail += "digital game must have psx_analog_sticks false" }
$gti = Join-Path $d "android\app\src\main\assets\game.toml.in"
if ((Test-Path $gti) -and -not (Select-String -Path $gti -SimpleMatch 'id = "SCUS-94454"' -Quiet)) { $fail += "game.toml.in is not Tomba 2's" }
$cm = Join-Path $d "CMakeLists.txt"
if (Test-Path $cm) {
    $c = Get-Content $cm -Raw
    foreach ($want in 'project(Tomba2Recomp LANGUAGES C CXX)', 'WINDOW_TITLE "Tomba! 2 - The Evil Swine Return"',
                      'GEN_MARKER "generated/SCUS_944.54_dispatch.c"', 'GEN_FULL_GLOB "generated/SCUS_944.54_full_*.c"') {
        if (-not $c.Contains($want)) { $fail += "CMakeLists.txt missing: $want" }
    }
    if ($c.Contains("@@")) { $fail += "CMakeLists.txt still has @@ placeholders" }
    if ($c.StartsWith("# Template")) { $fail += "CMakeLists.txt still has the template header" }
}
# A second run must refuse and change nothing.
$destBefore = Snapshot $d
& $Script -Name tomba2_recomp -SourceDir $src -Framework $fw -OutRoot $out
if ($LASTEXITCODE -eq 0) { $fail += "second run into an existing folder must exit non-zero" }
$fail += @(Compare-Object $destBefore (Snapshot $d) | ForEach-Object { "second run changed: $($_.InputObject)" })

if ($fail.Count) { $fail | ForEach-Object { Write-Host "FAIL: $_" }; exit 1 }
Write-Host "OK"; exit 0
