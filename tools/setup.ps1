# Install whatever the build needs and is missing. Hand-written (not a model task).
#   pwsh -File tools\setup.ps1
# git and Java 17 come from winget. The Android SDK comes from Google's command-line tools:
# downloaded, licences accepted, then exactly the NDK/CMake/platform versions the app uses.
# Safe to rerun: anything already installed is left alone. Exit 0 = ready to build.
$ErrorActionPreference = "Stop"
$ndk = "ndk;28.2.13676358"; $cmake = "cmake;3.22.1"
# build-tools 34.0.0 is the default of the Android Gradle plugin the app uses (8.7.3).
$sdkPackages = @("platform-tools", "platforms;android-35", "build-tools;34.0.0", $ndk, $cmake)
$fail = @()

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Winget-Install($id, $what) {
    if (-not (Have winget)) { Write-Host "FAIL: $what is missing and winget is not available. Install $what by hand."; return $false }
    Write-Host "Installing $what with winget ($id)..."
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
    return $true
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

# --- git ---------------------------------------------------------------------
if (Have git) { Write-Host "OK   git" } else { Winget-Install "Git.Git" "git" | Out-Null; Refresh-Path; if (Have git) { Write-Host "OK   git (installed)" } else { $fail += "git" } }

# --- Java 17+ ----------------------------------------------------------------
function Find-Java {
    $c = @()
    if ($env:JAVA_HOME) { $c += Join-Path $env:JAVA_HOME "bin\java.exe" }
    foreach ($p in "C:\Program Files\Microsoft\jdk-17*", "C:\Program Files\Microsoft\jdk-21*", "C:\Program Files\Eclipse Adoptium\jdk-17*",
                   "C:\Program Files\Java\jdk-17*", "C:\Program Files\Android\Android Studio\jbr") {
        Get-Item $p -ErrorAction SilentlyContinue | ForEach-Object { $c += Join-Path $_.FullName "bin\java.exe" }
    }
    $onPath = Get-Command java -ErrorAction SilentlyContinue
    if ($onPath) { $c += $onPath.Source }
    $c | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$java = Find-Java
if (-not $java) { Winget-Install "Microsoft.OpenJDK.17" "Java 17" | Out-Null; Refresh-Path; $java = Find-Java }
if ($java) { Write-Host "OK   Java: $java" } else { $fail += "Java 17" }

# --- Android SDK ---------------------------------------------------------------
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"; New-Item -ItemType Directory -Force $sdk | Out-Null }
$need = $sdkPackages | Where-Object { -not (Test-Path (Join-Path $sdk ($_ -replace ";", "\"))) }
if (-not $need) {
    Write-Host "OK   Android SDK: $sdk (NDK, CMake, platform, build-tools, platform-tools all present)"
} elseif (-not $java) {
    $fail += "Android SDK packages (needs Java first)"
} else {
    $sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"
    if (-not (Test-Path $sdkmanager)) {
        Write-Host "Downloading Google's Android command-line tools..."
        $repo = Invoke-WebRequest "https://dl.google.com/android/repository/repository2-3.xml" -UseBasicParsing
        $m = [regex]::Match($repo.Content, '(?s)<remotePackage path="cmdline-tools;latest">.*?(commandlinetools-win-\d+_latest\.zip)')
        $zipName = if ($m.Success) { $m.Groups[1].Value } else { "commandlinetools-win-16111833_latest.zip" }
        $zip = Join-Path $env:TEMP $zipName
        Invoke-WebRequest "https://dl.google.com/android/repository/$zipName" -OutFile $zip -UseBasicParsing
        $unpack = Join-Path $env:TEMP "android-cmdline-tools"
        if (Test-Path $unpack) { Remove-Item $unpack -Recurse -Force }
        Expand-Archive $zip $unpack
        New-Item -ItemType Directory -Force (Join-Path $sdk "cmdline-tools") | Out-Null
        Move-Item (Join-Path $unpack "cmdline-tools") (Join-Path $sdk "cmdline-tools\latest")
        Remove-Item $zip, $unpack -Recurse -Force
    }
    $env:JAVA_HOME = Split-Path (Split-Path $java)
    Write-Host "Accepting Android SDK licences..."
    ("y`n" * 30) | & $sdkmanager "--sdk_root=$sdk" --licenses | Out-Null
    Write-Host "Installing: $($need -join ', ') (a few GB, can take a while)..."
    & $sdkmanager "--sdk_root=$sdk" @need | Out-Host
    $still = $sdkPackages | Where-Object { -not (Test-Path (Join-Path $sdk ($_ -replace ";", "\"))) }
    if ($still) { $fail += "Android SDK: $($still -join ', ')" } else { Write-Host "OK   Android SDK: $sdk (installed)" }
}
$env:ANDROID_HOME = $sdk   # this run only; build.ps1 finds the SDK in its standard folder by itself

if ($fail.Count) { Write-Host "FAIL: still missing: $($fail -join '; ')"; exit 1 }
Write-Host "SETUP OK"
exit 0
