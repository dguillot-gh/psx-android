using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

namespace PsxManager;

public enum Verdict { Idle, Working, QuietBusy, Stuck, Problem }

public sealed record WorkerInfo(string Name, int Pid, double CpuPercent, double MemGb, TimeSpan Age);

public sealed record HealthReport(
    Verdict Verdict,
    string Headline,
    string Phase,
    TimeSpan PhaseAge,
    TimeSpan QuietFor,
    double FreeRamGb,
    double TotalRamGb,
    List<WorkerInfo> Workers,
    List<string> Hints);

/// <summary>Watches a running job and answers "is it working, or stuck?" in plain words. Looks at: when the job
/// last printed anything (its own output, progress.log, the current game's build log), which tool programs are
/// busy (CPU and memory), free memory, the current phase from go.ps1's heartbeat lines, and known problems
/// from today's experience (internet drop, phone full, unplugged phone, GT2-style giant code).</summary>
public sealed class Health
{
    private static readonly string[] WorkerNames =
        { "clang", "clang++", "ld.lld", "lld", "ld", "java", "ninja", "cmake", "python", "adb", "git", "gh", "psxrecomp-game", "robocopy", "tar" };

    private readonly Paths _paths;
    private readonly Dictionary<int, (TimeSpan cpu, DateTime at)> _prevCpu = new();
    private string _phase = "";
    private DateTime _phaseSinceUtc = DateTime.UtcNow;
    private readonly List<string> _recentLines = new();

    public Health(Paths paths) { _paths = paths; }

    /// <summary>Feed every output line here (for phase tracking and known-problem hints).</summary>
    public void Observe(string line)
    {
        lock (_recentLines)
        {
            _recentLines.Add(line);
            if (_recentLines.Count > 400) _recentLines.RemoveRange(0, 100);
        }
        var phase = PhaseOf(line);
        if (phase != null && phase != _phase) { _phase = phase; _phaseSinceUtc = DateTime.UtcNow; }
    }

    public void ResetPhase() { _phase = ""; _phaseSinceUtc = DateTime.UtcNow; lock (_recentLines) _recentLines.Clear(); }

    // go.ps1 / build.ps1 / speed.ps1 heartbeat lines -> a short phase name.
    private static string? PhaseOf(string l)
    {
        if (l.Contains("PORT:")) return "Copying the game and engine";
        if (l.Contains("REGEN:")) return "Generating the game's C code";
        if (l.Contains("SPEED:") && l.Contains("compiling")) return "Speed pre-compile";
        if (l.Contains("SPEED:")) return "Speed pre-compile (preparing)";
        if (l.Contains("linking")) return "Linking (joining everything into the app)";
        if (Regex.IsMatch(l, @"\d+/\d+ files compiled") || l.Contains("clang compiling")) return "Compiling the game";
        if (l.Contains("Gradle working")) return "Android build tools working";
        if (l.Contains("BUILD: started")) return "Starting the app build";
        if (l.Contains("RECOMPILER:")) return "Building the recompiler";
        if (l.Contains("PHONE:") && l.Contains("installing")) return "Installing on the phone";
        if (l.Contains("PHONE:") && l.Contains("copying the disc")) return "Copying the disc to the phone";
        if (l.Contains("test-running")) return "Test run on the phone";
        if (l.Contains("SETUP:")) return "Checking tools";
        return null;
    }

    public HealthReport Check(JobRunner runner)
    {
        var (freeGb, totalGb) = Memory();
        var workers = Workers();
        var hints = new List<string>();

        if (!runner.Busy)
            return new HealthReport(Verdict.Idle, "Nothing running.", "", TimeSpan.Zero, TimeSpan.Zero, freeGb, totalGb, workers, hints);

        // Last sign of life: job output, progress.log, or the current game's build log.
        var last = runner.LastOutputUtc;
        last = Max(last, WriteTime(_paths.ProgressLog));
        var game = runner.Current?.Game;
        string? genMbText = null;
        long genMb = 0;
        if (game != null)
        {
            last = Max(last, WriteTime(Path.Combine(_paths.WorkDir, game, "build-android.log")));
            genMb = GeneratedMb(game);
            if (genMb > 0) genMbText = $"{genMb:N0} MB";
        }
        var quiet = DateTime.UtcNow - last;
        var phaseAge = DateTime.UtcNow - _phaseSinceUtc;
        var cpu = workers.Sum(w => w.CpuPercent);
        var busyWorker = workers.OrderByDescending(w => w.CpuPercent).FirstOrDefault();

        // Known problems seen in the output.
        string[] recent;
        lock (_recentLines) recent = _recentLines.TakeLast(200).ToArray();
        bool Seen(string s) => recent.Any(l => l.Contains(s, StringComparison.OrdinalIgnoreCase));
        if (Seen("Couldn't resolve host") || Seen("Could not resolve host") || Seen("download failed"))
            hints.Add("The internet dropped during a download. When this step ends, press the same button again: it continues.");
        if (Seen("INSUFFICIENT_STORAGE") || Seen("No space left"))
            hints.Add("The phone is full. Use 'Phone storage' to remove spare disc copies, then try again.");
        if (Seen("no devices/emulators found") || Seen("No phone connected"))
            hints.Add("The phone isn't connected: plug in the USB cable, unlock it, tap Allow on 'USB debugging'.");
        if (Seen("INSTALL_FAILED_UPDATE_INCOMPATIBLE"))
            hints.Add("The phone has this game signed with another key. The shared key must be in tools-cache\\debug.keystore (see CLAUDE.md, Signing).");
        if (Seen("out of memory") || Seen("std::bad_alloc") || Seen("killed signal"))
            hints.Add("A compiler ran out of memory. Close other programs and run it again (it continues).");
        if (genMb > 300)
            hints.Add($"This game's generated code is abnormally large ({genMbText}; normal games are 2-60 MB). It's the 'data-as-code' problem (GT2, Legend of Dragoon): compiling and especially linking may take many hours or never finish. Consider stopping it and leaving the game out until the recompiler is fixed.");
        if (freeGb < 0.8)
            hints.Add($"The PC is almost out of memory ({freeGb:F1} GB free): everything slows to a crawl. Close other programs.");

        Verdict v;
        string head;
        var who = busyWorker != null && busyWorker.CpuPercent > 3
            ? $"{FriendlyName(busyWorker.Name)} is working ({busyWorker.CpuPercent:F0}% CPU, {busyWorker.MemGb:F1} GB memory)"
            : "";
        if (quiet < TimeSpan.FromMinutes(3))
        {
            v = Verdict.Working;
            head = "Working normally." + (who != "" ? " " + who + "." : "");
        }
        else if (cpu > 5)
        {
            v = Verdict.QuietBusy;
            head = $"No new output for {Fmt(quiet)}, but {who}. That's normal for long compile and link steps.";
            if (_phase.StartsWith("Linking") && phaseAge > TimeSpan.FromMinutes(45) && genMb <= 300)
                hints.Add("Linking is taking unusually long (normal: under 20 minutes). If it passes 2 hours, stop and run it again.");
        }
        else if (quiet > TimeSpan.FromMinutes(10))
        {
            v = Verdict.Stuck;
            head = $"Looks stuck: no output and almost no CPU for {Fmt(quiet)}.";
            hints.Add("Press Stop, then the same button again: finished work is kept and it continues from there. If it sticks at the same point twice, the log above shows where.");
        }
        else
        {
            v = Verdict.QuietBusy;
            head = $"Quiet for {Fmt(quiet)} (waiting on something). Keep an eye on it; after 10 minutes like this it counts as stuck.";
        }
        if (hints.Count > 0 && v == Verdict.Working && hints.Any(h => h.Contains("internet") || h.Contains("full") || h.Contains("isn't connected")))
            v = Verdict.Problem;

        return new HealthReport(v, head, _phase, phaseAge, quiet, freeGb, totalGb, workers, hints);
    }

    private List<WorkerInfo> Workers()
    {
        var now = DateTime.UtcNow;
        var list = new List<WorkerInfo>();
        var seen = new HashSet<int>();
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                var n = p.ProcessName.ToLowerInvariant();
                if (!WorkerNames.Contains(n)) continue;
                seen.Add(p.Id);
                var cpuNow = p.TotalProcessorTime;
                double pct = 0;
                if (_prevCpu.TryGetValue(p.Id, out var prev))
                {
                    var wall = (now - prev.at).TotalMilliseconds;
                    if (wall > 0) pct = (cpuNow - prev.cpu).TotalMilliseconds / wall * 100.0 / Environment.ProcessorCount * Environment.ProcessorCount;
                }
                _prevCpu[p.Id] = (cpuNow, now);
                // pct is "percent of one core"; show it as a share of the whole PC instead.
                var share = pct / Environment.ProcessorCount;
                list.Add(new WorkerInfo(n, p.Id, share, p.WorkingSet64 / 1073741824.0, now - p.StartTime.ToUniversalTime()));
            }
            catch { /* access denied / exited */ }
            finally { p.Dispose(); }
        }
        foreach (var dead in _prevCpu.Keys.Where(k => !seen.Contains(k)).ToList()) _prevCpu.Remove(dead);
        return list.OrderByDescending(w => w.CpuPercent).ThenByDescending(w => w.MemGb).ToList();
    }

    private long GeneratedMb(string game)
    {
        try
        {
            var dir = Path.Combine(_paths.WorkDir, game, "generated");
            if (!Directory.Exists(dir)) return 0;
            long sum = 0;
            foreach (var f in Directory.EnumerateFiles(dir, "*.c")) sum += new FileInfo(f).Length;
            return sum / 1048576;
        }
        catch { return 0; }
    }

    public static string FriendlyName(string n) => n switch
    {
        "clang" or "clang++" => "The C compiler (clang)",
        "ld.lld" or "lld" or "ld" => "The linker (ld.lld)",
        "java" => "The Android build tools (Gradle)",
        "ninja" or "cmake" => "The build planner (CMake/Ninja)",
        "python" => "The speed pre-compile (Python)",
        "adb" => "The phone connection (adb)",
        "psxrecomp-game" => "The recompiler",
        "git" or "gh" => "Git / GitHub",
        _ => n,
    };

    public static string Fmt(TimeSpan t) =>
        t.TotalHours >= 1 ? $"{(int)t.TotalHours} h {t.Minutes} min" : t.TotalMinutes >= 1 ? $"{(int)t.TotalMinutes} min" : $"{t.Seconds} s";

    private static DateTime Max(DateTime a, DateTime b) => a > b ? a : b;

    private static DateTime WriteTime(string path)
    {
        try { return File.Exists(path) ? File.GetLastWriteTimeUtc(path) : DateTime.MinValue; } catch { return DateTime.MinValue; }
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MEMORYSTATUSEX
    {
        public uint dwLength, dwMemoryLoad;
        public ulong ullTotalPhys, ullAvailPhys, ullTotalPageFile, ullAvailPageFile, ullTotalVirtual, ullAvailVirtual, ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll")] private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX m);

    public static (double freeGb, double totalGb) Memory()
    {
        var m = new MEMORYSTATUSEX { dwLength = (uint)Marshal.SizeOf<MEMORYSTATUSEX>() };
        return GlobalMemoryStatusEx(ref m) ? (m.ullAvailPhys / 1073741824.0, m.ullTotalPhys / 1073741824.0) : (0, 0);
    }
}
