# Report a problem: record everything a game logs on the phone while you play, then write a report
# with a plain-English verdict. Hand-written 2026-10-09 (PSX Manager's "Report a problem" button).
#   pwsh -File tools\report.ps1 -Package com.psxrecomp.tomba2 -Game tomba2_recomp
#   pwsh -File tools\report.ps1 -Package ... -Game ... -NoLaunch     (record a game you already opened)
#   pwsh -File tools\report.ps1 -Analyze <folder>                    (redo the verdict of an old report)
# Play until the problem happens. The report finishes by itself when the game crashes or you close it
# (swipe it away), or after -Minutes. Output: <drive>\recomp-backups\reports\<game>-<date>\
#   REPORT.txt   verdict, what to do next, the lines that matter
#   phone.log    everything the phone logged while recording
#   game.toml, psx_last_run_report.json   the game's settings and the engine's own crash report (if any)
# and a .zip of the folder, small enough to send to whoever fixes it.
param([string]$Package, [string]$Game, [int]$Minutes = 60, [switch]$NoLaunch, [string]$Analyze = "")
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")

function Write-Verdict([string]$dir) {
    $log = Join-Path $dir "phone.log"
    $info = Get-Content (Join-Path $dir "info.txt") -ErrorAction SilentlyContinue
    $pkg = ($info | Where-Object { $_ -match '^package=' }) -replace '^package=', ''
    $lines = @(Get-Content $log -ErrorAction SilentlyContinue)
    # The game runs in its own process "<package>:game"; collect its process ids from the start lines.
    $pids = @($lines | Select-String -Pattern "Start proc (\d+):$([regex]::Escape($pkg)):game" |
              ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -Unique)
    $mine = @($lines | Where-Object { $l = $_; $pids | Where-Object { $l -match " $_ " } })
    $engine = @($mine | Where-Object { $_ -match ' psxrecomp: ' })
    $fpsLines = @($engine | Where-Object { $_ -match '\[FPS\] game: ([\d.]+) fps' })
    $fps = @($fpsLines | ForEach-Object { if ($_ -match '\[FPS\] game: ([\d.]+) fps') { [double]$Matches[1] } } | Select-Object -Skip 2)

    $v = @(); $next = @(); $key = @()
    $native = @($mine | Where-Object { $_ -match ' F libc |Fatal signal|FORTIFY|Abort message|#\d\d pc ' })
    $java = @($lines | Where-Object { $_ -match "FATAL EXCEPTION|AndroidRuntime: Process: $([regex]::Escape($pkg))" })
    $anr = @($lines | Where-Object { $_ -match "ANR in $([regex]::Escape($pkg))" })
    $lmk = @($lines | Where-Object { $_ -match "lowmemorykiller: Kill '$([regex]::Escape($pkg))" })
    $died = @($lines | Where-Object { $_ -match "has died.*$([regex]::Escape($pkg)):game|$([regex]::Escape($pkg)):game \(pid \d+\) has died" })
    $guest = @($engine | Where-Object { $_ -match 'INTERP: |NULL jump|unknown COP|FAIL|FATAL|fatal|stale-static|dispatch miss' })

    if ($native) {
        $v += "CRASHED: the app stopped with a native crash."
        $f = ($native | Where-Object { $_ -match 'FORTIFY|Abort message' } | Select-Object -First 1)
        if ($f -match 'destroyed mutex') {
            $v += "  This is a side effect: the engine had already called exit() and Android's text drawing hit a lock freed by the exit. The real reason is the engine's (ENGINE STOPPED below, if any)."
        }
        $next += "Send this report to whoever maintains the engine; the backtrace lines below say where it died."
        $key += $native | Select-Object -First 40
    }
    if ($java) { $v += "CRASHED: the app's Java/menu side threw an error."; $key += $java | Select-Object -First 20 }
    if ($anr) { $v += "FROZE: Android said the app stopped responding (ANR)."; $key += $anr | Select-Object -First 5 }
    if ($lmk) {
        $v += "KILLED BY ANDROID: the phone ran low on memory and closed the game."
        $next += "Close other apps before playing; on the GPU renderer try a lower internal resolution."
        $key += $lmk | Select-Object -First 5
    }
    if ($guest) {
        $v += "GAME CODE PROBLEM: the engine reported code it could not run ($($guest.Count) line(s))."
        $next += "Play the same spot again so the phone records it, then Build / update (speed) the game; if it stays, it needs the recompiler."
        $key += $guest | Select-Object -First 20
    }
    if ($fps.Count -gt 0) {
        $avg = ($fps | Measure-Object -Average).Average
        $slow = @($fps | Where-Object { $_ -lt 50 }).Count
        $min = ($fps | Measure-Object -Minimum).Minimum
        $line = "Speed: average {0:N1} fps, lowest {1:N1}, {2} of {3} seconds under 50 fps." -f $avg, $min, $slow, $fps.Count
        if ($slow -gt [Math]::Max(5, $fps.Count / 10)) {
            $v += "SLOW: " + $line
            $next += "Slow spots usually speed up after playing them once and then running Build / update with the speed pre-compile."
        } else { $v += $line }
    }
    if (-not ($native -or $java -or $anr -or $lmk)) {
        if ($died) { $v += "The game was closed (no crash recorded): swiped away, or stopped by Android." }
        elseif ($pids.Count -eq 0) { $v += "The game never started while recording (was it open already? use -NoLaunch, or check the disc is picked)." }
        else { $v += "Still running when recording stopped; no crash recorded." }
        if ($fpsLines.Count -gt 0) {
            $v += "If the picture froze but this says it kept running, the GAME is stuck (engine still at full speed): note where, and send this report."
        }
    }
    $crash = Join-Path $dir "psx_last_run_report.json"
    if (Test-Path $crash) {
        $key += "", "Engine crash report (psx_last_run_report.json) is included."
        # The engine's own reason for stopping, when it stopped on purpose (fail-fast). report.ps1 pulls
        # the file after the run; it is this run's when its time is after the recording started.
        try {
            $j = Get-Content $crash -Raw | ConvertFrom-Json
            $rec = ($info | Where-Object { $_ -match '^recorded: ' }) -replace '^recorded: ', ''
            $fresh = (-not $rec) -or ([datetime]$j.timestamp).ToLocalTime() -ge ([datetime]$rec).AddMinutes(-1)
            if ($fresh -and $j.reason -and $j.reason -ne "atexit") {
                $v += "ENGINE STOPPED ON PURPOSE: $($j.reason -replace '\s+', ' ' -replace ' — see.*$', '')"
                if ($j.reason -match 'unknown dispatch: addr=0x8000([0-9A-F]{4})') {
                    $v += "  The game jumped into low RAM (0x8000$($Matches[1])), below its program: usually extra code from a fan translation / patch that expects Sony's BIOS."
                    $next += "Try Sony's BIOS for this game: put a file android-bios.txt containing SCPH1001.BIN in its android-recomp folder, then Build / update (Mizzurna Falls, 2026-10-09)."
                } elseif ($j.reason -match 'unknown dispatch') {
                    $next += "The game ran code the recompiler never found. Send this report to whoever maintains the engine."
                }
            }
        } catch { }
    }

    $out = @("PSX report for $pkg", ($info | Where-Object { $_ -notmatch '^package=' }), "",
             "VERDICT", ($v | ForEach-Object { "  $_" }), "")
    if ($next) { $out += "WHAT TO DO", ($next | Select-Object -Unique | ForEach-Object { "  $_" }), "" }
    $out += "ENGINE MESSAGES (start of the last run)", ($engine | Where-Object { $_ -notmatch '\[FPS\]' } | Select-Object -Last 30), ""
    if ($key) { $out += "KEY LINES", $key }
    Set-Content (Join-Path $dir "REPORT.txt") $out -Encoding utf8
    $v | ForEach-Object { Write-Host "VERDICT: $_" }
}

if ($Analyze) { Write-Verdict $Analyze; exit 0 }
if (-not $Package -or -not $Game) { Write-Host "FAIL: -Package and -Game are needed"; exit 1 }
$adb = Find-Adb
if (-not $adb) { Write-Host "FAIL: adb not found (run tools\setup.ps1)"; exit 1 }
if (-not (Get-Process adb -ErrorAction SilentlyContinue)) {   # detached: see phone.ps1
    Start-Process -FilePath $adb -ArgumentList "start-server" -WindowStyle Hidden; Start-Sleep -Seconds 3
}
if (-not (@(& $adb devices) -match "`tdevice$")) { Write-Host "FAIL: no phone connected (USB, unlocked, debugging allowed)"; exit 1 }

$dir = Join-Path (Join-Path $DriveRoot "reports") ("{0}-{1}" -f ($Game -replace '_recomp$', ''), (Get-Date -Format "yyyyMMdd-HHmm"))
New-Item -ItemType Directory -Force $dir | Out-Null
$apk = Get-ChildItem (Join-Path $DefaultWorkDir "$Game\apk") -Filter *.apk -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
$installed = ((& $adb shell dumpsys package $Package) -match 'lastUpdateTime' | Select-Object -First 1) -replace '^\s+', ''
Set-Content (Join-Path $dir "info.txt") @("package=$Package", "game: $Game", "recorded: $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
    "newest APK on the drive: $(if ($apk) { $apk.Name } else { 'none' })", "on the phone: $installed") -Encoding utf8

& $adb logcat -c
$log = Join-Path $dir "phone.log"
$rec = Start-Process -FilePath $adb -ArgumentList "logcat", "-v", "threadtime", "-b", "all" -RedirectStandardOutput $log -WindowStyle Hidden -PassThru
Write-Host "Recording to $dir"
if (-not $NoLaunch) {
    & $adb shell am force-stop $Package
    & $adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 *> $null
    Write-Host "Opened the game on the phone. Press Play, then play until the problem happens."
}
Write-Host "The report finishes when the game crashes or you close it (swipe it away), or after $Minutes min."

$seen = $false; $deadline = (Get-Date).AddMinutes($Minutes); $gpid = ""; $livePid = ""   # livePid: kept after the game ends, for its last lines
# Live view: the game's own lines appear here (PSX Manager's log window) as they happen. The frame rate is
# shown every 10 s instead of every second; Android's noise from other apps is left out (it's all in phone.log).
$pos = 0L; $lastFps = Get-Date; $partial = ""
function Show-NewLines {
    try {
        $fs = [System.IO.FileStream]::new($log, 'Open', 'Read', 'ReadWrite')
        if ($fs.Length -lt $script:pos) { $script:pos = 0 }
        $fs.Seek($script:pos, 'Begin') | Out-Null
        $sr = [System.IO.StreamReader]::new($fs)
        $text = $script:partial + $sr.ReadToEnd()
        $script:pos = $fs.Position
        $sr.Dispose()
    } catch { return }
    $parts = $text -split "`r?`n"
    $script:partial = $parts[-1]                       # an unfinished last line waits for the next read
    foreach ($l in $parts[0..($parts.Count - 2)]) {
        if (-not $l) { continue }
        $mine = $script:livePid -and $l -match " $($script:livePid) "
        if ($l -match '\[FPS\] game: ([\d.]+) fps') {
            if ($mine -and ((Get-Date) - $script:lastFps).TotalSeconds -ge 10) { $script:lastFps = Get-Date; Write-Host "game: $($Matches[1]) fps" }
        } elseif ($mine -and $l -match ' (psxrecomp|psxcrash|SDL/APP|libc|DEBUG|AndroidRuntime)\s*: (.*)$') {
            Write-Host "game: $($Matches[2])"
        } elseif ($l -match "FATAL EXCEPTION|ANR in $([regex]::Escape($Package))|lowmemorykiller: Kill '$([regex]::Escape($Package))|$([regex]::Escape($Package)):game.*has died") {
            Write-Host "phone: $($l -replace '^\S+ \S+\s+\d+\s+\d+\s+\w\s+', '')"
        }
    }
}
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    $gpid = ((& $adb shell pidof "$($Package):game" 2>$null) -join "").Trim()
    if ($gpid) {
        if (-not $seen) { Write-Host "Game running (process $gpid). Recording; its messages follow live:" }
        $seen = $true; $livePid = $gpid
    }
    Show-NewLines
    if (-not $gpid -and $seen) { Start-Sleep -Seconds 2; Show-NewLines; Write-Host "Game stopped. Finishing the report..."; break }
}
Start-Sleep -Seconds 3   # let the crash lines reach the log
Stop-Process -Id $rec.Id -Force -ErrorAction SilentlyContinue
foreach ($f in "game.toml", "psx_last_run_report.json") {
    $t = Join-Path $dir $f
    $p = Start-Process -FilePath $adb -ArgumentList "exec-out", "run-as", $Package, "cat", "files/$f" -RedirectStandardOutput $t -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0 -or (Get-Item $t).Length -eq 0 -or (Select-String -Path $t -Pattern 'No such file' -Quiet)) { Remove-Item $t -Force }
}
Write-Verdict $dir
$zip = "$dir.zip"
Compress-Archive -Path (Join-Path $dir "*") -DestinationPath $zip -Force
Write-Host "Report: $dir\REPORT.txt"
Write-Host "Zip to send: $zip"
exit 0
