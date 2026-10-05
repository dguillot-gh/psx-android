# THE ONE COMMAND. Every game on the drive, start to finish, unattended:
#   pwsh -File RUN-ALL.ps1
# For each game in ..\recomps (all of them, including new ones such as ff7_recomp; Tomba 1 is done):
#   recomp (generate the C code with the newest recompiler) -> pre-compile the game's disc code ->
#   Android play build (box-art icon, on-screen pad, save states, multi-disc) -> APK copy on the drive ->
#   phone: back up saves, install, copy the discs, import a brought-along memory card -> launch and
#   test-run each game (fps, screenshots, log in android-recomp\<game>\phone-test\).
# Same as: pwsh -File go.ps1 -Game all -Speed   (extra options pass through, e.g. -NoPhone)
# Watch it: pwsh -File watch.ps1  and  pwsh -File watch-compile.ps1  in other windows.
pwsh -NoProfile -File (Join-Path $PSScriptRoot "go.ps1") -Game all -Speed @args
exit $LASTEXITCODE
