param([string]$Action, [string]$Package, [string]$Apk, [string]$OutDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "saves-backup"), [string]$Adb = "adb", [switch]$DryRun)
function Invoke-Adb([string[]]$a, [string]$To) {
    $line = "ADB: " + ($a -join " ")
    if ($To) { $line += " > $To" }
    Write-Host $line
    if ($DryRun) { return }
    if ($To) { & $Adb @a | Set-Content -Path $To -AsByteStream } else { & $Adb @a }
}
function Backup {
    if (-not $Package) { Write-Host "FAIL: -Package needed"; exit 1 }
    $dir = Join-Path (Join-Path $OutDir $Package) (Get-Date -Format "yyyyMMdd-HHmmss")
    if (-not $DryRun) { New-Item -ItemType Directory -Force $dir | Out-Null }
    foreach ($c in "card1.mcd", "card2.mcd") {
        $t = Join-Path $dir $c
        Invoke-Adb @("exec-out", "run-as", $Package, "cat", "files/$c") $t
        if (-not $DryRun) { $n = (Get-Item $t).Length; Write-Host "$c : $n bytes"; if ($n -eq 0) { Write-Host "FAIL: $c backup empty"; exit 1 } }
    }
}
switch ($Action) {
    "devices" { Invoke-Adb @("devices") }
    "backup-saves" { Backup }
    "install" {
        if (-not $Apk -or -not (Test-Path $Apk)) { Write-Host "FAIL: apk not found"; exit 1 }
        Backup; Invoke-Adb @("install", "-r", $Apk)
    }
    "launch" {
        if (-not $Package) { Write-Host "FAIL: -Package needed"; exit 1 }
        Invoke-Adb @("shell", "monkey", "-p", $Package, "-c", "android.intent.category.LAUNCHER", "1")
    }
    default { Write-Host "FAIL: unknown action '$Action'"; exit 1 }
}
exit 0
