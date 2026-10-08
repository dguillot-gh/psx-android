namespace PsxManager;

public sealed class GameInfo
{
    public required string Name { get; init; }
    public required bool InPipeline { get; init; }          // recomps\ (true) or recomps-later\ (set aside)
    public string Package => Paths.PackageOf(Name);
    public FileInfo? LastApk { get; set; }
    public bool? OnPhone { get; set; }
    public string LastTest { get; set; } = "";
    public long GeneratedMb { get; set; }
}

/// <summary>Builds the game list: recomps\ (+ recomps-later\), newest play APK, installed on the phone,
/// last test result, size of the generated code. Runs on a background thread.</summary>
public static class Games
{
    public static List<GameInfo> Scan(Paths p, bool includeLater, ISet<string>? installed)
    {
        var list = new List<GameInfo>();
        void Add(string dir, bool pipeline)
        {
            if (!Directory.Exists(dir)) return;
            foreach (var d in Directory.GetDirectories(dir).OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                list.Add(new GameInfo { Name = Path.GetFileName(d), InPipeline = pipeline });
        }
        Add(p.Recomps, true);
        if (includeLater) Add(p.Later, false);

        var apks = new List<FileInfo>();
        try
        {
            if (Directory.Exists(p.Apks))
                apks = new DirectoryInfo(p.Apks).EnumerateFiles("*-play-*.apk", SearchOption.AllDirectories).ToList();
        }
        catch { }

        foreach (var g in list)
        {
            g.LastApk = apks.Where(a => a.Name.StartsWith(g.Name + "-play-", StringComparison.OrdinalIgnoreCase))
                            .OrderBy(a => a.LastWriteTimeUtc).LastOrDefault();
            g.OnPhone = installed == null ? null : installed.Contains(g.Package);
            g.LastTest = LastTest(p, g.Name);
            g.GeneratedMb = GeneratedMb(p, g.Name);
        }
        return list;
    }

    private static string LastTest(Paths p, string game)
    {
        try
        {
            var dir = Path.Combine(p.WorkDir, game, "phone-test");
            if (!Directory.Exists(dir)) return "";
            var f = new DirectoryInfo(dir).EnumerateFiles("summary.txt", SearchOption.AllDirectories)
                        .OrderBy(x => x.LastWriteTimeUtc).LastOrDefault();
            if (f == null) return "";
            var s = File.ReadAllText(f.FullName).Trim();
            var m = System.Text.RegularExpressions.Regex.Match(s, @"GAME fps min ([\d.]+), average ([\d.]+)");
            if (m.Success) return $"~{double.Parse(m.Groups[2].Value, System.Globalization.CultureInfo.InvariantCulture):F0} fps";
            if (s.Contains("ended during the test")) return "crashed";
            if (s.Contains("game fps unknown")) return "ran (fps not logged)";
            return s.Length > 24 ? s[..24] + "..." : s;
        }
        catch { return ""; }
    }

    private static long GeneratedMb(Paths p, string game)
    {
        try
        {
            var dir = Path.Combine(p.WorkDir, game, "generated");
            if (!Directory.Exists(dir)) return 0;
            long sum = 0;
            foreach (var f in Directory.EnumerateFiles(dir, "*.c")) sum += new FileInfo(f).Length;
            return sum / 1048576;
        }
        catch { return 0; }
    }

    /// <summary>Installed game apps (null = no phone). Quick adb calls.</summary>
    public static (bool connected, HashSet<string>? installed, string free) Phone(Paths p)
    {
        var dev = Shell.Run(p.Adb, new[] { "devices" }, 8000);
        var connected = dev.Output.Split('\n').Skip(1).Any(l => l.TrimEnd().EndsWith("\tdevice"));
        if (!connected) return (false, null, "");
        var pk = Shell.Run(p.Adb, new[] { "shell", "pm", "list", "packages", "com.psxrecomp" }, 10000);
        var set = new HashSet<string>(pk.Output.Split('\n').Select(l => l.Trim()).Where(l => l.StartsWith("package:"))
                                         .Select(l => l["package:".Length..]), StringComparer.OrdinalIgnoreCase);
        var df = Shell.Run(p.Adb, new[] { "shell", "df", "-h", "/storage/emulated" }, 8000);
        var last = df.Output.Split('\n').Select(l => l.Trim()).LastOrDefault(l => l.Length > 0) ?? "";
        var cols = last.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var free = cols.Length >= 4 ? $"{cols[3]} free of {cols[1]}" : "";
        return (true, set, free);
    }
}
