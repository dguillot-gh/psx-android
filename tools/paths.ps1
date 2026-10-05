# Shared locations, dot-sourced by setup.ps1, build.ps1 and phone.ps1:   . (Join-Path $PSScriptRoot "paths.ps1")
# Everything lives on the USB drive next to this repo, not on the PC's C: drive:
#   <drive>\recomp-backups\tools-cache\jdk-17*        portable Java 17
#   <drive>\recomp-backups\tools-cache\android-sdk    Android SDK, NDK, CMake, adb
#   <drive>\recomp-backups\tools-cache\gradle         Gradle's download cache
#   <drive>\recomp-backups\android-recomp\<game>      ported games and their builds
$DriveRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # ...\recomp-backups
$ToolsCache = Join-Path $DriveRoot "tools-cache"
$SdkHome = Join-Path $ToolsCache "android-sdk"
$GradleHome = Join-Path $ToolsCache "gradle"
$DefaultWorkDir = Join-Path $DriveRoot "android-recomp"

function Find-Java {
    $c = @()
    Get-Item (Join-Path $ToolsCache "jdk-17*") -ErrorAction SilentlyContinue | ForEach-Object { $c += Join-Path $_.FullName "bin\java.exe" }
    if ($env:JAVA_HOME) { $c += Join-Path $env:JAVA_HOME "bin\java.exe" }
    foreach ($p in "C:\Program Files\Microsoft\jdk-17*", "C:\Program Files\Microsoft\jdk-21*", "C:\Program Files\Eclipse Adoptium\jdk-17*",
                   "C:\Program Files\Java\jdk-17*", "C:\Program Files\Android\Android Studio\jbr") {
        Get-Item $p -ErrorAction SilentlyContinue | ForEach-Object { $c += Join-Path $_.FullName "bin\java.exe" }
    }
    $c | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# The SDK on the drive wins; an SDK already installed on the PC is used only if the drive has none.
function Find-Sdk {
    @($SdkHome, $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
        Where-Object { $_ -and (Test-Path (Join-Path $_ "platform-tools")) } | Select-Object -First 1
}

function Find-Adb {
    $sdk = Find-Sdk
    if ($sdk -and (Test-Path (Join-Path $sdk "platform-tools\adb.exe"))) { return Join-Path $sdk "platform-tools\adb.exe" }
    $onPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    return "adb"
}
