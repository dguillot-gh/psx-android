# adb steps for one game app on the phone, with save backups built in. Hand-written.
#   pwsh -File tools\phone.ps1 -Action connect
#   pwsh -File tools\phone.ps1 -Action backup-saves -Package com.psxrecomp.tomba2
#   pwsh -File tools\phone.ps1 -Action install -Package com.psxrecomp.tomba2 -Apk <path>   (backs up saves first)
#   pwsh -File tools\phone.ps1 -Action launch -Package com.psxrecomp.tomba2
#   pwsh -File tools\phone.ps1 -Action push-disc -Folder <drive>\recomp-backups\android-recomp\tomba2_recomp\disc -Name tomba2_recomp
#   pwsh -File tools\phone.ps1 -Action pull-captures -Package com.psxrecomp.tomba2 -To <file>
#       the overlay code the game saved while playing (files/overlay_captures.json); read-only
#   pwsh -File tools\phone.ps1 -Action play-test -Package com.psxrecomp.tomba2 -OutDir <folder> [-Seconds 90]
#       opens the game, presses Play, then records frame rate, screenshots and the game's log
# -DryRun prints the adb commands ("ADB: ...") without running anything.
param([string]$Action, [string]$Package, [string]$Apk, [string]$Folder, [string]$Name, [string]$To,
      [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "saves-backup"),
      [int]$Seconds = 90, [string]$Adb = "", [switch]$DryRun)

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
    "home" { Invoke-Adb @("shell", "input", "keyevent", "KEYCODE_HOME") }
    "pull-captures" {
        # Read-only: copies the game's own record of code it loaded while playing. Exit 2 = none yet.
        if (-not $Package -or -not $To) { Write-Host "FAIL: -Package and -To needed"; exit 1 }
        & $Adb shell run-as $Package ls files/overlay_captures.json *> $null
        if ($LASTEXITCODE -ne 0) { Write-Host "$Package : no play captures on the phone yet"; exit 2 }
        Invoke-Adb @("exec-out", "run-as", $Package, "cat", "files/overlay_captures.json") $To
        Write-Host "$Package : play captures saved to $To ($((Get-Item $To).Length) bytes)"
    }
    "play-test" {
        # Opens the game, presses Play on its start menu, then for -Seconds: frame rate every 10 s
        # (from Android's own frame timing, works on play builds), three screenshots, and the
        # game's log. Exit 2 = no disc picked yet in the app (pick it once on the phone).
        if (-not $Package -or -not $OutDir) { Write-Host "FAIL: -Package and -OutDir needed"; exit 1 }
        New-Item -ItemType Directory -Force $OutDir | Out-Null
        $ui = Join-Path $OutDir "ui.xml"
        function Read-Screen { & $Adb shell uiautomator dump /sdcard/psx-ui.xml *> $null; Invoke-Adb @("exec-out", "cat", "/sdcard/psx-ui.xml") $ui | Out-Null; Get-Content $ui -Raw }
        Invoke-Adb @("shell", "monkey", "-p", $Package, "-c", "android.intent.category.LAUNCHER", "1") | Out-Null
        Start-Sleep -Seconds 5
        $screen = Read-Screen
        if ($screen -match 'No game file selected') { Write-Host "$Package : no disc picked yet in the app. Pick it once on the phone (Select game file)."; exit 2 }
        # Operators only (-match/$Matches, -f): works in constrained PowerShell too.
        if ($screen -notmatch 'text="PLAY"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"') { Write-Host "FAIL: the start menu's PLAY button was not found (see $ui)"; exit 1 }
        $x = [int](([int]$Matches[1] + [int]$Matches[3]) / 2); $y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
        # Phone clock at the moment Play is pressed: the log is taken from here on.
        $since = ((& $Adb shell "date '+%m-%d %H:%M:%S.000'") -join "").Trim()
        $sinceArg = "`"$since`""   # quoted: Start-Process joins arguments with plain spaces
        Invoke-Adb @("shell", "input", "tap", "$x", "$y")
        Start-Sleep -Seconds 8
        $fps = @(); $shots = 0; $t = 8
        while ($t -lt $Seconds) {
            # The game's SurfaceView layer, e.g. "52c5536 SurfaceView[com.psxrecomp.persona/...PsxGameActivity](BLAST)#6254"
            $layer = (& $Adb shell dumpsys SurfaceFlinger --list) | ForEach-Object {
                if ($_.Contains("SurfaceView[$Package/") -and $_ -match '([0-9a-f]+ SurfaceView\[[^\]]+\]\(BLAST\)#\d+)') { $Matches[1] } } |
                Select-Object -Last 1
            if ($layer) {
                $times = @(& $Adb shell "dumpsys SurfaceFlinger --latency '$layer'" | Select-Object -Skip 1 |
                    ForEach-Object { $p = $_ -split '\s+'; if ($p.Count -ge 2 -and $p[1] -match '^\d+$' -and $p[1].Length -lt 19 -and [int64]$p[1] -gt 0) { [int64]$p[1] } })
                if ($times.Count -gt 10) {
                    $span = ($times[-1] - $times[0]) / 1e9
                    if ($span -gt 0) { $f = [double]("{0:F1}" -f (($times.Count - 1) / $span)); $fps += $f; Write-Host ("  {0,3} s: {1} fps" -f $t, $f) }
                }
            }
            # Screenshots 10 s after Play, then every 30 s (3 at most): 18, 48, 78 s.
            if ($shots -lt 3 -and (($t - 8) % 30) -eq 10) {
                $shots++; Invoke-Adb @("exec-out", "screencap", "-p") (Join-Path $OutDir "screen-$shots.png") | Out-Null
            }
            Start-Sleep -Seconds 10; $t += 10
        }
        $gamePid = ((& $Adb shell pidof "$($Package):game") -join "").Trim()
        $log = Join-Path $OutDir "logcat.txt"
        if ($gamePid) { Invoke-Adb @("logcat", "-d", "-T", $sinceArg, "--pid=$gamePid") $log | Out-Null }
        else { Write-Host "NOTE: the game process is not running anymore (crashed or closed); saving the crash log."; Invoke-Adb @("logcat", "-d", "-T", $sinceArg) $log | Out-Null }
        Invoke-Adb @("logcat", "-d", "-b", "crash", "-T", $sinceArg) (Join-Path $OutDir "crash.txt") | Out-Null
        $st = $fps | Measure-Object -Minimum -Average -Maximum
        $summary = if ($fps.Count) { "fps min {0}, average {1:F1}, max {2} ({3} samples)" -f $st.Minimum, $st.Average, $st.Maximum, $fps.Count } else { "no frame timing (the game may not have drawn anything)" }
        if (-not $gamePid) { $summary = "game process ended during the test; " + $summary }
        Set-Content (Join-Path $OutDir "summary.txt") $summary
        Write-Host "$Package : $summary. Screenshots and log in $OutDir"
        Remove-Item $ui -ErrorAction SilentlyContinue
    }
    default { Write-Host "FAIL: unknown action '$Action'"; exit 1 }
}
exit 0
