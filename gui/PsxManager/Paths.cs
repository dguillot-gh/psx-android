namespace PsxManager;

/// <summary>Where everything is. The app lives next to psx-android-tools (on the drive:
/// &lt;root&gt;\PSX-Manager\PSX-Manager.exe beside &lt;root&gt;\psx-android-tools), so it walks up from its own
/// folder until it finds go.ps1. Works on any drive letter and in a clone of the psx-android repository.</summary>
public sealed class Paths
{
    public string DriveRoot { get; }
    public string Tools { get; }        // psx-android-tools (go.ps1, tools\, easy\)
    public string Recomps => Path.Combine(DriveRoot, "recomps");
    public string Later => Path.Combine(DriveRoot, "recomps-later");
    public string WorkDir => Path.Combine(DriveRoot, "android-recomp");
    public string Apks => Path.Combine(DriveRoot, "apks");
    public string ToolsCache => Path.Combine(DriveRoot, "tools-cache");
    public string Logs => Path.Combine(Tools, "logs");
    public string Reports => Path.Combine(DriveRoot, "reports");   // tools\report.ps1 ("Report a problem")
    public string ProgressLog => Path.Combine(Tools, "progress.log");

    public string Pwsh
    {
        get
        {
            var p = Path.Combine(ToolsCache, "pwsh", "pwsh.exe");
            return File.Exists(p) ? p : "pwsh";
        }
    }

    public string Adb
    {
        get
        {
            var p = Path.Combine(ToolsCache, "android-sdk", "platform-tools", "adb.exe");
            if (File.Exists(p)) return p;
            var local = Environment.GetEnvironmentVariable("LOCALAPPDATA");
            if (local != null)
            {
                var q = Path.Combine(local, "Android", "Sdk", "platform-tools", "adb.exe");
                if (File.Exists(q)) return q;
            }
            return "adb";
        }
    }

    public string Gh => Path.Combine(ToolsCache, "gh", "bin", "gh.exe");

    private Paths(string driveRoot, string tools) { DriveRoot = driveRoot; Tools = tools; }

    public static Paths? Find(string start)
    {
        var dir = new DirectoryInfo(start);
        for (int i = 0; i < 6 && dir != null; i++, dir = dir.Parent)
        {
            var t = Path.Combine(dir.FullName, "psx-android-tools");
            if (File.Exists(Path.Combine(t, "go.ps1"))) return new Paths(dir.FullName, t);
            if (File.Exists(Path.Combine(dir.FullName, "go.ps1")) &&
                File.Exists(Path.Combine(dir.FullName, "tools", "paths.ps1")))
                return new Paths(dir.Parent?.FullName ?? dir.FullName, dir.FullName);
        }
        return null;
    }

    public static string PackageOf(string game) =>
        "com.psxrecomp." + new string(game.Replace("_recomp", "").ToLowerInvariant()
            .Where(char.IsAsciiLetterOrDigit).ToArray());
}
