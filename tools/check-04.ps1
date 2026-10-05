# Check for tasks\04-phone.md. Exit 0 = done. Runs only in -DryRun mode; needs no phone.
param([string]$Script = (Join-Path $PSScriptRoot "phone.ps1"))
$ErrorActionPreference = "Continue"
if (-not (Test-Path $Script) -or (Get-Item $Script).Length -lt 50) { Write-Host "FAIL: $Script missing or empty"; exit 1 }
$fail = @()
$src = Get-Content $Script -Raw
foreach ($bad in "uninstall", "pm clear", "rm -", "Remove-Item") {
    if ($src.Contains($bad)) { $fail += "script must not contain '$bad'" }
}
$out = Join-Path $env:TEMP "check-04"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
$apk = Join-Path $env:TEMP "check-04-fake.apk"
Set-Content $apk "not a real apk"
$pkg = "com.psxrecomp.tomba"

function Run([string[]]$a) {
    $lines = & pwsh -NoProfile -File $Script @a 2>&1 | ForEach-Object { "$_" }
    @{ Code = $LASTEXITCODE; Lines = @($lines) }
}
function Adb($r) { @($r.Lines | Where-Object { $_.StartsWith("ADB: ") }) }

$r = Run @("-Action", "devices", "-DryRun")
if ($r.Code -ne 0 -or -not ((Adb $r) -contains "ADB: devices")) { $fail += "devices: expected 'ADB: devices' and exit 0" }

$r = Run @("-Action", "launch", "-Package", $pkg, "-DryRun")
if ($r.Code -ne 0 -or -not ((Adb $r) -contains "ADB: shell monkey -p $pkg -c android.intent.category.LAUNCHER 1")) { $fail += "launch: wrong adb line or exit code" }

$r = Run @("-Action", "backup-saves", "-Package", $pkg, "-OutDir", $out, "-DryRun")
$a = Adb $r
if ($r.Code -ne 0) { $fail += "backup-saves: exit $($r.Code)" }
foreach ($card in "card1.mcd", "card2.mcd") {
    $hit = $a | Where-Object { $_.StartsWith("ADB: exec-out run-as $pkg cat files/$card > ") -and $_.Contains($out) -and $_.Contains($pkg) }
    if (-not $hit) { $fail += "backup-saves: no line for $card into $out\$pkg\<timestamp>" }
}
if (Test-Path $out) { $fail += "backup-saves -DryRun must not create folders" }

$r = Run @("-Action", "install", "-Package", $pkg, "-Apk", $apk, "-OutDir", $out, "-DryRun")
$a = Adb $r
$iInstall = -1; $iBackup = -1
for ($i = 0; $i -lt $a.Count; $i++) {
    if ($a[$i] -eq "ADB: install -r $apk") { $iInstall = $i }
    if ($a[$i].Contains("cat files/card2.mcd")) { $iBackup = $i }
}
if ($r.Code -ne 0) { $fail += "install: exit $($r.Code)" }
if ($iInstall -lt 0) { $fail += "install: missing 'ADB: install -r $apk'" }
elseif ($iBackup -lt 0 -or $iBackup -gt $iInstall) { $fail += "install: saves must be backed up BEFORE install" }

$r = Run @("-Action", "install", "-Package", $pkg, "-Apk", (Join-Path $env:TEMP "no-such.apk"), "-DryRun")
if ($r.Code -eq 0 -or (Adb $r).Count -gt 0 -or -not ($r.Lines | Where-Object { $_.Contains("FAIL: apk not found") })) { $fail += "install with a missing apk must print 'FAIL: apk not found', run nothing, exit 1" }

$r = Run @("-Action", "launch", "-DryRun")
if ($r.Code -eq 0) { $fail += "launch without -Package must exit 1" }
$r = Run @("-Action", "explode", "-Package", $pkg, "-DryRun")
if ($r.Code -eq 0 -or (Adb $r).Count -gt 0) { $fail += "unknown action must run nothing and exit 1" }

Remove-Item $apk -Force
if ($fail.Count) { $fail | ForEach-Object { Write-Host "FAIL: $_" }; exit 1 }
Write-Host "OK"; exit 0
