# Policenauts Android build

This is a separate Android application build. It uses the same generated game
code and native runtime as the desktop build, with SDL's Android Activity and
NDK integration.

## Build requirements

- Android Studio or the Android SDK command-line tools
- Android NDK 28.2.13676358 and CMake (the Gradle project pins the NDK version)
- JDK 17 or newer
- An Android device or emulator using `arm64-v8a`

## Build and install

From this directory, run:

```powershell
gradlew.bat :app:assembleDebug
gradlew.bat :app:installDebug
```

The native build uses the game project's top-level `CMakeLists.txt`. The Android
package loads the native runtime as `libmain.so`; desktop builds continue to
produce `Policenauts.exe` as before.

## Current port work

The SDL Android project shell, app-private writable paths, first-run disc-folder
import, PS1 Mouse SIO protocol, and visible left/right touch buttons are in
place. The Debug APK has compiled successfully for `arm64-v8a`, but has not yet
been installed or run on a device, so gameplay is not yet verified.

The app can import both discs from a common folder, or prompt for the Disc 1 and
Disc 2 folders separately. Each selected folder must contain its `.cue` file
and referenced track files. Disc images are copied into app-private storage.
Game data is not bundled in the APK; the runtime reads the boot executable from
the imported disc image. The licensed OpenBIOS runtime is staged from the
project/framework during the Android build.
