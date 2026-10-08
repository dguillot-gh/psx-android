using System.Diagnostics;
using System.Text;

namespace PsxManager;

/// <summary>Short helper commands (adb, gh) that finish quickly; run on a background thread.</summary>
public static class Shell
{
    public sealed record Result(int Code, string Output, bool TimedOut);

    public static Result Run(string exe, IEnumerable<string> args, int timeoutMs = 20000, string? workDir = null)
    {
        var psi = new ProcessStartInfo(exe)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        if (workDir != null) psi.WorkingDirectory = workDir;
        foreach (var a in args) psi.ArgumentList.Add(a);
        try
        {
            using var p = Process.Start(psi)!;
            var outTask = p.StandardOutput.ReadToEndAsync();
            var errTask = p.StandardError.ReadToEndAsync();
            if (!p.WaitForExit(timeoutMs))
            {
                try { p.Kill(true); } catch { }
                return new Result(-1, "", true);
            }
            p.WaitForExit();
            return new Result(p.ExitCode, outTask.Result + errTask.Result, false);
        }
        catch (Exception e)
        {
            return new Result(-1, e.Message, false);
        }
    }

    /// <summary>Opens a visible PowerShell window (for the guided, question-asking jobs).</summary>
    public static void OpenConsole(Paths paths, string scriptOrCommand, bool isCommand = false)
    {
        var psi = new ProcessStartInfo(paths.Pwsh) { UseShellExecute = true, WorkingDirectory = paths.Tools };
        psi.ArgumentList.Add("-NoProfile");
        if (isCommand) { psi.ArgumentList.Add("-NoExit"); psi.ArgumentList.Add("-Command"); }
        else psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(scriptOrCommand);
        Process.Start(psi);
    }

    public static string Quote(string s) => "'" + s.Replace("'", "''") + "'";   // PowerShell single-quoted string
}
