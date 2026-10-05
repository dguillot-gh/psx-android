# adb steps for one game app on the phone, with save backups built in. Hand-written.
#   pwsh -File tools\phone.ps1 -Action connect
#   pwsh -File tools\phone.ps1 -Action backup-saves -Package com.psxrecomp.tomba2
#   pwsh -File tools\phone.ps1 -Action install -Package com.psxrecomp.tomba2 -Apk <path>   (backs up saves first)
#   pwsh -File tools\phone.ps1 -Action launch -Package com.psxrecomp.tomba2
#   pwsh -File tools\phone.ps1 -Action push-disc -Folder C:\recomp\tomba2_recomp\disc -Name tomba2_recomp
# -DryRun prints the adb commands ("ADB: ...") without running anything.
param([string]$Action, [string]$Package, [string]$Apk, [string]$Folder, [string]$Name,
      [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "saves-backup"),
      [string]$Adb = "", [switch]$DryRun)

# adb: the given path, else the SDK's platform-tools (drive first), else PATH.
. (Join-Path $PSScriptRoot "paths.ps1")
if (-not $Adb) { $Adb = Find-Adb }
$CardSize = 131072   # a PS1 memory card image is exactly 128 KB

function Invoke-Adb([string[]]$a, [string]$To) {
    $line = "ADB: " + ($a -join " ")
    if ($To) { $line += " > $To" }
    Write-Host $line
    if ($DryRun) { return }
    if ($To) {
        # adb writes the file itself: raw bytes, never re-encoded by PowerShell.
        $p = Start-Process -FilePath $Adb -ArgumentList $a -RedirectStandardOutput $To -NoNewWindow -Wait -PassThru
        $global:LASTEXITCODE = $p.ExitCode
    } else { & $Adb @a }
}

function Backup {
    if (-not $Package) { Write-Host "FAIL: -Package needed"; exit 1 }
    $dir = Join-Path (Join-Path $OutDir $Package) (Get-Date -Format "yyyyMMdd-HHmmss")
    if (-not $DryRun) {
        $installed = @(& $Adb shell pm path $Package 2>$null) -match '^package:'
        if (-not $installed) { Write-Host "$Package is not on the phone yet: nothing to back up."; return }
    }
    foreach ($c in "card1.mcd", "card2.mcd") {
        if (-not $DryRun) {
            & $Adb shell run-as $Package ls "files/$c" *> $null
            if ($LASTEXITCODE -ne 0) { Write-Host "$c : none on the phone yet"; continue }
            New-Item -ItemType Directory -Force $dir | Out-Null
        }
        $t = Join-Path $dir $c
        Invoke-Adb @("exec-out", "run-as", $Package, "cat", "files/$c") $t
        if (-not $DryRun) {
            $n = (Get-Item $t).Length
            if ($n -ne $CardSize) { Write-Host "FAIL: $c backup is $n bytes, expected $CardSize. Nothing was installed."; exit 1 }
            Write-Host "$c : backed up to $t"
        }
    }
}

function Connect {
    $ready = @(& $Adb devices) | Where-Object { $_ -match "`tdevice$" }
    if ($ready) { Write-Host "Phone connected: $($ready[0])"; return $true }
    # Wireless debugging: a phone paired once shows up in mDNS; connect to it.
    $found = @(& $Adb mdns services) | Where-Object { $_ -match '_adb-tls-connect' }
    foreach ($s in $found) {
        if ($s -match '(\d+\.\d+\.\d+\.\d+:\d+)') { & $Adb connect $Matches[1] | Out-Host }
    }
    $ready = @(& $Adb devices) | Where-Object { $_ -match "`tdevice$" }
    if ($ready) { Write-Host "Phone connected: $($ready[0])"; return $true }
    Write-Host "No phone connected. Turn on Wireless debugging (pair once with: adb pair <ip:port>), or plug in USB."
    return $false
}

switch ($Action) {
    "devices" { Invoke-Adb @("devices") }
    "connect" { if ($DryRun) { Invoke-Adb @("devices") } elseif (-not (Connect)) { exit 1 } }
    "backup-saves" { Backup }
    "install" {
        if (-not $Apk -or -not (Test-Path $Apk)) { Write-Host "FAIL: apk not found"; exit 1 }
        if (-not $Package) { Write-Host "FAIL: -Package needed"; exit 1 }
        Backup
        Invoke-Adb @("install", "-r", $Apk)
        if (-not $DryRun -and $LASTEXITCODE -ne 0) { Write-Host "FAIL: adb install failed"; exit 1 }
    }
    "push-disc" {
        # Copy a game's disc images to the phone's Download\<Name> folder, where the app's
        # "Select game file" picker can find them. Files already there at the same size are skipped.
        if (-not $Folder -or -not (Test-Path $Folder)) { Write-Host "FAIL: -Folder (the game's disc folder) not found"; exit 1 }
        if (-not $Name) { Write-Host "FAIL: -Name needed (folder name to use on the phone)"; exit 1 }
        $remote = "/sdcard/Download/$Name"
        Invoke-Adb @("shell", "mkdir", "-p", $remote)
        Get-ChildItem $Folder -File | Where-Object { $_.Extension -in ".cue", ".bin", ".img", ".iso", ".chd" } | ForEach-Object {
            $dest = "$remote/$($_.Name)"
            if (-not $DryRun) {
                $have = (& $Adb shell stat -c %s "`"$dest`"" 2>$null) -join ""
                if ($have.Trim() -eq "$($_.Length)") { Write-Host "$($_.Name) : already on the phone"; return }
            }
            Invoke-Adb @("push", $_.FullName, $dest)
            if (-not $DryRun -and $LASTEXITCODE -ne 0) { Write-Host "FAIL: pushing $($_.Name)"; exit 1 }
        }
    }
    "launch" {
        if (-not $Package) { Write-Host "FAIL: -Package needed"; exit 1 }
        Invoke-Adb @("shell", "monkey", "-p", $Package, "-c", "android.intent.category.LAUNCHER", "1")
    }
    default { Write-Host "FAIL: unknown action '$Action'"; exit 1 }
}
exit 0
