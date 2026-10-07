param([string]$GameToml, [string]$Out)
$ErrorActionPreference = "Stop"
$lines = Get-Content $GameToml
# section -> ordered list of (key, text) entries
$sections = [ordered]@{}
$cur = ""; $key = $null; $buf = @()
foreach ($l in $lines) {
    if ($key) { $buf += $l; if ($l.Trim() -eq "]") { $sections[$cur].Add($key, ($buf -join "`n")); $key = $null }; continue }
    $t = $l.Trim()
    if ($t -match '^\[([^\]]+)\]$') { $cur = $Matches[1]; $sections[$cur] = [ordered]@{}; continue }
    if ($t -eq "" -or $t.StartsWith("#") -or $cur -eq "") { continue }
    if ($t -match '^([A-Za-z0-9_]+)\s*=\s*(.*)$') {
        if ($Matches[2] -eq "[") { $key = $Matches[1]; $buf = @($l) } else { $sections[$cur].Add($Matches[1], $l) }
    }
}
$o = @("# Android runtime config, written by the start menu after the user selects",
       "# their own disc image (it fills the disc placeholder).", "[game]")
$g = $sections["game"]
foreach ($k in "name","id","players","exe") { if ($g.Contains($k)) { $o += $g[$k] } }
$n = @(($g["discs"] -split "`n") | Where-Object { $_.Trim().StartsWith('"') }).Count
# A fresh probe (tools\new-recomp.ps1) writes only `disc = "..."` for a one-disc game, no list:
# that is one disc (2026-10-07: Einhander came out with an empty list and quit "no disc selected").
if ($n -eq 0 -and $g.Contains("disc")) { $n = 1 }
$o += "discs = ["; for ($i = 1; $i -le $n; $i++) { $o += "  @@DISC$i@@," }; $o += "]"
foreach ($k in "disc_serials","load_address","entry_pc","text_size","stack_base") { if ($g.Contains($k)) { $o += $g[$k] } }
foreach ($s in "recompiler") { $o += ""; $o += "[$s]"; $o += $sections[$s].Values }
$o += ""; $o += "[runtime]"; $o += 'video_renderer = "software"'; $o += "overlay_cache = true"
foreach ($s in "controller","widescreen") { if ($sections.Contains($s)) { $o += ""; $o += "[$s]"; $o += $sections[$s].Values } }
$o += ""; $o += "[bios]"; $o += 'path = "bios/openbios.bin"'
Set-Content -Path $Out -Value $o -Encoding utf8NoBOM
