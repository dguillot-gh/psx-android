Task: write tools\phone.ps1 (PowerShell only, no .bat or .cmd files).
It wraps the adb steps for one game app on the phone, with save backups built in.
Parameters: -Action <devices|backup-saves|install|launch> (required), -Package <app id, e.g. com.psxrecomp.tomba>,
-Apk <path>, -OutDir <folder for save backups, default: saves-backup next to this repo>, -Adb <adb path, default: adb>, -DryRun (switch).
Every adb call goes through one function. With -DryRun that function only prints "ADB: <arguments>" and runs nothing;
without -DryRun it prints the same line and then runs adb with those arguments.
Actions:
- devices: adb devices
- backup-saves (needs -Package): make OutDir\<Package>\<yyyyMMdd-HHmmss>\ (skip creating it with -DryRun), then for card1.mcd and card2.mcd:
  ADB: exec-out run-as <Package> cat files/<card>   (saved to that folder as <card>; with -DryRun print "ADB: exec-out run-as <Package> cat files/<card> > <full target path>")
  Without -DryRun, after each copy print the file size; a 0-byte file means the backup FAILED: print "FAIL: <card> backup empty" and exit 1.
- install (needs -Package and -Apk): first do backup-saves exactly as above, then ADB: install -r <Apk>
  If -Apk does not exist, print "FAIL: apk not found" and exit 1 before anything else.
- launch (needs -Package): ADB: shell monkey -p <Package> -c android.intent.category.LAUNCHER 1
A missing required parameter or an unknown action prints "FAIL: <reason>" and exits 1.
NEVER use uninstall, pm clear, rm, or anything that deletes data on the phone. Exit 0 on success.
If a detail is unclear, write UNKNOWN: <what you need> and stop.
DONE WHEN tools\check-04.ps1 exits 0.
