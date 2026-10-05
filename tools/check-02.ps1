# Check for tasks\02-game-toml-in.md. Exit 0 = done.
param([string]$Script = (Join-Path $PSScriptRoot "make-game-toml-in.ps1"))
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$fx   = Join-Path $repo "tests\fixtures"
$tmp  = Join-Path $env:TEMP "check-02"
if (-not (Test-Path $Script) -or (Get-Item $Script).Length -lt 50) { Write-Host "FAIL: $Script missing or empty"; exit 1 }
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory $tmp | Out-Null
$fail = @()

function Lines($file) { (Get-Content $file) | ForEach-Object { $_.Trim() } }
function Section($lines, $name) {
    # lines between [name] and the next [section]
    $out = @(); $in = $false
    foreach ($l in $lines) {
        if ($l -match '^\[[^\]]+\]$') { $in = ($l -eq "[$name]"); continue }
        if ($in -and $l -ne "" -and -not $l.StartsWith("#")) { $out += $l }
    }
    ,$out
}

foreach ($case in "tomba", "pe2") {
    $in  = Join-Path $fx "$case\game.toml"
    $out = Join-Path $tmp "$case.game.toml.in"
    $before = (Get-FileHash $in).Hash
    & $Script -GameToml $in -Out $out
    if ((Get-FileHash $in).Hash -ne $before) { $fail += "$case : input file was modified" }
    if (-not (Test-Path $out)) { $fail += "$case : output not written"; continue }
    $head = Get-Content $out -AsByteStream -TotalCount 3
    if ($head.Count -ge 2 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB) { $fail += "$case : output has a BOM" }
    $o = Lines $out
    $src = Lines $in
    $g = Section $o "game"
    foreach ($k in "name","id","players","exe","load_address","entry_pc","text_size","stack_base") {
        $want = ($src | Where-Object { $_ -match "^$k\s*=" } | Select-Object -First 1)
        if ($want -and -not ($g -contains $want)) { $fail += "$case : [game] missing '$want'" }
    }
    if ($g | Where-Object { $_ -match '^disc\s*=' }) { $fail += "$case : single 'disc =' key copied" }
    $nd = if ($case -eq "pe2") { 2 } else { 1 }
    for ($i = 1; $i -le $nd; $i++) { if (-not ($g -contains "@@DISC$i@@,")) { $fail += "$case : missing line @@DISC$i@@," } }
    if ($o -match "@@DISC$($nd + 1)@@") { $fail += "$case : too many disc placeholders" }
    if ($o | Where-Object { $_ -match '"@@DISC' }) { $fail += "$case : placeholders must not be quoted" }
    if ($case -eq "pe2" -and -not ($g -contains 'disc_serials = ["SLUS-01042", "SLUS-01055"]')) { $fail += "pe2 : disc_serials not copied" }
    $r = Section $o "runtime"
    if (-not (($r -contains 'video_renderer = "software"') -and ($r -contains 'overlay_cache = true') -and $r.Count -eq 2)) { $fail += "$case : [runtime] must be exactly video_renderer + overlay_cache" }
    $rc = Section $o "recompiler"
    if (-not ($rc -contains 'seeds = "seeds/ghidra_funcs.txt"')) { $fail += "$case : [recompiler] not copied" }
    if (-not ((Section $o "controller") -contains 'default_mode = "digital"')) { $fail += "$case : [controller] not copied" }
    $b = Section $o "bios"
    if (-not ($b.Count -eq 1 -and $b[0] -eq 'path = "bios/openbios.bin"')) { $fail += "$case : [bios] wrong" }
    foreach ($bad in "[prepare_disc]","[netplay]","[video]") { if ($o -contains $bad) { $fail += "$case : $bad must be left out" } }
    foreach ($bad in "window_title","memcard_dir","known_md5","G:/") { if ($o | Where-Object { $_.Contains($bad) }) { $fail += "$case : '$bad' must be left out" } }
    foreach ($s in "[game]","[recompiler]","[runtime]","[controller]","[bios]") {
        if (($o | Where-Object { $_ -eq $s }).Count -ne 1) { $fail += "$case : $s must appear exactly once" }
    }
}
if ($fail.Count) { $fail | ForEach-Object { Write-Host "FAIL: $_" }; exit 1 }
Write-Host "OK"; exit 0
