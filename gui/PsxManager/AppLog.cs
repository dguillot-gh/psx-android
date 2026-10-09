using System.Text;

namespace PsxManager;

/// <summary>One log for everything PSX Manager does, kept whether or not a job runs:
/// psx-android-tools\logs\manager-&lt;date&gt;.log. Jobs' script output, the commands they ran and their exit
/// codes, what was clicked (with the ticked games and options), health checks during long steps, and
/// PSX Manager's own errors. Written so the log alone explains a problem on a PC nobody else can see.</summary>
public static class AppLog
{
    private static readonly object Gate = new();
    private static string? _dir;

    public static void Init(Paths paths)
    {
        _dir = paths.Logs;
        try { Directory.CreateDirectory(_dir); } catch { }
    }

    public static string CurrentFile => Path.Combine(_dir ?? ".", $"manager-{DateTime.Now:yyyyMMdd}.log");

    public static void Write(string line)
    {
        if (_dir == null) return;
        var text = $"[{DateTime.Now:HH:mm:ss}] {line}{Environment.NewLine}";
        lock (Gate)
        {
            try { File.AppendAllText(CurrentFile, text, Encoding.UTF8); } catch { }
        }
    }

    /// <summary>A block of lines (e.g. the tail of a game's build log), each prefixed so it reads as one unit.</summary>
    public static void Block(string title, IEnumerable<string> lines)
    {
        Write($"----- {title} -----");
        foreach (var l in lines) Write("  | " + l);
        Write($"----- end of {title} -----");
    }

    /// <summary>What a reader needs first: which PC, which copy of the project, disk space, engine version.</summary>
    public static IEnumerable<string> Context(Paths p)
    {
        yield return $"PC {Environment.MachineName}, {Environment.OSVersion.VersionString}, {Environment.ProcessorCount} CPU threads";
        yield return $"PSX Manager {File.GetLastWriteTime(Environment.ProcessPath ?? "").ToString("yyyy-MM-dd HH:mm")} at {AppContext.BaseDirectory}";
        yield return $"Project folder {p.DriveRoot}";
        string free;
        try { var d = new DriveInfo(Path.GetPathRoot(p.DriveRoot)!); free = $"{d.AvailableFreeSpace / 1073741824.0:N1} GB free of {d.TotalSize / 1073741824.0:N0} GB ({d.DriveType})"; }
        catch (Exception e) { free = "unknown (" + e.Message + ")"; }
        yield return $"Disk {free}";
        yield return $"Engine {GitHead(Path.Combine(p.DriveRoot, "framework", "psxrecomp"))}, scripts {GitHead(p.Tools)}";
    }

    private static string GitHead(string dir)
    {
        try
        {
            var r = Shell.Run("git", new[] { "-C", dir, "log", "-1", "--format=%h %cd %s", "--date=format:%Y-%m-%d" }, 5000);
            var s = r.Output.Trim();
            return r.Code == 0 && s != "" ? s : "(not a git copy)";
        }
        catch { return "(git not found)"; }
    }

    /// <summary>Last lines of a text file, for failure context. Shared read: the file may still be open.</summary>
    public static List<string> Tail(string file, int n)
    {
        var q = new Queue<string>();
        try
        {
            using var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            using var sr = new StreamReader(fs);
            string? l;
            while ((l = sr.ReadLine()) != null) { q.Enqueue(l); if (q.Count > n) q.Dequeue(); }
        }
        catch { }
        return q.ToList();
    }
}
