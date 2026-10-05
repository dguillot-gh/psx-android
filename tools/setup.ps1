# Install whatever the build needs and is missing, onto the USB drive (not the PC's C: drive).
#   pwsh -File tools\setup.ps1
# Java 17: Microsoft's portable JDK zip, unpacked into <drive>\recomp-backups\tools-cache.
# Android SDK: Google's command-line tools into tools-cache\android-sdk, licences accepted, then exactly
# the NDK/CMake/platform versions the app uses. Python 3 (portable, for the overlay pre-compile)
# into tools-cache\python. git is optional (only used to commit model work).
# Safe to rerun: anything already there is left alone. Exit 0 = ready to build. Hand-written.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")
$ndk = "ndk;28.2.13676358"; $cmake = "cmake;3.22.1"
# build-tools 34.0.0 is the default of the Android Gradle plugin the app uses (8.7.3).
$sdkPackages = @("platform-tools", "platforms;android-35", "build-tools;34.0.0", $ndk, $cmake)
$fail = @()
New-Item -ItemType Directory -Force $ToolsCache | Out-Null

function Unzip-Into($url, $what) {
    $zip = Join-Path $ToolsCache "download.zip"
    Write-Host "Downloading $what..."
    Invoke-WebRequest $url -OutFile $zip -UseBasicParsing
    $unpack = Join-Path $ToolsCache "unpack"
    if (Test-Path $unpack) { Remove-Item $unpack -Recurse -Force }
    Expand-Archive $zip $unpack
    Remove-Item $zip -Force
    return $unpack
}

# --- git (optional) ------------------------------------------------------------
if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host "OK   git" }
else { Write-Host "NOTE git not found: not needed for porting or building (install with: winget install --id Git.Git -e)" }

# --- Java 17 -------------------------------------------------------------------
$java = Find-Java
if (-not $java) {
    $unpack = Unzip-Into "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip" "Java 17 (about 190 MB)"
    Get-ChildItem $unpack -Directory | ForEach-Object { Move-Item $_.FullName (Join-Path $ToolsCache $_.Name) }
    Remove-Item $unpack -Recurse -Force
    $java = Find-Java
}
if ($java) { Write-Host "OK   Java: $java" } else { $fail += "Java 17" }

# --- Android SDK ---------------------------------------------------------------
$sdk = Find-Sdk
if (-not $sdk) { $sdk = $SdkHome }
$need = $sdkPackages | Where-Object { -not (Test-Path (Join-Path $sdk ($_ -replace ";", "\"))) }
# An SDK on the PC is used only if it is already complete; anything missing goes onto the drive.
if ($need -and $sdk -ne $SdkHome) {
    $sdk = $SdkHome
    $need = $sdkPackages | Where-Object { -not (Test-Path (Join-Path $sdk ($_ -replace ";", "\"))) }
}
if (-not $need) {
    Write-Host "OK   Android SDK: $sdk (NDK, CMake, platform, build-tools, platform-tools all present)"
} elseif (-not $java) {
    $fail += "Android SDK packages (needs Java first)"
} else {
    New-Item -ItemType Directory -Force $sdk | Out-Null
    $sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkmanager)) {
        $repo = Invoke-WebRequest "https://dl.google.com/android/repository/repository2-3.xml" -UseBasicParsing
        $m = [regex]::Match($repo.Content, '(?s)<remotePackage path="cmdline-tools;latest">.*?(commandlinetools-win-\d+_latest\.zip)')
        $zipName = if ($m.Success) { $m.Groups[1].Value } else { "commandlinetools-win-16111833_latest.zip" }
        $unpack = Unzip-Into "https://dl.google.com/android/repository/$zipName" "Android command-line tools (about 150 MB)"
        New-Item -ItemType Directory -Force (Join-Path $sdk "cmdline-tools") | Out-Null
        Move-Item (Join-Path $unpack "cmdline-tools") (Join-Path $sdk "cmdline-tools\latest")
        Remove-Item $unpack -Recurse -Force
    }
    $env:JAVA_HOME = Split-Path (Split-Path $java)
    Write-Host "Accepting Android SDK licences..."
    ("y`n" * 30) | & $sdkmanager "--sdk_root=$sdk" --licenses | Out-Null
    Write-Host "Installing into $sdk : $($need -join ', ') (a few GB, can take a while)..."
    & $sdkmanager "--sdk_root=$sdk" @need | Out-Host
    $still = $sdkPackages | Where-Object { -not (Test-Path (Join-Path $sdk ($_ -replace ";", "\"))) }
    if ($still) { $fail += "Android SDK: $($still -join ', ')" } else { Write-Host "OK   Android SDK: $sdk (installed)" }
}

# --- Python 3 (overlay pre-compile tools) -----------------------------------------
# The official Windows Python as a NuGet package: a plain zip with tools\python.exe and the
# standard library, no installer, nothing written outside the drive.
$py = Find-Python
if (-not $py) {
    $ver = "3.12.10"
    $nupkg = Join-Path $ToolsCache "python.zip"
    Write-Host "Downloading Python $ver (about 15 MB)..."
    Invoke-WebRequest "https://api.nuget.org/v3-flatcontainer/python/$ver/python.$ver.nupkg" -OutFile $nupkg -UseBasicParsing
    if (Test-Path $PythonHome) { Remove-Item $PythonHome -Recurse -Force }
    Expand-Archive $nupkg $PythonHome
    Remove-Item $nupkg -Force
    $py = Find-Python
}
if ($py) { Write-Host "OK   Python: $py" } else { $fail += "Python 3" }

if ($fail.Count) { Write-Host "FAIL: still missing: $($fail -join '; ')"; exit 1 }
Write-Host "SETUP OK"
exit 0
