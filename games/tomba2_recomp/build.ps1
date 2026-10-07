# Build script for Tomba! 2 - The Evil Swine Return Recomp
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1
param([string]$Config = "Release")
$proj = $PSScriptRoot
$build = Join-Path $proj "build-$Config"
cmake -S "$proj" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=$Config
cmake --build "$build" --target psx-runtime -j$([Environment]::ProcessorCount)
