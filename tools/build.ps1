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

# --- Gradle ------------------------------------------------------------------
$wrapper = Join-Path $android "gradle\wrapper\gradle-wrapper.jar"
# --no-daemon: no Gradle process stays running afterwards with files open on the USB drive.
$gradleArgs = @("-classpath", $wrapper, "org.gradle.wrapper.GradleWrapperMain", "--no-daemon", ":app:assembleDebug")
if ($Play) { $gradleArgs += "-PpsxPlayBuild" }
Write-Host "Building (the first build takes about 30 minutes; later ones are much faster)..."
$log = Join-Path $GameDir "build-android.log"
Push-Location $android
try {
    & $java @gradleArgs *> $log
    $code = $LASTEXITCODE
} finally { Pop-Location }
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
