Task: write tools\new-game.ps1 (PowerShell only, no .bat or .cmd files).
It creates a new game's Android app from the template in template\android.
Reference: handbook section 10, step 4. If a detail isn't there, write UNKNOWN: <what you need> and stop.
Parameters: -GameName, -PackageId, -GameId, -Title, -AnalogSticks (switch), -OutDir.
1. Copy template\android to OutDir\android, skipping app\build, .cxx, .gradle.
2. Replace the old package id com.psxrecomp.tomba with -PackageId in every text file
   (app\build.gradle namespace, both AndroidManifest.xml files, resources).
3. In app\src\main\res\values\strings.xml set app_name, psx_game_title (-Title) and psx_game_id (-GameId).
   In bools.xml set psx_analog_sticks to true if -AnalogSticks is given, otherwise false.
Do NOT change com.psxrecomp.android or org.libsdl.app. The template has no Java under com\psxrecomp, only org\libsdl\app.
Never delete anything outside OutDir. Never touch disc, saves, or memory card files.
Skip app\src\main\assets\game.toml.in. It is handled by hand.
DONE WHEN tools\check.ps1 exits 0.
