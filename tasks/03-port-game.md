Task: write tools\port-game.ps1 (PowerShell only, no .bat or .cmd files).
It sets up one game for Android in a new folder, using the tools from tasks 01 and 02.
Parameters: -Name <game folder name, e.g. tomba2_recomp>, -SourceDir <folder holding the original game folders>,
-Framework <path to a psxrecomp folder>, -OutRoot <folder to create the game in>.
Steps:
1. $dest = OutRoot\Name. If $dest already exists, print "FAIL: <dest> exists" and exit 1 without changing anything.
2. Copy SourceDir\Name to $dest with robocopy, skipping the folders build-release and psxrecomp.
   robocopy exit codes 0-7 are success, 8 or more is failure.
3. Copy Framework to $dest\psxrecomp with robocopy, skipping the folder recompiler\build
   (use /XD with the full path of Framework\recompiler\build so recompiler\build-mingw is still copied).
4. Read $dest\game.toml as text: [game] id, [game] name, [game] exe, [controller] default_mode.
   Short = Name without "_recomp", keep only a-z and 0-9, lowercase. Example: tomba2_recomp -> tomba2.
   Title = [game] name with any trailing " (...)" groups removed. Example: "Parasite Eve II (USA, Canada) (Disc 1)" -> "Parasite Eve II".
   Exe = the file name part of [game] exe. Example: "disc/SCUS_944.54" -> SCUS_944.54.
   Project = Short with its first letter upper case, plus "Recomp". Example: tomba2 -> Tomba2Recomp.
5. Run tools\new-game.ps1 -GameName Name -PackageId com.psxrecomp.<Short> -GameId <id> -Title <Title> -OutDir $dest,
   adding -AnalogSticks only when default_mode is "analog".
6. Run tools\make-game-toml-in.ps1 -GameToml $dest\game.toml -Out $dest\android\app\src\main\assets\game.toml.in
7. Read template\CMakeLists.txt.in, drop its first 4 comment lines, replace @@PROJECT@@, @@TITLE@@, @@EXE@@,
   and write it to $dest\CMakeLists.txt (UTF-8, no BOM).
8. Print one summary line per step and exit 0.
Never delete or change anything in SourceDir or Framework. Never open, change or delete disc or saves files
(robocopy copying them is fine). If a detail is unclear, write UNKNOWN: <what you need> and stop.
DONE WHEN tools\check-03.ps1 exits 0.
