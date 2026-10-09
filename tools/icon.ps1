# Give a game's Android app its own icon made from the game's box art. Hand-written.
#   pwsh -File tools\icon.ps1 -GameDir <drive>\recomp-backups\android-recomp\persona2_recomp [-Force]
# 1. Box art: <GameDir>\launcher_assets\img\boxart.png, downloaded once from libretro-thumbnails by the
#    framework's fetch_boxart.py (needs internet; matched by the disc's file name; attribution is saved
#    next to it in BOXART_SOURCE.txt). An existing boxart.png is used as is (you can drop your own in).
# 2. tools\MakeIcon.java (JDK only): crops the PlayStation spine, squares it -> res\drawable-nodpi\ic_launcher_art.png.
# 3. The adaptive icon: the cover inset in the round icon (ic_launcher_fg.xml), on the cover's average
#    colour (ic_launcher_bg.xml).
# Skips a game that already has its icon unless -Force. Exit 0 = icon set, 2 = no box art (old icon kept).
param([Parameter(Mandatory = $true)][string]$GameDir, [switch]$Force)
. (Join-Path $PSScriptRoot "paths.ps1")
$res = Join-Path $GameDir "android\app\src\main\res"
$artOut = Join-Path $res "drawable-nodpi\ic_launcher_art.png"
if (-not (Test-Path $res)) { Write-Host "FAIL: no Android app in $GameDir"; exit 1 }
if ((Test-Path $artOut) -and -not $Force) { Write-Host "icon: already set"; exit 0 }

$img = Join-Path $GameDir "launcher_assets\img"
$box = Join-Path $img "boxart.png"
if (-not (Test-Path $box)) {
    $py = Find-Python
    $cue = Get-ChildItem (Join-Path $GameDir "disc") -Filter *.cue -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
    if (-not $py -or -not $cue) { Write-Host "icon: no Python or no disc; keeping the default icon"; exit 2 }
    New-Item -ItemType Directory -Force $img | Out-Null
    Push-Location $GameDir
    # The archive names covers by their Redump name; a few discs carry a longer region than the
    # cover entry ("(USA, Canada)" vs "(USA)"), so that shorter form is tried too.
    $short = $cue.BaseName -replace '\(USA, Canada\)', '(USA)'
    $stem = $cue.BaseName
    # boxart-name.txt (in the game's folder or recomps\<name>, exported with the game): the cover's exact
    # name in libretro-thumbnails, for discs whose name differs (fan translations, "Einhaender").
    $override = @((Join-Path $GameDir "boxart-name.txt"),
                  (Join-Path $DriveRoot ("recomps\" + (Split-Path $GameDir -Leaf) + "\boxart-name.txt"))) |
                Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($override) { $short = (Get-Content $override -TotalCount 1).Trim(); $stem = $short }
    & $py psxrecomp\tools\new_project_layout\fetch_boxart.py --cue-stem $stem --name $short `
        --out (Join-Path $img "boxart.tga") --png-out $box *> (Join-Path $img "fetch.log")
    Pop-Location
    if (-not (Test-Path $box)) { Write-Host "icon: no box art found online (see $img\fetch.log); keeping the default icon"; exit 2 }
}

$java = Find-Java
if (-not $java) { Write-Host "icon: no Java; keeping the default icon"; exit 2 }
New-Item -ItemType Directory -Force (Split-Path $artOut) | Out-Null
# "-D..." must be quoted: unquoted, PowerShell splits it at the first dot.
$color = (@(& $java "-Djava.awt.headless=true" (Join-Path $PSScriptRoot "MakeIcon.java") $box $artOut) -join "").Trim()
if ($LASTEXITCODE -ne 0 -or $color -notmatch '^#[0-9A-F]{6}$' -or -not (Test-Path $artOut)) { Write-Host "icon: FAIL making the icon image"; exit 1 }

Set-Content (Join-Path $res "drawable\ic_launcher_fg.xml") -Encoding utf8NoBOM -Value @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Launcher foreground: the game's box art (tools\icon.ps1), inset so the round mask frames it. -->
<inset xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/ic_launcher_art"
    android:inset="20dp" />
'@
Set-Content (Join-Path $res "drawable\ic_launcher_bg.xml") -Encoding utf8NoBOM -Value @"
<?xml version="1.0" encoding="utf-8"?>
<!-- Launcher background: the box art's average colour (tools\icon.ps1). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="$color" android:pathData="M0,0 h108 v108 h-108 z" />
</vector>
"@
Write-Host "icon: box art icon set ($color background)"
exit 0
