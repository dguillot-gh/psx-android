# Watch go.ps1 from a second PowerShell window. Refreshes every few seconds; Ctrl+C to stop watching
# (that never affects go.ps1).
#   pwsh -File watch.ps1
param([int]$Seconds = 5, [string]$WorkDir = "")
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot "tools\paths.ps1")
if (-not $WorkDir) { $WorkDir = $DefaultWorkDir }
$progress = Join-Path $PSScriptRoot "progress.log"

while ($true) {
    $out = @()
    $out += "go.ps1 progress   (refreshes every $Seconds s, Ctrl+C to stop watching)   $(Get-Date -Format 'HH:mm:ss')"
    $out += ("-" * 100)
    if (Test-Path $progress) {
        # Only the latest run: from the last "go.ps1 started" line on.
        $lines = Get-Content $progress
        $start = 0
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "go\.ps1 started") { $start = $i } }
        $out += $lines[$start..($lines.Count - 1)] | Select-Object -Last 18
    } else {
        $out += "No progress.log yet: start go.ps1 in another window."
    }

    $apks = @(Get-ChildItem (Join-Path $WorkDir "*\apk\*.apk") -ErrorAction SilentlyContinue)
    $out += ""
    $out += "APKs built so far: $($apks.Count)" + $(if ($apks.Count) { "  (" + (($apks | ForEach-Object { $_.Directory.Parent.Name } | Sort-Object -Unique) -join ", ") + ")" } else { "" })

    # The build log written most recently = the game building right now.
    $log = Get-ChildItem (Join-Path $WorkDir "*\build-android.log") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($log) {
        $age = [int]((Get-Date) - $log.LastWriteTime).TotalSeconds
        $out += ""
        $out += "Build log: $($log.FullName)   (last written $age s ago)"
        $out += ("-" * 100)
        $out += Get-Content $log.FullName -Tail 12 | ForEach-Object { if ($_.Length -gt 160) { $_.Substring(0, 160) } else { $_ } }
    }
    try { Clear-Host } catch { }
    $out | ForEach-Object { Write-Host $_ }
    Start-Sleep -Seconds $Seconds
}
