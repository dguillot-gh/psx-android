using System.Diagnostics;
using System.Text;

namespace PsxManager;

/// <summary>One command in a job. Args are made when the step STARTS (so a step can use what earlier
/// steps produced, e.g. the newest APK). Skip-if lets a step skip itself (e.g. install after a failed build).</summary>
public sealed class Step
{
    public required string Title { get; init; }
    public string? Game { get; init; }
    public required Func<List<string>> Args { get; init; }       // full pwsh argument list
    public Func<bool>? SkipIf { get; init; }
    public Action<Step, bool>? After { get; init; }               // (step, ok) when it ends
    public bool Ok { get; set; }
}

/// <summary>Runs steps one at a time (two builds at once crashed PowerShell on 2026-10-07), streaming every
/// output line to the window and to a log file. Stop kills the whole process tree; the pipeline resumes
/// from what's saved the next time.</summary>
public sealed class JobRunner
{
    private readonly Paths _paths;
    private readonly Queue<Step> _queue = new();
    private Process? _proc;
    private StreamWriter? _log;
    private bool _stopping;

    public event Action<string, LineKind>? Line;
    public event Action? StateChanged;
    public event Action<string>? JobFinished;

    public Step? Current { get; private set; }
    public string JobName { get; private set; } = "";
    public int StepIndex { get; private set; }
    public int StepCount { get; private set; }
    public DateTime StepStartedUtc { get; private set; }
    public DateTime LastOutputUtc { get; private set; }
    public bool Busy => Current != null;
    public int? ProcessId => _proc is { HasExited: false } ? _proc.Id : null;
    public readonly List<string> Results = new();
    public readonly Dictionary<string, bool> GameOk = new(StringComparer.OrdinalIgnoreCase);

    public JobRunner(Paths paths) { _paths = paths; }

    public void Start(string jobName, IEnumerable<Step> steps)
    {
        if (Busy) throw new InvalidOperationException("A job is already running.");
        _queue.Clear();
        foreach (var s in steps) _queue.Enqueue(s);
        JobName = jobName;
        StepCount = _queue.Count;
        StepIndex = 0;
        Results.Clear();
        GameOk.Clear();
        _stopping = false;
        Directory.CreateDirectory(_paths.Logs);
        var logPath = Path.Combine(_paths.Logs, $"manager-{DateTime.Now:yyyyMMdd}.log");
        _log = new StreamWriter(new FileStream(logPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite), Encoding.UTF8) { AutoFlush = true };
        Emit($"===== {DateTime.Now:yyyy-MM-dd HH:mm:ss}  {jobName} ({StepCount} step(s)) =====", LineKind.Header);
        Emit($"(this log is also saved in {logPath})", LineKind.Info);
        Next();
    }

    public void Stop()
    {
        if (!Busy) return;
        _stopping = true;
        _queue.Clear();
        Emit("Stopping... (safe: finished work is kept; run the same job again to continue)", LineKind.Warn);
        try { _proc?.Kill(true); } catch { }
    }

    private void Next()
    {
        while (_queue.Count > 0)
        {
            var s = _queue.Dequeue();
            StepIndex++;
            if (s.SkipIf?.Invoke() == true)
            {
                Emit($"--- step {StepIndex}/{StepCount}: {s.Title}: skipped", LineKind.Info);
                continue;
            }
            Current = s;
            StepStartedUtc = DateTime.UtcNow;
            LastOutputUtc = DateTime.UtcNow;
            Emit($"--- step {StepIndex}/{StepCount}: {s.Title}", LineKind.Header);
            try { Launch(s); }
            catch (Exception e)
            {
                Emit($"Could not start: {e.Message}", LineKind.Bad);
                Finish(s, false);
                continue;
            }
            StateChanged?.Invoke();
            return;
        }
        // Queue empty: job done.
        var name = JobName;
        Current = null;
        Emit($"===== {name}: finished {DateTime.Now:HH:mm} =====", LineKind.Header);
        foreach (var r in Results) Emit("  " + r, r.Contains(": ok") || r.Contains("installed") ? LineKind.Good : LineKind.Warn);
        _log?.Dispose();
        _log = null;
        StateChanged?.Invoke();
        JobFinished?.Invoke(name);
    }

    private void Launch(Step s)
    {
        var psi = new ProcessStartInfo(_paths.Pwsh)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = _paths.Tools,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        foreach (var a in s.Args()) psi.ArgumentList.Add(a);
        psi.Environment["PSX_GUI"] = "1";                 // easy\ scripts: no "Press Enter" pauses
        psi.Environment["NO_COLOR"] = "1";
        var p = new Process { StartInfo = psi, EnableRaisingEvents = true };
        p.OutputDataReceived += (_, e) => { if (e.Data != null) OnOutput(s, e.Data); };
        p.ErrorDataReceived += (_, e) => { if (e.Data != null) OnOutput(s, e.Data); };
        p.Exited += (_, _) => OnExited(s, p);
        p.Start();
        p.BeginOutputReadLine();
        p.BeginErrorReadLine();
        _proc = p;
    }

    private void OnOutput(Step s, string raw)
    {
        LastOutputUtc = DateTime.UtcNow;
        var line = StripAnsi(raw);
        if (line.Length == 0) return;
        // go.ps1 summary lines: "[hh:mm:ss] game : ok, APK ..." / "... : FAIL ..."
        if (s.Game != null && line.Contains($"] {s.Game} : "))
        {
            var ok = line.Contains($"{s.Game} : ok");
            s.Ok = ok;
            GameOk[s.Game] = ok;
            Results.Add(line[(line.IndexOf(']') + 2)..]);
        }
        if (line.Contains("PHONE PASS SUMMARY")) s.Ok = true;
        Emit(line, Classify(line));
    }

    private void OnExited(Step s, Process p)
    {
        p.WaitForExit();   // drain the async output first
        var code = p.ExitCode;
        if (s.Game == null) s.Ok = code == 0;
        Finish(s, s.Ok);
    }

    private void Finish(Step s, bool ok)
    {
        if (s.Game != null && !GameOk.ContainsKey(s.Game)) { GameOk[s.Game] = ok; Results.Add($"{s.Game} : {(ok ? "ok" : "did not finish")}"); }
        var mins = (DateTime.UtcNow - StepStartedUtc).TotalMinutes;
        Emit($"--- step {StepIndex}/{StepCount} ended after {mins:F0} min: {(ok ? "ok" : _stopping ? "stopped" : "problem (see above)")}",
             ok ? LineKind.Good : LineKind.Warn);
        try { s.After?.Invoke(s, ok); } catch (Exception e) { Emit("After-step error: " + e.Message, LineKind.Bad); }
        _proc?.Dispose();
        _proc = null;
        if (_stopping) _queue.Clear();
        Next();
    }

    public void Emit(string line, LineKind kind)
    {
        try { _log?.WriteLine($"[{DateTime.Now:HH:mm:ss}] {line}"); } catch { }
        Line?.Invoke(line, kind);
    }

    private static string StripAnsi(string s)
    {
        if (s.IndexOf('\u001b') < 0) return s.TrimEnd();
        var sb = new StringBuilder(s.Length);
        for (int i = 0; i < s.Length; i++)
        {
            if (s[i] == '\u001b' && i + 1 < s.Length && s[i + 1] == '[')
            {
                i += 2;
                while (i < s.Length && !char.IsLetter(s[i])) i++;
                continue;
            }
            sb.Append(s[i]);
        }
        return sb.ToString().TrimEnd();
    }

    private static LineKind Classify(string l)
    {
        if (l.Contains("FAIL") || l.Contains("error:") || l.Contains("Exception") || l.Contains("FAILED")) return LineKind.Bad;
        if (l.Contains("WARNING") || l.Contains("NOTE") || l.Contains("warning:")) return LineKind.Warn;
        if (l.Contains(": ok") || l.Contains("done") || l.Contains("Success") || l.Contains("installed")) return LineKind.Good;
        return LineKind.Normal;
    }
}

public enum LineKind { Normal, Info, Header, Good, Warn, Bad, Hint }
