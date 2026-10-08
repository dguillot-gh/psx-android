# Rebuild PSX Manager (the window app) after changing its code in gui\PsxManager\.
# Makes ONE self-contained exe (its own .NET runtime inside: nothing to install on any PC) at
# <drive>\PSX-Manager\PSX-Manager.exe, next to psx-android-tools. Needs the .NET SDK (10) on the PC that builds;
# the exe itself runs on any 64-bit Windows 10/11 without .NET.
#   pwsh -File gui\build-manager.ps1
$ErrorActionPreference = "Stop"
$proj = Join-Path $PSScriptRoot "PsxManager\PsxManager.csproj"
$out = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "PSX-Manager"
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Write-Host "FAIL: the .NET SDK isn't installed on this PC (only needed to REBUILD the app)."; exit 1 }
dotnet publish $proj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:DebugType=none -o $out
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: publish"; exit 1 }
Get-ChildItem $out | Where-Object { $_.Name -ne "PSX-Manager.exe" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
$exe = Get-Item (Join-Path $out "PSX-Manager.exe")
Write-Host ("OK: {0} ({1:N0} MB)" -f $exe.FullName, ($exe.Length / 1MB))
