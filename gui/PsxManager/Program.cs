namespace PsxManager;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        var paths = Paths.Find(AppContext.BaseDirectory) ?? Paths.Find(Environment.CurrentDirectory);
        if (paths == null)
        {
            MessageBox.Show("PSX Manager could not find the project (psx-android-tools\\go.ps1).\n\n" +
                            "Keep PSX-Manager.exe in its folder next to psx-android-tools (for example D:\\recomp-backups\\PSX-Manager).",
                            "PSX Manager", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        AppLog.Init(paths);
        AppLog.Write("===== PSX Manager opened =====");
        foreach (var c in AppLog.Context(paths)) AppLog.Write("context: " + c);
        // PSX Manager's own errors go to the log too (and a message instead of a silent close).
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, e) =>
        {
            AppLog.Write("PSX Manager error: " + e.Exception);
            MessageBox.Show("PSX Manager hit an error (details saved in the log):\n\n" + e.Exception.Message, "PSX Manager",
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
        };
        AppDomain.CurrentDomain.UnhandledException += (_, e) => AppLog.Write("PSX Manager crashed: " + e.ExceptionObject);
        Application.Run(new MainForm(paths));
        AppLog.Write("===== PSX Manager closed =====");
    }
}
