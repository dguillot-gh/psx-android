# The one command. Does everything it can, in order, skips what is already done,
# and ends with a summary.
#   pwsh -File go.ps1 -Game all                  every game in ..\recomps (except Tomba, already done)
#   pwsh -File go.ps1 -Game tomba2_recomp        one game
#   pwsh -File go.ps1 -Game all -SkipBuild       port + regenerate only
#   pwsh -File go.ps1 -Game all -NoPhone         build and copy APKs, but don't install
#   pwsh -File go.ps1 -Game all -NoDiscPush      install, but don't copy disc images to the phone
#   pwsh -File go.ps1 -Status                    only list which task cards pass
# Stage 0: install missing tools (tools\setup.ps1: git, Java 17, Android SDK/NDK/CMake).
# Stage 1: task cards in tasks\ (tools the local model writes, via run.ps1).
# Stage 2, per game: port -> regenerate C code -> build APK -> copy APK to the drive.
# Stage 3: if a phone is connected, install every new APK (saves backed up first) and copy
#          each game's disc images to the phone's Download\<game> folder.
param(
    [switch]$Status,
    [string]$Game = "all",
    [string]$WorkDir = "C:\recomp",
    [switch]$SkipBuild,
    [switch]$NoPhone,
    [switch]$NoDiscPush
)
Set-Location $PSScriptRoot
$root = Split-Path -Parent $PSScriptRoot          # ...\recomp-backups
$recomps = Join-Path $root "recomps"
$framework = Join-Path $root "framework\psxrecomp"
$apkStore = Join-Path $root ("apks\" + (Get-Date -Format "yyyy-MM-dd"))

# --- Stage 0: tools ------------------------------------------------------------
if (-not $Status) {
    pwsh -NoProfile -File tools\setup.ps1
    if ($LASTEXITCODE -ne 0) { Write-Host "Stopped: setup could not install everything (see above)."; exit 1 }
}

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
$built = @()   # @{ Game; Package; Apk }

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

    # Build, then keep a copy of the APK on the drive
    if ($SkipBuild) { $results += "$g : ported (build skipped)"; continue }
    pwsh -NoProfile -File tools\build.ps1 -GameDir $gameDir
    if ($LASTEXITCODE -ne 0) { $results += "$g : FAIL build (see $gameDir\build-android.log)"; continue }
    $apk = Get-ChildItem (Join-Path $gameDir "apk") -Filter *.apk | Sort-Object LastWriteTime | Select-Object -Last 1
    New-Item -ItemType Directory -Force $apkStore | Out-Null
    Copy-Item $apk.FullName $apkStore
    $pkg = "com.psxrecomp." + (($g -replace '_recomp$', '').ToLower() -replace '[^a-z0-9]', '')
    $built += @{ Game = $g; Package = $pkg; Apk = $apk.FullName }
    $results += "$g : $result, APK $($apk.Name) (copy in $apkStore)"
}

# --- Stage 3: phone ------------------------------------------------------------
if ($built.Count -and -not $NoPhone) {
    Write-Host ""
    Write-Host "===== PHONE ====="
    pwsh -NoProfile -File tools\phone.ps1 -Action connect
    if ($LASTEXITCODE -ne 0) {
        $results += "phone : not connected, nothing installed (APKs are in $apkStore; rerun go.ps1 when the phone is on)"
    } else {
        foreach ($b in $built) {
            pwsh -NoProfile -File tools\phone.ps1 -Action install -Package $b.Package -Apk $b.Apk
            if ($LASTEXITCODE -ne 0) { $results += "phone : FAIL installing $($b.Package) (see above)"; continue }
            $results += "phone : installed $($b.Package)"
            if ($NoDiscPush) { continue }
            # The app asks for the disc image on first launch; put it where the file picker looks.
            pwsh -NoProfile -File tools\phone.ps1 -Action push-disc -Folder (Join-Path (Join-Path $WorkDir $b.Game) "disc") -Name $b.Game
            if ($LASTEXITCODE -eq 0) { $results += "phone : disc for $($b.Game) is in Download\$($b.Game) on the phone" }
            else { $results += "phone : FAIL copying the disc for $($b.Game) (see above)" }
        }
    }
}

Write-Host ""
Write-Host "===== SUMMARY ====="
$results | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "On the phone, open each game: Select game file, pick the .cue and .bin together, then Play."
Write-Host "Package names: com.psxrecomp.<folder name without _recomp and underscores>, e.g. com.psxrecomp.parasiteeve2"
if ($results | Where-Object { $_ -match "FAIL" }) { exit 1 }
exit 0
