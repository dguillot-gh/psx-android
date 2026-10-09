# Build a ported game's Android APK. Written by hand (not a model task).
#   pwsh -File tools\build.ps1 -GameDir <drive>\recomp-backups\android-recomp\tomba2_recomp [-Play]
# Finds Java 17+ and the Android SDK, checks the NDK/CMake versions the app needs,
# writes android\local.properties if missing, runs Gradle through gradle-wrapper.jar
# (no .bat needed), and copies the APK to <GameDir>\apk\.
param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [switch]$Play
)
$ErrorActionPreference = "Stop"
$ndkVersion = "28.2.13676358"
$cmakeVersion = "3.22.1"
$android = Join-Path $GameDir "android"
if (-not (Test-Path (Join-Path $android "app\build.gradle"))) { Write-Host "FAIL: no Android app in $android (run port-game.ps1 first)"; exit 1 }

. (Join-Path $PSScriptRoot "paths.ps1")

# --- Java ------------------------------------------------------------------
$java = Find-Java
if (-not $java) { Write-Host "FAIL: no Java found. Run tools\setup.ps1 (go.ps1 does it first)."; exit 1 }
Write-Host "Java: $java"

# --- Android SDK -----------------------------------------------------------
# The first SDK (drive first, then the PC) that has the NDK and CMake versions this app needs.
$sdk = @($SdkHome, $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
    Where-Object { $_ -and (Test-Path (Join-Path $_ "ndk\$ndkVersion")) -and (Test-Path (Join-Path $_ "cmake\$cmakeVersion")) } |
    Select-Object -First 1
if (-not $sdk) { Write-Host "FAIL: no Android SDK with NDK $ndkVersion and CMake $cmakeVersion. Run tools\setup.ps1 (go.ps1 does it first)."; exit 1 }
Write-Host "SDK:  $sdk"
# Gradle's download cache goes on the drive, not the PC's user folder.
$env:GRADLE_USER_HOME = $GradleHome

# --- local.properties --------------------------------------------------------
$props = Join-Path $android "local.properties"
$sdkLine = "sdk.dir=" + $sdk.Replace("\", "/")
if (-not (Test-Path $props) -or -not (Select-String -Path $props -SimpleMatch $sdkLine -Quiet)) {
    Set-Content -Path $props -Value $sdkLine -Encoding utf8NoBOM
    Write-Host "Wrote $props"
}

# --- Per-game BIOS -------------------------------------------------------------
# Every app bundles the free OpenBIOS. A game that needs Sony's BIOS names it in <GameDir>\android-bios.txt
# (one line, a file in framework\psxrecomp\bios\, e.g. SCPH1001.BIN): it is copied into this app and
# written into its game.toml.in, so the app passes it to the engine. Mizzurna Falls' fan translation
# keeps its own code in low RAM that OpenBIOS uses: fail-fast at 0x8000C000 (2026-10-09).
# Such an APK contains Sony's BIOS: for your own phone only, not for sharing.
$assets = Join-Path $android "app\src\main\assets"
$tomlIn = Join-Path $assets "game.toml.in"
$biosWant = Join-Path $GameDir "android-bios.txt"
$biosName = if (Test-Path $biosWant) { (Get-Content $biosWant -TotalCount 1).Trim() } else { "" }
Get-ChildItem (Join-Path $assets "bios") -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin "openbios.bin", "OpenBIOS.LICENSE", $biosName } | Remove-Item -Force
if ($biosName) {
    $src = Join-Path $FrameworkDir "bios\$biosName"
    if (-not (Test-Path $src)) { Write-Host "FAIL: android-bios.txt names $biosName, but $src does not exist"; exit 1 }
    New-Item -ItemType Directory -Force (Join-Path $assets "bios") | Out-Null
    Copy-Item $src (Join-Path $assets "bios\$biosName") -Force
    Write-Host "BIOS: $biosName (from android-bios.txt)"
}
if (Test-Path $tomlIn) {
    $want = if ($biosName) { "bios/$biosName" } else { "bios/openbios.bin" }
    $t = Get-Content $tomlIn -Raw
    $n = [regex]::Replace($t, '(?m)^path = "bios/[^"]*"', "path = `"$want`"")
    if ($n -ne $t) { Set-Content -Path $tomlIn -Value $n -NoNewline -Encoding utf8NoBOM }
}

# --- Gradle ------------------------------------------------------------------
$wrapper = Join-Path $android "gradle\wrapper\gradle-wrapper.jar"
# --no-daemon: no Gradle process stays running afterwards with files open on the USB drive.
# Push-Location is not needed: the job below starts in the android folder itself.
$gradleArgs = @("-classpath", $wrapper, "org.gradle.wrapper.GradleWrapperMain", "--no-daemon", ":app:assembleDebug")
if ($Play) { $gradleArgs += "-PpsxPlayBuild" }
# One signing key for every PC: Android only installs an update signed with the same key as the
# installed app. setup.ps1 puts the home PC's debug key (the one the installed games were first
# built with) on the drive; sign with it here, whichever PC builds. Without it Gradle uses this
# PC's own debug key, and the phone refuses the update (INSTALL_FAILED_UPDATE_INCOMPATIBLE).
# The GitHub build PC gets the same key from the workflow (a repository secret, written to a temporary
# file and passed as PSX_KEYSTORE); it wins over the drive's copy.
$sharedKey = if ($env:PSX_KEYSTORE) { $env:PSX_KEYSTORE } else { Join-Path $ToolsCache "debug.keystore" }
if (Test-Path $sharedKey) {
    $gradleArgs += @("-Pandroid.injected.signing.store.file=$sharedKey", "-Pandroid.injected.signing.store.password=android",
                     "-Pandroid.injected.signing.key.alias=androiddebugkey", "-Pandroid.injected.signing.key.password=android")
    Write-Host "Signing with the shared key ($sharedKey)"
} else {
    Write-Host "NOTE: no shared signing key on the drive yet (run tools\setup.ps1 on the home PC); using this PC's own key"
}
# SDL3 source: download it ONCE into tools-cache\deps (checked against the framework's pinned SHA-256) and
# point every build at it (PSX_SDL3_SOURCE_DIR, read by the framework's runtime.cmake). Before this, every game
# downloaded SDL itself, and a short internet drop failed the build (Gex 2, 2026-10-07).
$manifest = Join-Path $GameDir "psxrecomp\third_party\deps.manifest"
$sdlLine = if (Test-Path $manifest) { Get-Content $manifest | Where-Object { $_ -match '^SDL3\s' } | Select-Object -First 1 }
if ($sdlLine) {
    $f = $sdlLine -split '\s+'          # name, file, sha256, url
    $deps = Join-Path $ToolsCache "deps"
    $sdlDir = Join-Path $deps ($f[1] -replace '\.tar\.gz$', '')
    if (-not (Test-Path (Join-Path $sdlDir "CMakeLists.txt"))) {
        New-Item -ItemType Directory -Force $deps | Out-Null
        $tgz = Join-Path $deps $f[1]
        for ($try = 1; $try -le 5 -and -not (Test-Path $tgz); $try++) {
            Write-Host "Downloading $($f[1]) once for all builds (try $try)..."
            try { Invoke-WebRequest $f[3] -OutFile $tgz -UseBasicParsing } catch { Remove-Item $tgz -ErrorAction SilentlyContinue; Start-Sleep -Seconds (15 * $try) }
        }
        if ((Test-Path $tgz) -and (Get-FileHash $tgz -Algorithm SHA256).Hash -eq $f[2].ToUpper()) {
            & (Join-Path $env:SystemRoot "System32	ar.exe") -xzf $tgz -C $deps   # Windows tar (Git's tar misreads D: paths)
        } else {
            Remove-Item $tgz -ErrorAction SilentlyContinue
            Write-Host "NOTE: could not get a verified SDL3 copy; the build will try to download it itself"
        }
    }
    if (Test-Path (Join-Path $sdlDir "CMakeLists.txt")) { $env:PSX_SDL3_SOURCE_DIR = $sdlDir; Write-Host "SDL3 from $sdlDir (no download)" }
}
Write-Host "Building (the first build takes 30-60 minutes; later ones are much faster)..."
$log = Join-Path $GameDir "build-android.log"
$progress = Join-Path (Split-Path -Parent $PSScriptRoot) "progress.log"   # go.ps1's log, shown by watch.ps1

# Gradle runs as a background job so this window can print a heartbeat. The longest step
# (compiling the game's C code) prints nothing to the build log for many minutes; the
# heartbeat shows it is still working.
$job = Start-Job -ScriptBlock {
    param($java, $gradleArgs, $log, $dir, $gradleHome)
    Set-Location $dir
    $env:GRADLE_USER_HOME = $gradleHome
    & $java @gradleArgs *> $log
    $LASTEXITCODE
} -ArgumentList $java, $gradleArgs, $log, $android, $GradleHome

$started = Get-Date
while ($job.State -eq "Running") {
    Wait-Job $job -Timeout 60 | Out-Null
    if ($job.State -ne "Running") { break }
    $clang = @(Get-Process clang -ErrorAction SilentlyContinue)
    $what = if ($clang.Count) { "$($clang.Count) clang compiling" } else { "Gradle working (no compiler running right now)" }
    $ninja = Get-ChildItem (Join-Path $android "app\.cxx\Debug\*\arm64-v8a") -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ninja -and (Test-Path (Join-Path $ninja.FullName ".ninja_log")) -and (Test-Path (Join-Path $ninja.FullName "build.ninja"))) {
        $total = (Select-String -Path (Join-Path $ninja.FullName "build.ninja") -Pattern '^build \S+\.o:').Count
        $done = @(Get-Content (Join-Path $ninja.FullName ".ninja_log") | ForEach-Object { ($_ -split "`t")[3] } |
                  Where-Object { $_ -like "*.o" } | Sort-Object -Unique).Count
        if ($done -ge $total -and $clang.Count -eq 0) { $what = "all $total files compiled, linking (can take several minutes)" }
        else { $what += ", $done/$total files compiled" }
    }
    $line = "[{0}] BUILD: still working, {1} min so far: {2}" -f (Get-Date -Format "HH:mm:ss"), [int]((Get-Date) - $started).TotalMinutes, $what
    Write-Host $line
    Add-Content -Path $progress -Value $line
}
$code = Receive-Job $job | Select-Object -Last 1
Remove-Job $job
if ($null -eq $code) { $code = 1 }
if ($code -ne 0) {
    Write-Host "FAIL: Gradle build failed (exit $code). Last lines of $log :"
    Get-Content $log -Tail 25 | ForEach-Object { Write-Host "  $_" }
    exit 1
}
$apk = Join-Path $android "app\build\outputs\apk\debug\app-debug.apk"
if (-not (Test-Path $apk)) { Write-Host "FAIL: build said OK but $apk is missing"; exit 1 }
$apkDir = Join-Path $GameDir "apk"
New-Item -ItemType Directory -Force $apkDir | Out-Null
$kind = if ($Play) { "play" } else { "debug" }
$copy = Join-Path $apkDir ("{0}-{1}-{2}.apk" -f (Split-Path $GameDir -Leaf), $kind, (Get-Date -Format "yyyyMMdd-HHmm"))
Copy-Item $apk $copy
Write-Host "OK: built $copy"
exit 0
