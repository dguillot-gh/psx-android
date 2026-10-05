# The one command. Does everything it can, in order, skips what is already done,
# and ends with a summary.
#   pwsh -File go.ps1 -Game all                  every game in ..\recomps (except Tomba, already done)
#   pwsh -File go.ps1 -Game tomba2_recomp        one game
#   pwsh -File go.ps1 -Game all -SkipBuild       port + regenerate only
#   pwsh -File go.ps1 -Status                    only list which task cards pass
# Stage 1: task cards in tasks\ (tools the local model writes, via run.ps1).
# Stage 2, per game: port (tools\port-game.ps1) -> regenerate C code -> build APK (tools\build.ps1).
param(
    [switch]$Status,
    [string]$Game = "all",
    [string]$WorkDir = "C:\recomp",
    [switch]$SkipBuild
)
Set-Location $PSScriptRoot
$root = Split-Path -Parent $PSScriptRoot          # ...\recomp-backups
$recomps = Join-Path $root "recomps"
$framework = Join-Path $root "framework\psxrecomp"

# --- Stage 1: task cards -----------------------------------------------------
$cards = Get-ChildItem tasks -Filter "*.md" | Sort-Object Name
foreach ($card in $cards) {
    $text = Get-Content $card.FullName -Raw
    if ($text -notmatch 'DONE WHEN (tools\\[\w.-]+\.ps1) exits 0') { Write-Host "SKIP $($card.Name): no DONE WHEN line"; continue }
    $check = $Matches[1]
    pwsh -NoProfile -File $check *> check.log
    if ($LASTEXITCODE -eq 0) { Write-Host "PASS $($card.Name)"; continue }
    Write-Host "TODO $($card.Name)"
    if ($Status) { continue }
    $num = $card.Name.Substring(0, 2)
    pwsh -NoProfile -File run.ps1 -Task $num
    if ($LASTEXITCODE -ne 0) { Write-Host "Stopped at $($card.Name). Newest reply is in logs\, check output in check.log. Bring both to Claude."; exit 1 }
}
if ($Status) { exit 0 }
Write-Host "ALL TASKS PASS"
if (-not (Test-Path (Join-Path $framework "runtime\runtime.cmake"))) { Write-Host "FAIL: framework missing at $framework"; exit 1 }

# --- Stage 2: games ----------------------------------------------------------
$games = if ($Game -eq "all") {
    Get-ChildItem $recomps -Directory | Where-Object { $_.Name -ne "tomba_recomp" } | ForEach-Object { $_.Name }
} else { @($Game) }
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$results = @()

foreach ($g in $games) {
    Write-Host ""
    Write-Host "===== $g ====="
    $gameDir = Join-Path $WorkDir $g
    $result = "ok"

    # Port (skipped if the folder exists)
    if (Test-Path $gameDir) {
        Write-Host "PORT: already in $gameDir"
    } elseif (-not (Test-Path (Join-Path $recomps $g))) {
        $results += "$g : FAIL no such game in $recomps"; continue
    } else {
        Write-Host "PORT: copying into $gameDir (0.5-1 GB)..."
        pwsh -NoProfile -File tools\port-game.ps1 -Name $g -SourceDir $recomps -Framework $framework -OutRoot $WorkDir
        if ($LASTEXITCODE -ne 0) { $results += "$g : FAIL port-game.ps1"; continue }
    }

    # Regenerate C code with this framework's recompiler (once; the original is kept in generated.orig)
    $marker = Join-Path $gameDir ".regenerated"
    if (Test-Path $marker) {
        Write-Host "REGEN: already done"
    } else {
        $gen = Join-Path $gameDir "generated"; $orig = Join-Path $gameDir "generated.orig"
        if (-not (Test-Path $orig)) { robocopy $gen $orig /E /NFL /NDL /NJH /NJS | Out-Null }
        $exe = Join-Path $gameDir "psxrecomp\recompiler\build-mingw\psxrecomp-game.exe"
        Write-Host "REGEN: regenerating game code..."
        Push-Location $gameDir
        & $exe --config game.toml *> (Join-Path $gameDir "regen.log")
        $code = $LASTEXITCODE
        Pop-Location
        if ($code -eq 0) {
            Set-Content $marker (Get-Date -Format s)
        } else {
            robocopy $orig $gen /MIR /NFL /NDL /NJH /NJS | Out-Null
            Write-Host "REGEN: FAILED (exit $code, see regen.log); building with the original code instead."
            $result = "ok, but regen failed (original code used)"
        }
    }

    # Build
    if ($SkipBuild) { $results += "$g : ported (build skipped)"; continue }
    pwsh -NoProfile -File tools\build.ps1 -GameDir $gameDir
    if ($LASTEXITCODE -ne 0) { $results += "$g : FAIL build (see $gameDir\build-android.log)"; continue }
    $apk = Get-ChildItem (Join-Path $gameDir "apk") -Filter *.apk | Sort-Object LastWriteTime | Select-Object -Last 1
    $results += "$g : $result, APK $($apk.FullName)"
}

Write-Host ""
Write-Host "===== SUMMARY ====="
$results | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "To put a game on the phone (wireless debugging on), e.g. Tomba 2:"
Write-Host "  pwsh -File tools\phone.ps1 -Action devices"
Write-Host "  pwsh -File tools\phone.ps1 -Action install -Package com.psxrecomp.tomba2 -Apk <APK path from the summary>"
Write-Host "  pwsh -File tools\phone.ps1 -Action launch -Package com.psxrecomp.tomba2"
Write-Host "Packages: com.psxrecomp.<folder name without _recomp and underscores>, e.g. com.psxrecomp.parasiteeve2"
if ($results | Where-Object { $_ -match "FAIL" }) { exit 1 }
exit 0
