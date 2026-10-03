param(
    [Parameter(Mandatory=$true)]
    [string]$GameName,

    [Parameter(Mandatory=$true)]
    [string]$PackageId,

    [Parameter(Mandatory=$true)]
    [string]$GameId,

    [Parameter(Mandatory=$true)]
    [string]$Title,

    [switch]$AnalogSticks,

    [Parameter(Mandatory=$true)]
    [string]$OutDir
)

$ErrorActionPreference = "Stop"

$templateDir = Join-Path $PSScriptRoot "..\template\android"
$outDir = Join-Path $PSScriptRoot "$OutDir"

# Step 1: Copy template\android to OutDir\android, skipping app\build, .cxx, .gradle
$excludedDirs = @("app\build", "app\.cxx", "app\.gradle")

function Get-ExcludedPaths {
    param([string]$BasePath)
    $results = @()
    foreach ($ex in $excludedDirs) {
        $path = Join-Path $BasePath "$ex"
        if (Test-Path $path) {
            $results += $path
        }
    }
    return $results
}

$excludedPaths = Get-ExcludedPaths -BasePath $templateDir

Copy-Item -Path $templateDir -Destination $outDir -Recurse -Force -Exclude @($excludedPaths)

# Step 2: Replace the old package id com.psxrecomp.tomba with -PackageId in every text file
function Get-TextFiles {
    param([string]$BasePath)
    $results = @()
    foreach ($dir in (Get-ChildItem -Path $BasePath -Directory -Recurse)) {
        foreach ($file in (Get-ChildItem -Path $dir.FullName -Filter "*.txt" -Include "*.gradle", "*.xml")) {
            # Skip files outside OutDir
            if ($file.FullName -notlike "$outDir\*") {
                continue
            }
            # Skip game.toml.in (handled by hand)
            if ($file.Name -eq "game.toml.in") {
                continue
            }
            $results += $file
        }
    }
    return $results
}

$textFiles = Get-TextFiles -BasePath $outDir

foreach ($file in $textFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $newContent = $content -replace 'com\.psxrecomp\.tomba', $PackageId
    Set-Content -Path $file.FullName -Value $newContent -NoNewline
}

# Step 3: In app\src\main\res\values\strings.xml set app_name, psx_game_title and psx_game_id
$stringsXml = Join-Path $outDir "app\src\main\res\values\strings.xml"
if (Test-Path $stringsXml) {
    $content = Get-Content -Path $stringsXml -Raw
    $newContent = $content -replace '<string name="app_name">.*?</string>', "<string name=`"app_name`">$Title</string>"
    $newContent = $newContent -replace '<string name="psx_game_title">.*?</string>', "<string name=`"psx_game_title`">$Title</string>"
    $newContent = $newContent -replace '<string name="psx_game_id">.*?</string>', "<string name=`"psx_game_id`">$GameId</string>"
    Set-Content -Path $stringsXml -Value $newContent -NoNewline
}

# Step 4: In bools.xml set psx_analog_sticks to true if -AnalogSticks is given, otherwise false
$boolsXml = Join-Path $outDir "app\src\main\res\values\bools.xml"
if (Test-Path $boolsXml) {
    $content = Get-Content -Path $boolsXml -Raw
    if ($AnalogSticks) {
        $newContent = $content -replace '<bool name="psx_analog_sticks">false</bool>', "<bool name=`"psx_analog_sticks`">true</bool>"
    } else {
        $newContent = $content -replace '<bool name="psx_analog_sticks">true</bool>', "<bool name=`"psx_analog_sticks`">false</bool>"
    }
    Set-Content -Path $boolsXml -Value $newContent -NoNewline
}

Write-Host "New game '$GameName' created successfully in $outDir"
