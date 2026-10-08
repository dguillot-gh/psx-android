# Status: what's built, what's on the phone, and the last test result of each game. Changes nothing.
. (Join-Path $PSScriptRoot "_common.ps1")
Title "Status"
$phone = Phone-Connected
if ($phone) { Good "Phone connected." } else { Warn "Phone not connected (phone columns left empty)." }
$installed = @{}
if ($phone) {
    foreach ($l in & $Adb shell pm list packages com.psxrecomp 2>$null) { if ($l -match 'package:(\S+)') { $installed[$Matches[1]] = $true } }
}
$rows = foreach ($g in Get-Games -IncludeLater) {
    $pkg = Get-Package $g
    $apk = Get-ChildItem (Join-Path $DriveRoot "apks") -Recurse -Filter "$g-play-*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    $test = Get-ChildItem (Join-Path $WorkDir "$g\phone-test") -Recurse -Filter summary.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    $sum = if ($test) { ((Get-Content $test.FullName -Raw) -replace '\s+', ' ').Trim() } else { "" }
    if ($sum -match 'GAME fps min [\d.]+, average ([\d.]+)') { $sum = "game fps ~$($Matches[1])" } elseif ($sum.Length -gt 40) { $sum = $sum.Substring(0, 40) + "..." }
    [pscustomobject]@{
        Game        = $g
        Where       = if (Test-Path (Join-Path $Recomps $g)) { "pipeline" } else { "set aside" }
        "Last APK"  = if ($apk) { $apk.LastWriteTime.ToString("yyyy-MM-dd HH:mm") } else { "-" }
        "On phone"  = if (-not $phone) { "?" } elseif ($installed[$pkg]) { "yes" } else { "no" }
        "Last test" = $sum
    }
}
$rows | Format-Table -AutoSize | Out-Host
$free = Get-PSDrive ($DriveRoot.Substring(0, 1)) -ErrorAction SilentlyContinue
if ($free) { Info ("Drive free space: {0:N0} GB" -f ($free.Free / 1GB)) }
if ($phone) {
    $df = (& $Adb shell df -h /storage/emulated 2>$null | Select-Object -Last 1) -split '\s+'
    if ($df.Count -ge 4) { Info "Phone free space: $($df[3]) of $($df[1])" }
}
Pause-End
