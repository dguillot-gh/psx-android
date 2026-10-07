# The one command. Does everything it can, in order, skips what is already done,
# and ends with a summary. Everything is written to the USB drive, not the PC's C: drive.
#   pwsh -File go.ps1 -Game all                  every game in ..\recomps (Tomba 1 and Policenauts included since 2026-10-06)
#   pwsh -File go.ps1 -Game tomba2_recomp        one game (or several, comma-separated: -Game "gex_recomp,gex2_recomp")
#   pwsh -File go.ps1 -Game all -SkipBuild       port + regenerate only
#   pwsh -File go.ps1 -Game all -NoPhone         build and copy APKs, but don't install
#   pwsh -File go.ps1 -Game "a_recomp,b_recomp" -Speed -NoInstall   read the phone's play captures, but build only
#                                                (for two go.ps1 runs side by side; install afterwards)
#   pwsh -File go.ps1 -Game all -NoDiscPush      install, but don't copy disc images to the phone
#   pwsh -File go.ps1 -Game tomba2_recomp -Framework ..\framework\psxrecomp-next -WorkDir ..\android-recomp-next -NoPhone
#                                                test build on another framework copy, in its own work folder
#   pwsh -File go.ps1 -Status                    only list which task cards pass
#   pwsh -File go.ps1 -Game all -Speed           the FAST builds: pre-compile each game's overlay code
#                                                (tools\speed.ps1), build the play version, install it,
#                                                then open each game and record fps, screenshots and log
#   pwsh -File go.ps1 -Game ff7_recomp -Disc "<disc 1 .cue>","<disc 2 .cue>" -Speed
#                                                a NEW game with no recomp yet: creates it from your discs
#                                                (tools\new-recomp.ps1), then everything above
# Watch it from a second window:  pwsh -File watch.ps1
# Stage 0: install missing tools onto the drive (tools\setup.ps1: Java 17, Android SDK/NDK/CMake, Python).
# Stage 1: task cards in tasks\ (tools the local model writes, via run.ps1).
# Stage 2, per game: port -> regenerate C code -> [-Speed: pre-compile overlays] -> build APK
#          -> copy APK to ..\apks\<date>.
# Stage 3: if a phone is connected, install every new APK (saves backed up first), copy each game's
#          disc images to the phone's Download\<game> folder, [-Speed: test-run each game].
param(
    [switch]$Status,
    [string]$Game = "all",
    [string]$WorkDir = "",
    [string]$Framework = "",
    [switch]$SkipBuild,
    [switch]$NoPhone,
    [switch]$NoInstall,
    [switch]$NoDiscPush,
    [switch]$Speed,
    [int]$TestSeconds = 90,
    [int]$SpeedMinutes = 0,      # -Speed pre-compile time cap (0 = speed.ps1 default, 45); unfinished pieces resume next run
    [string[]]$Disc = @()
)
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "tools\paths.ps1")
if (-not $WorkDir) { $WorkDir = $DefaultWorkDir }          # <drive>\recomp-backups\android-recomp
$recomps = Join-Path $DriveRoot "recomps"
$framework = if ($Framework) { (Resolve-Path $Framework).Path } else { Join-Path $DriveRoot "framework\psxrecomp" }
$apkStore = Join-Path $DriveRoot ("apks\" + (Get-Date -Format "yyyy-MM-dd"))
$progress = Join-Path $PSScriptRoot "progress.log"

# One timestamped line per step, on screen and in progress.log (what watch.ps1 shows).
function Say([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $progress -Value $line
}
if (-not $Status) { Add-Content -Path $progress -Value ""; Say "=== go.ps1 started: -Game $Game, work folder $WorkDir" }

# Keep the PC awake while this window runs (2026-10-05: an overnight run went silent mid-compile,
# most likely the PC sleeping). This is a request from this process only, like a video player's;
# it changes no power settings and ends when go.ps1 exits. The screen may still turn off.
if (-not $Status) {
    try {
        Add-Type -Namespace PsxTools -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -ErrorAction Stop
        [void][PsxTools.Power]::SetThreadExecutionState([uint32]2147483649)   # 0x80000001 = ES_CONTINUOUS | ES_SYSTEM_REQUIRED
        Say "PC: kept awake while go.ps1 runs"
    } catch {
        Say "PC: could not ask Windows to stay awake; set Sleep to Never for long runs ($($_.Exception.Message))"
    }
}

# --- Stage 0: tools ------------------------------------------------------------
if (-not $Status) {
    Say "SETUP: checking tools (downloads anything missing onto the drive)"
    pwsh -NoProfile -File tools\setup.ps1
    if ($LASTEXITCODE -ne 0) { Say "STOPPED: setup could not install everything (see the go.ps1 window)."; exit 1 }
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
    Say "TASK: $($card.Name) fails its check; asking the local model (run.ps1)"
    $num = $card.Name.Substring(0, 2)
    pwsh -NoProfile -File run.ps1 -Task $num
    if ($LASTEXITCODE -ne 0) { Say "STOPPED at $($card.Name). Newest reply is in logs\, check output in check.log. Bring both to Claude."; exit 1 }
}
if ($Status) { exit 0 }
Say "TASKS: all pass"
if (-not (Test-Path (Join-Path $framework "runtime\runtime.cmake"))) { Say "FAIL: framework missing at $framework"; exit 1 }

# --- Stage 2: games ----------------------------------------------------------
# A new game (no recomp yet): create it from the given discs first, then treat it like any other.
if ($Disc.Count) {
    if ($Game -eq "all") { Say "FAIL: -Disc needs -Game <name>_recomp (the new game's name)"; exit 1 }
    if (Test-Path (Join-Path $recomps $Game)) {
        Say "NEW GAME: $Game already exists in $recomps; using it (the -Disc files are not copied again)"
    } else {
        Say "NEW GAME: creating $Game from $($Disc.Count) disc(s) (copies the discs, reads the disc; about a minute)"
        # In-process (&): a list of disc paths can't pass through "pwsh -File"; the script's exit code still lands in $LASTEXITCODE.
        & (Join-Path $PSScriptRoot "tools\new-recomp.ps1") -Name $Game -Disc $Disc | Out-Host
        if ($LASTEXITCODE -ne 0) { Say "FAIL: new-recomp.ps1 could not create $Game (see above)"; exit 1 }
        Say "NEW GAME: $Game created in $recomps"
    }
}
$games = if ($Game -eq "all") {
    Get-ChildItem $recomps -Directory | ForEach-Object { $_.Name }
} else { @($Game -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }   # one game, or several: -Game "a_recomp,b_recomp"
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$results = @()
$built = @()   # @{ Game; Package; Apk }
$n = 0

# -Speed reads the code each game recorded while being played, so connect to the phone first.
$phoneUp = $false
if ($Speed -and -not $NoPhone) {
    Say "PHONE: connecting, to read the code each game recorded while being played"
    pwsh -NoProfile -File tools\phone.ps1 -Action connect
    $phoneUp = ($LASTEXITCODE -eq 0)
    if (-not $phoneUp) { Say "PHONE: not connected; pre-compiling from the discs only" }
}

foreach ($g in $games) {
    $n++
    Write-Host ""
    Say "===== $g ($n of $($games.Count)) ====="
    $gameDir = Join-Path $WorkDir $g
    $result = "ok"

    # Port (skipped when an earlier port FINISHED). A port is finished when the Android app, the game's
    # CMakeLists and the app config all exist (port-game.ps1 writes them last, after the big copy). A
    # folder without them is an interrupted port (2026-10-05: FF7 was stopped mid-copy and the next run
    # treated the half copy as done): it is moved aside, never deleted, and the game is ported again.
    $ported = (Test-Path (Join-Path $gameDir "android\app\build.gradle")) -and
              (Test-Path (Join-Path $gameDir "CMakeLists.txt")) -and
              (Test-Path (Join-Path $gameDir "android\app\src\main\assets\game.toml.in"))
    if ((Test-Path $gameDir) -and -not $ported) {
        $aside = "$g.incomplete-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        Rename-Item $gameDir $aside
        Say "PORT: $g was only partly copied earlier (interrupted); moved aside to $aside, porting again"
    }
    # overlay_codegen_hash.h is a BUILD OUTPUT (each game's build writes its own from its sources); a
    # stale copy in the framework once overwrote every game's correct one and broke the pre-compile.
    if (Test-Path $gameDir) {
        Say "PORT: already in $gameDir (updating its framework copy with any newer fixes)"
        robocopy $framework (Join-Path $gameDir "psxrecomp") /MIR /XD (Join-Path $framework "recompiler\build") (Join-Path $framework ".git") /XF overlay_codegen_hash.h /NFL /NDL /NJH /NJS | Out-Null
    } elseif (-not (Test-Path (Join-Path $recomps $g))) {
        Say "FAIL: no such game in $recomps"; $results += "$g : FAIL no such game in $recomps"; continue
    } else {
        Say "PORT: copying into $gameDir (0.5-1 GB)"
        pwsh -NoProfile -File tools\port-game.ps1 -Name $g -SourceDir $recomps -Framework $framework -OutRoot $WorkDir
        if ($LASTEXITCODE -ne 0) { Say "FAIL: port-game.ps1"; $results += "$g : FAIL port-game.ps1"; continue }
    }

    # Regenerate C code with this framework's recompiler (the original is kept in generated.orig).
    # Done once, and again whenever the recompiler is newer than the last regeneration
    # (a recompiler fix only reaches a game through a regeneration).
    $marker = Join-Path $gameDir ".regenerated"
    $exe = Join-Path $gameDir "psxrecomp\recompiler\build-mingw\psxrecomp-game.exe"
    if ((Test-Path $marker) -and (Get-Item $exe).LastWriteTime -le (Get-Item $marker).LastWriteTime) {
        Say "REGEN: already done"
    } else {
        $gen = Join-Path $gameDir "generated"; $orig = Join-Path $gameDir "generated.orig"
        if (-not (Test-Path $orig)) { robocopy $gen $orig /E /NFL /NDL /NJH /NJS | Out-Null }
        Say "REGEN: regenerating game code (log: $gameDir\regen.log)"
        Push-Location $gameDir
        & $exe --config game.toml *> (Join-Path $gameDir "regen.log")
        $code = $LASTEXITCODE
        Pop-Location
        if ($code -eq 0) {
            Set-Content $marker (Get-Date -Format s)
            Say "REGEN: done"
        } else {
            robocopy $orig $gen /MIR /NFL /NDL /NJH /NJS | Out-Null
            Say "REGEN: FAILED (exit $code, see regen.log); building with the original code instead"
            $result = "ok, but regen failed (original code used)"
        }
    }

    # Oversized-file guard. Normal generated files are 1-2 MB. Empty areas of the game (runs of
    # zeros) used to come out as one giant file that took hours and ran the PC out of memory
    # (Parasite Eve, 2026-10-05). The recompiler now writes them as a short loop, so nothing here
    # should be over 4 MB. If one is, the build still compiles it without optimisation (slower
    # game code there, but it finishes); report it to Claude, it means a new recompiler case.
    $big = @(Get-ChildItem (Join-Path $gameDir "generated") -Filter *.c -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 4MB })
    foreach ($f in $big) {
        Say ("WARNING: oversized generated file {0} ({1:N0} MB). Building anyway; tell Claude." -f $f.Name, ($f.Length / 1MB))
    }
    if ($big.Count) { $result += ", but $($big.Count) oversized generated file(s), tell Claude" }

    # Codegen hash header. Both the pre-compile and Gradle read psxrecomp\runtime\include\
    # overlay_codegen_hash.h BEFORE the native build that normally writes it, so a freshly ported
    # game (never built) had none and failed both (FF7, 2026-10-05). Write it now from the game's own
    # framework sources (same value CMake computes); exit 2 = the recompiler binary is stale.
    $hpy = Find-Python
    if ($hpy) {
        $hout = @(& $hpy tools\codegen_hash.py (Join-Path $gameDir "psxrecomp") --recompiler $exe 2>&1)
        $hc = $LASTEXITCODE
        if ($hc -eq 2) { Say "FAIL: $($hout -join ' ') (tell Claude)"; $results += "$g : FAIL stale recompiler binary (tell Claude)"; continue }
        if ($hc -ne 0) { Say "WARNING: could not write the codegen hash header: $($hout -join ' ')" }
    } else { Say "WARNING: no Python, codegen hash header not checked (run tools\setup.ps1)" }

    $pkg = "com.psxrecomp." + (($g -replace '_recomp$', '').ToLower() -replace '[^a-z0-9]', '')

    # App icon from the game's box art (once per game; keeps the default icon if none is found).
    pwsh -NoProfile -File tools\icon.ps1 -GameDir $gameDir | ForEach-Object { if ($_ -match '^icon: (box art|no box|FAIL)') { Say $_ } }

    # Build, then keep a copy of the APK on the drive
    if ($SkipBuild) { $results += "$g : ported (build skipped)"; continue }
    $buildArgs = @("-NoProfile", "-File", "tools\build.ps1", "-GameDir", $gameDir)
    if ($Speed) {
        # Pre-compile the game's overlay code, then build the fast "play" version (no debug server).
        $speedArgs = @("-NoProfile", "-File", "tools\speed.ps1", "-GameDir", $gameDir, "-Package", $pkg)
        if (-not $phoneUp) { $speedArgs += "-NoPhone" }
        if ($SpeedMinutes -gt 0) { $speedArgs += @("-MaxMinutes", "$SpeedMinutes") }
        pwsh @speedArgs
        if ($LASTEXITCODE -ne 0) { Say "SPEED: FAILED (see above); building the play version without pre-compiled code"; $result += ", pre-compile failed" }
        $buildArgs += "-Play"
    }
    Say "BUILD: started$(if ($Speed) { ' (play version)' }) (about 10-30 min the first time; log: $gameDir\build-android.log)"
    pwsh @buildArgs
    if ($LASTEXITCODE -ne 0) { Say "BUILD: FAILED (see $gameDir\build-android.log)"; $results += "$g : FAIL build (see $gameDir\build-android.log)"; continue }
    $apk = Get-ChildItem (Join-Path $gameDir "apk") -Filter *.apk | Sort-Object LastWriteTime | Select-Object -Last 1
    New-Item -ItemType Directory -Force $apkStore | Out-Null
    Copy-Item $apk.FullName $apkStore
    Say "BUILD: done, $($apk.Name) (copy in $apkStore)"
    $built += @{ Game = $g; Package = $pkg; Apk = $apk.FullName }
    $results += "$g : $result, APK $($apk.Name) (copy in $apkStore)"
}

# --- Stage 3: phone ------------------------------------------------------------
if ($built.Count -and -not $NoPhone -and -not $NoInstall) {
    Write-Host ""
    Say "===== PHONE ====="
    pwsh -NoProfile -File tools\phone.ps1 -Action connect
    if ($LASTEXITCODE -ne 0) {
        Say "PHONE: not connected, nothing installed"
        $results += "phone : not connected, nothing installed (APKs are in $apkStore; rerun go.ps1 when the phone is on)"
    } else {
        foreach ($b in $built) {
            Say "PHONE: backing up saves and installing $($b.Package)"
            pwsh -NoProfile -File tools\phone.ps1 -Action install -Package $b.Package -Apk $b.Apk
            if ($LASTEXITCODE -ne 0) { Say "PHONE: FAILED installing $($b.Package)"; $results += "phone : FAIL installing $($b.Package) (see above)"; continue }
            $results += "phone : installed $($b.Package)"
            if (-not $NoDiscPush) {
                # The app asks for the disc image on first launch; put it where the file picker looks.
                Say "PHONE: copying the disc for $($b.Game) to Download\$($b.Game)"
                pwsh -NoProfile -File tools\phone.ps1 -Action push-disc -Folder (Join-Path (Join-Path $WorkDir $b.Game) "disc") -Name $b.Game
                if ($LASTEXITCODE -eq 0) { $results += "phone : disc for $($b.Game) is in Download\$($b.Game) on the phone" }
                else { Say "PHONE: FAILED copying the disc for $($b.Game)"; $results += "phone : FAIL copying the disc for $($b.Game) (see above)" }
            }
            # A memory card brought along for this game (e.g. from DuckStation) in <game>\memcard-import\:
            # copied in only when the app has no card yet (a fresh install); never replaces one.
            $mcd = Get-ChildItem (Join-Path (Join-Path $WorkDir $b.Game) "memcard-import") -Filter *.mcd -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
            if ($mcd) {
                pwsh -NoProfile -File tools\phone.ps1 -Action import-card -Package $b.Package -Card $mcd.FullName -Slot 1
                if ($LASTEXITCODE -eq 0) { Say "PHONE: memory card $($mcd.Name) imported into $($b.Package)"; $results += "phone : $($b.Game) memory card imported ($($mcd.Name))" }
                elseif ($LASTEXITCODE -eq 2) { $results += "phone : $($b.Game) already had a memory card; $($mcd.Name) NOT imported (ask Claude)" }
                else { $results += "phone : FAIL importing the memory card for $($b.Game)" }
            }
            if (-not $Speed) { continue }
            # Test run: open the game, press Play, record fps + screenshots + the game's log.
            $testDir = Join-Path (Join-Path (Join-Path $WorkDir $b.Game) "phone-test") (Get-Date -Format "yyyyMMdd-HHmm")
            Say "PHONE: test-running $($b.Package) for $TestSeconds s (fps, screenshots, log in $testDir)"
            pwsh -NoProfile -File tools\phone.ps1 -Action play-test -Package $b.Package -OutDir $testDir -Seconds $TestSeconds
            $tc = $LASTEXITCODE
            $sum = if (Test-Path (Join-Path $testDir "summary.txt")) { (Get-Content (Join-Path $testDir "summary.txt") -Raw).Trim() } else { "" }
            if ($tc -eq 0) { Say "PHONE: $($b.Package) test: $sum"; $results += "test  : $($b.Game): $sum (details in $testDir)" }
            elseif ($tc -eq 2) { $results += "test  : $($b.Game): not run, pick the disc once in the app (Select game file), then rerun" }
            else { Say "PHONE: test of $($b.Package) FAILED (see above)"; $results += "test  : $($b.Game): FAIL (see $testDir)" }
            # Back to the phone's home screen before the next game (the tested game keeps running).
            pwsh -NoProfile -File tools\phone.ps1 -Action home | Out-Null
        }
    }
}

Write-Host ""
Say "===== SUMMARY ====="
$results | ForEach-Object { Say $_ }
Write-Host ""
Write-Host "On the phone, open each game: Select game file, pick the .cue and .bin together, then Play."
Write-Host "Package names: com.psxrecomp.<folder name without _recomp and underscores>, e.g. com.psxrecomp.parasiteeve2"
Say "=== go.ps1 finished"
if ($results | Where-Object { $_ -match "FAIL" }) { exit 1 }
exit 0
