# Build a ported game's Android APK. Written by hand (not a model task).
#   pwsh -File tools\build.ps1 -GameDir C:\recomp\tomba2_recomp [-Play]
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

# --- Java ------------------------------------------------------------------
$javaCandidates = @()
if ($env:JAVA_HOME) { $javaCandidates += Join-Path $env:JAVA_HOME "bin\java.exe" }
foreach ($pattern in "C:\Program Files\Microsoft\jdk-17*", "C:\Program Files\Eclipse Adoptium\jdk-17*",
                     "C:\Program Files\Java\jdk-17*", "C:\Program Files\Android\Android Studio\jbr") {
    Get-Item $pattern -ErrorAction SilentlyContinue | ForEach-Object { $javaCandidates += Join-Path $_.FullName "bin\java.exe" }
}
$onPath = Get-Command java -ErrorAction SilentlyContinue
if ($onPath) { $javaCandidates += $onPath.Source }
$java = $javaCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $java) { Write-Host "FAIL: no Java found. Install JDK 17 (e.g. winget install Microsoft.OpenJDK.17) or Android Studio."; exit 1 }
Write-Host "Java: $java"

# --- Android SDK -----------------------------------------------------------
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $sdk) { Write-Host "FAIL: no Android SDK found. Install Android Studio, open it once, and let it install the SDK."; exit 1 }
Write-Host "SDK:  $sdk"
$missing = @()
if (-not (Test-Path (Join-Path $sdk "ndk\$ndkVersion"))) { $missing += "ndk;$ndkVersion" }
if (-not (Test-Path (Join-Path $sdk "cmake\$cmakeVersion"))) { $missing += "cmake;$cmakeVersion" }
if ($missing.Count) {
    Write-Host "FAIL: the SDK is missing: $($missing -join ', ')"
    Write-Host "Install them in Android Studio (Settings > Android SDK > SDK Tools, tick 'Show Package Details'),"
    $quoted = ($missing | ForEach-Object { '"' + $_ + '"' }) -join ' '
    Write-Host ('or run: "' + $sdk + '\cmdline-tools\latest\bin\sdkmanager.bat" ' + $quoted)
    exit 1
}

# --- local.properties --------------------------------------------------------
$props = Join-Path $android "local.properties"
$sdkLine = "sdk.dir=" + $sdk.Replace("\", "/")
if (-not (Test-Path $props) -or -not (Select-String -Path $props -SimpleMatch $sdkLine -Quiet)) {
    Set-Content -Path $props -Value $sdkLine -Encoding utf8NoBOM
    Write-Host "Wrote $props"
}

# --- Gradle ------------------------------------------------------------------
$wrapper = Join-Path $android "gradle\wrapper\gradle-wrapper.jar"
$gradleArgs = @("-classpath", $wrapper, "org.gradle.wrapper.GradleWrapperMain", ":app:assembleDebug")
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
