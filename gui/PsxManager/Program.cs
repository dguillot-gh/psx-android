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
        Application.Run(new MainForm(paths));
    }
}
