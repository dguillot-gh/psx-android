# Live view of the compiler while go.ps1 builds: one line per running process every 2 s, scrolling.
#   pwsh -File watch-compile.ps1
# clang   = one C file compiling (the file name is shown). CPU seconds should keep rising.
# ld.lld  = the linker (after all files are compiled; can take several minutes).
# java    = Gradle (packaging the APK, or between steps).
# Nothing at all for minutes = the build ended: look at the go.ps1 window / watch.ps1.
# Read-only: Ctrl+C stops only this window, never the build.
param([int]$Seconds = 2)
while ($true) {
    $now = Get-Date -Format HH:mm:ss
    $lines = @()
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='clang.exe'" -ErrorAction SilentlyContinue)) {
        $proc = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
        if (-not $proc) { continue }
        $file = if ($p.CommandLine -match '([\w.-]+\.c)\b') { $Matches[1] } else { "?" }
        $lines += "{0}  clang   {1,-30} CPU {2,8:N1} s   RAM {3,6:N0} MB" -f $now, $file, $proc.CPU, ($proc.WorkingSet64 / 1MB)
    }
    foreach ($proc in @(Get-Process ld.lld, lld, java -ErrorAction SilentlyContinue)) {
        $lines += "{0}  {1,-7} {2,-30} CPU {3,8:N1} s   RAM {4,6:N0} MB" -f $now, $proc.ProcessName, "", $proc.CPU, ($proc.WorkingSet64 / 1MB)
    }
    if (-not $lines.Count) { $lines += "$now  nothing compiling, linking or packaging right now" }
    $lines | ForEach-Object { Write-Host $_ }
    Start-Sleep -Seconds $Seconds
}
