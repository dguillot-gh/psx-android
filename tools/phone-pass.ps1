# Put already-built games on the phone: the same steps as go.ps1's phone stage, without building.
# For each game: back up saves + install its newest play APK (apks\<date>), copy its disc to
# Download\<game>, import memcard-import\*.mcd only if the app has no card yet, then (unless -NoTest)
# a test run (fps, screenshots, log in <game>\phone-test\<time>). Hand-written, 2026-10-07.
#   pwsh -File tools\phone-pass.ps1 -Game "crash2_recomp,ff7_recomp"
#   pwsh -File tools\phone-pass.ps1 -Game ff7_recomp -Date 2026-10-07 -NoTest
param(
    [Parameter(Mandatory = $true)][string]$Game,
    [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
    [string]$WorkDir = "",
    [switch]$NoTest,
    [int]$TestSeconds = 90
)
Set-Location (Split-Path $PSScriptRoot -Parent)
. (Join-Path $PSScriptRoot "paths.ps1")
if (-not $WorkDir) { $WorkDir = $DefaultWorkDir }
$progress = Join-Path (Split-Path $PSScriptRoot -Parent) "progress.log"
function Say([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $progress -Value $line
}
$apkDir = Join-Path $DriveRoot "apks\$Date"
$results = @()
pwsh -NoProfile -File tools\phone.ps1 -Action connect
if ($LASTEXITCODE -ne 0) { Say "PHONE: not connected, nothing installed"; exit 1 }
foreach ($g in @($Game -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $pkg = "com.psxrecomp." + (($g -replace '_recomp$', '').ToLower() -replace '[^a-z0-9]', '')
    $apk = Get-ChildItem $apkDir -Filter "$g-play-*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $apk) { Say "PHONE: no play APK for $g in $apkDir"; $results += "$g : no APK"; continue }
    Say "PHONE: backing up saves and installing $pkg ($($apk.Name))"
    pwsh -NoProfile -File tools\phone.ps1 -Action install -Package $pkg -Apk $apk.FullName
    if ($LASTEXITCODE -ne 0) { Say "PHONE: FAILED installing $pkg"; $results += "$g : FAIL install"; continue }
    $gameDir = Join-Path $WorkDir $g
    Say "PHONE: copying the disc for $g to Download\$g"
    pwsh -NoProfile -File tools\phone.ps1 -Action push-disc -Folder (Join-Path $gameDir "disc") -Name $g
    if ($LASTEXITCODE -ne 0) { Say "PHONE: FAILED copying the disc for $g"; $results += "$g : FAIL disc copy"; continue }
    $mcd = Get-ChildItem (Join-Path $gameDir "memcard-import") -Filter *.mcd -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
    if ($mcd) {
        pwsh -NoProfile -File tools\phone.ps1 -Action import-card -Package $pkg -Card $mcd.FullName -Slot 1
        if ($LASTEXITCODE -eq 0) { Say "PHONE: memory card $($mcd.Name) imported into $pkg" }
    }
    if ($NoTest) { $results += "$g : installed, disc copied"; continue }
    $testDir = Join-Path (Join-Path $gameDir "phone-test") (Get-Date -Format "yyyyMMdd-HHmm")
    Say "PHONE: test-running $pkg for $TestSeconds s"
    pwsh -NoProfile -File tools\phone.ps1 -Action play-test -Package $pkg -OutDir $testDir -Seconds $TestSeconds
    $tc = $LASTEXITCODE
    $sum = if (Test-Path (Join-Path $testDir "summary.txt")) { (Get-Content (Join-Path $testDir "summary.txt") -Raw).Trim() } else { "" }
    if ($tc -eq 0) { $results += "$g : installed; test: $sum" }
    elseif ($tc -eq 2) { $results += "$g : installed; not tested (pick the disc once in the app)" }
    else { $results += "$g : installed; test FAILED (see $testDir)" }
    Say "PHONE: $g done"
    pwsh -NoProfile -File tools\phone.ps1 -Action home | Out-Null
}
Say "===== PHONE PASS SUMMARY ====="
$results | ForEach-Object { Say $_ }
