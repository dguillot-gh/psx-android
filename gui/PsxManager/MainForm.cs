using System.Diagnostics;

namespace PsxManager;

public sealed class MainForm : Form
{
    private readonly Paths _p;
    private readonly JobRunner _runner;
    private readonly Health _health;
    private List<GameInfo> _games = new();
    private HashSet<string>? _installed;
    private bool _phoneConnected;

    // UI
    private readonly ListView _gameList = new() { View = View.Details, CheckBoxes = true, FullRowSelect = true, Dock = DockStyle.Fill, HideSelection = false };
    private readonly Label _phoneLabel = new() { AutoSize = true, Padding = new Padding(6, 6, 18, 6) };
    private readonly Label _driveLabel = new() { AutoSize = true, Padding = new Padding(6, 6, 18, 6) };
    private readonly Label _memLabel = new() { AutoSize = true, Padding = new Padding(6, 6, 6, 6) };
    private readonly CheckBox _showLater = new() { Text = "Show set-aside games", AutoSize = true };
    private readonly NumericUpDown _speedMin = new() { Minimum = 0, Maximum = 600, Value = 45, Width = 60 };
    private readonly CheckBox _readPhone = new() { Text = "Read play recordings from the phone", AutoSize = true };
    private readonly CheckBox _installAfter = new() { Text = "Put on the phone when built", AutoSize = true };
    private readonly NumericUpDown _testSec = new() { Minimum = 10, Maximum = 600, Value = 30, Width = 60 };
    private readonly RichTextBox _log = new() { Dock = DockStyle.Fill, ReadOnly = true, Font = new Font("Consolas", 9f), BackColor = Color.FromArgb(24, 24, 28), ForeColor = Color.Gainsboro, WordWrap = false, BorderStyle = BorderStyle.None };
    private readonly Panel _verdictBar = new() { Dock = DockStyle.Top, Height = 6 };
    private readonly Label _headline = new() { Dock = DockStyle.Top, AutoSize = false, Height = 44, Font = new Font("Segoe UI", 11f, FontStyle.Bold), Padding = new Padding(6, 4, 6, 0) };
    private readonly Label _detail = new() { Dock = DockStyle.Top, AutoSize = false, Height = 40, Padding = new Padding(6, 0, 6, 0) };
    private readonly ListView _workers = new() { View = View.Details, Dock = DockStyle.Top, Height = 110, FullRowSelect = true, HeaderStyle = ColumnHeaderStyle.Nonclickable };
    private readonly TextBox _hints = new() { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, BackColor = Theme.HintsBg, Font = new Font("Segoe UI", 10f) };
    private SplitContainer? _split;
    private readonly Button _stop = new() { Text = "Stop", AutoSize = true, MinimumSize = new Size(150, 36), Enabled = false, BackColor = Color.FromArgb(200, 70, 60), ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
    private readonly List<Button> _jobButtons = new();
    private readonly System.Windows.Forms.Timer _healthTimer = new() { Interval = 5000 };
    private readonly System.Windows.Forms.Timer _phoneTimer = new() { Interval = 20000 };
    private readonly ToolTip _tips = new() { AutoPopDelay = 15000 };

    public MainForm(Paths paths)
    {
        _p = paths;
        _runner = new JobRunner(paths);
        _health = new Health(paths);
        Text = "PSX Manager: PS1 games on Android";
        // Fit smaller laptop screens too: 90% of the screen, at most 1500 x 950.
        var wa = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1400, 900);
        Width = Math.Min(1500, (int)(wa.Width * 0.9)); Height = Math.Min(950, (int)(wa.Height * 0.9));
        MinimumSize = new Size(1000, 640);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9.5f);
        BuildUi();
        Theme.Apply(this);

        _runner.Line += (l, k) => { _health.Observe(l); if (!IsDisposed) BeginInvoke(() => AppendLog(l, k)); };
        _runner.StateChanged += () => { if (!IsDisposed) BeginInvoke(UpdateButtons); };
        _runner.JobFinished += name => { if (!IsDisposed) BeginInvoke(() => { UpdateHealth(); _ = RefreshAll(); }); };
        _healthTimer.Tick += (_, _) => UpdateHealth();
        _phoneTimer.Tick += async (_, _) => { if (!_runner.Busy) await RefreshPhone(); };
        Shown += async (_, _) =>
        {
            AppendLog($"PSX Manager. Project folder: {_p.DriveRoot}", LineKind.Info);
            AppendLog("Tick the games on the left, then press a job button. One job runs at a time; Stop is always safe.", LineKind.Info);
            if (_split != null) _split.SplitterDistance = Math.Max(600, (int)(ClientSize.Width * 0.5));
            _healthTimer.Start(); _phoneTimer.Start();
            await RefreshAll();
            UpdateHealth();
        };
        FormClosing += (s, e) =>
        {
            if (_runner.Busy && MessageBox.Show(this, "A job is still running. Stop it and close? (Safe: it continues next time.)",
                    "PSX Manager", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) { e.Cancel = true; return; }
            _runner.Stop();
        };
    }

    // ------------------------------------------------------------------ layout
    private void BuildUi()
    {
        var top = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 34, BackColor = Theme.Panel };
        top.Controls.AddRange(new Control[] { _phoneLabel, _driveLabel, _memLabel });

        var split = new SplitContainer { Dock = DockStyle.Fill, FixedPanel = FixedPanel.Panel1, SplitterWidth = 6 };
        _split = split;

        // Left: games + options + job buttons
        var left = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4 };
        left.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        left.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        left.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        left.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var listBar = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false, AutoSize = true };
        var all = new Button { Text = "Tick all", AutoSize = true };
        var none = new Button { Text = "Untick all", AutoSize = true };
        var refresh = new Button { Text = "Refresh", AutoSize = true };
        all.Click += (_, _) => { foreach (ListViewItem i in _gameList.Items) i.Checked = true; };
        none.Click += (_, _) => { foreach (ListViewItem i in _gameList.Items) i.Checked = false; };
        refresh.Click += async (_, _) => await RefreshAll();
        _showLater.CheckedChanged += async (_, _) => await RefreshAll();
        listBar.Controls.AddRange(new Control[] { all, none, refresh, _showLater });

        _gameList.Columns.Add("Game", 160);
        _gameList.Columns.Add("Built", 110);
        _gameList.Columns.Add("On phone", 70);
        _gameList.Columns.Add("Last test", 90);
        _gameList.Columns.Add("Code size", 80);

        var opts = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, AutoSize = true, Padding = new Padding(4) };
        opts.Controls.Add(new Label { Text = "Speed pre-compile limit (minutes, 0 = default 45):", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 0);
        opts.Controls.Add(_speedMin, 1, 0);
        opts.Controls.Add(_readPhone, 0, 1);
        opts.Controls.Add(_installAfter, 0, 2);
        opts.Controls.Add(new Label { Text = "Test run length (seconds):", AutoSize = true, Anchor = AnchorStyles.Left }, 0, 3);
        opts.Controls.Add(_testSec, 1, 3);
        _tips.SetToolTip(_speedMin, "Longer = smoother games, longer builds. It always continues where it stopped.");
        _tips.SetToolTip(_readPhone, "Plug in the phone first: the build reads which code you ran while playing, so it gets pre-compiled.");
        var optBox = new GroupBox { Text = "Options", Dock = DockStyle.Fill, AutoSize = true };
        optBox.Controls.Add(opts);

        var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, Padding = new Padding(2) };
        AddJob(buttons, "Build / update", "Build the ticked games one at a time (with the speed pre-compile).", BuildJob);
        AddJob(buttons, "Overnight speed", "Let the ticked games' speed pre-compile finish (up to 4 h each). No phone needed.", OvernightJob);
        AddJob(buttons, "Put on phone", "Back up saves, install the newest build, copy the disc if the app needs it, quick test.", PhoneJob);
        AddJob(buttons, "Test on phone", "Open each ticked game, press Play, record fps, screenshots and log.", TestJob);
        AddJob(buttons, "Add new game...", "Pick a disc's .cue file(s) and a short name; it sets up and builds the game.", AddGameJob);
        AddJob(buttons, "Back up saves", "Copy every game's memory cards from the phone to the drive.", BackupJob);
        AddJob(buttons, "Phone storage...", "See the phone's free space and remove spare disc copies.", StorageJob);
        AddJob(buttons, "Save to GitHub", "Upload the games' setups, scripts and engine to your repositories.", GithubJob);
        AddJob(buttons, "Update engine...", "Get the newest psxrecomp, test it, switch only if you say yes (opens its own window).", UpdateEngineJob);
        AddJob(buttons, "Report a problem", "Tick ONE game: it opens on the phone and everything it logs is recorded while you play. " +
            "Close the game (or let it crash) to finish; you get a report with a plain-English verdict.", ReportJob);
        var logsBtn = new Button { Text = "Open logs folder", AutoSize = true, MinimumSize = new Size(150, 36), Padding = new Padding(6, 0, 6, 0) };
        logsBtn.Click += (_, _) => { Directory.CreateDirectory(_p.Logs); Process.Start(new ProcessStartInfo("explorer.exe", _p.Logs) { UseShellExecute = true }); };
        buttons.Controls.Add(logsBtn);
        var reportsBtn = new Button { Text = "Open reports", AutoSize = true, MinimumSize = new Size(150, 36), Padding = new Padding(6, 0, 6, 0) };
        reportsBtn.Click += (_, _) => { Directory.CreateDirectory(_p.Reports); Process.Start(new ProcessStartInfo("explorer.exe", _p.Reports) { UseShellExecute = true }); };
        buttons.Controls.Add(reportsBtn);
        _stop.Click += (_, _) => _runner.Stop();
        _tips.SetToolTip(_stop, "Always safe: finished work is kept; press the same job again later to continue.");
        buttons.Controls.Add(_stop);

        left.Controls.Add(listBar, 0, 0);
        left.Controls.Add(_gameList, 0, 1);
        left.Controls.Add(optBox, 0, 2);
        left.Controls.Add(buttons, 0, 3);
        split.Panel1.Controls.Add(left);

        // Right: what's happening + log
        var right = new SplitContainer { Dock = DockStyle.Fill, Orientation = Orientation.Horizontal, SplitterDistance = 330 };
        var healthPanel = new Panel { Dock = DockStyle.Fill };
        _workers.Columns.Add("Program", 330);
        _workers.Columns.Add("CPU", 70);
        _workers.Columns.Add("Memory", 90);
        _workers.Columns.Add("Running for", -2);
        var hintsBox = new GroupBox { Text = "What to do / hints", Dock = DockStyle.Fill };
        hintsBox.Controls.Add(_hints);
        healthPanel.Controls.Add(hintsBox);
        healthPanel.Controls.Add(_workers);
        healthPanel.Controls.Add(_detail);
        healthPanel.Controls.Add(_headline);
        healthPanel.Controls.Add(_verdictBar);
        var healthBox = new GroupBox { Text = "What's happening", Dock = DockStyle.Fill };
        healthBox.Controls.Add(healthPanel);
        right.Panel1.Controls.Add(healthBox);
        var logBox = new GroupBox { Text = "Live log (also saved in psx-android-tools\\logs\\manager-<date>.log)", Dock = DockStyle.Fill };
        logBox.Controls.Add(_log);
        right.Panel2.Controls.Add(logBox);
        split.Panel2.Controls.Add(right);

        Controls.Add(split);
        Controls.Add(top);
    }

    private void AddJob(FlowLayoutPanel panel, string text, string tip, Action action)
    {
        var b = new Button { Text = text, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowOnly, MinimumSize = new Size(150, 36), Padding = new Padding(6, 0, 6, 0) };
        b.Click += (_, _) =>
        {
            if (_runner.Busy) { MessageBox.Show(this, "A job is already running. Wait for it, or press Stop.", "PSX Manager"); return; }
            try { action(); } catch (Exception e) { AppendLog("Error: " + e.Message, LineKind.Bad); }
        };
        _tips.SetToolTip(b, tip);
        _jobButtons.Add(b);
        panel.Controls.Add(b);
    }

    private void UpdateButtons()
    {
        foreach (var b in _jobButtons) b.Enabled = !_runner.Busy;
        _stop.Enabled = _runner.Busy;
        Text = _runner.Busy ? $"PSX Manager: {_runner.JobName} (step {_runner.StepIndex}/{_runner.StepCount})" : "PSX Manager: PS1 games on Android";
        UpdateHealth();
    }

    // ------------------------------------------------------------------ refresh
    private async Task RefreshPhone()
    {
        var (conn, inst, free) = await Task.Run(() => Games.Phone(_p));
        _phoneConnected = conn;
        _installed = inst;
        _phoneLabel.Text = conn ? $"Phone: connected ({free})" : "Phone: not connected (plug in USB, unlock, Allow)";
        _phoneLabel.ForeColor = conn ? Theme.Good : Theme.Warn;
    }

    private async Task RefreshAll()
    {
        var ticked = Ticked().ToHashSet(StringComparer.OrdinalIgnoreCase);
        await RefreshPhone();
        var later = _showLater.Checked;
        var inst = _installed;
        _games = await Task.Run(() => Games.Scan(_p, later, inst));
        _gameList.BeginUpdate();
        _gameList.Items.Clear();
        foreach (var g in _games)
        {
            var label = g.Name.EndsWith("_recomp") ? g.Name[..^7] : g.Name;
            if (!g.InPipeline) label += " (set aside)";
            var item = new ListViewItem(label) { Checked = ticked.Contains(g.Name), Tag = g };
            item.SubItems.Add(g.LastApk != null ? g.LastApk.LastWriteTime.ToString("MMM d HH:mm") : "not yet");
            item.SubItems.Add(g.OnPhone == null ? "?" : g.OnPhone.Value ? "yes" : "no");
            item.SubItems.Add(g.LastTest);
            item.SubItems.Add(g.GeneratedMb > 0 ? $"{g.GeneratedMb:N0} MB" : "");
            if (g.GeneratedMb > 300) { item.BackColor = Theme.RowBad; item.ForeColor = Theme.Text; item.ToolTipText = "Abnormally large code (data-as-code problem): may never finish linking."; }
            else if (!g.InPipeline) item.ForeColor = Theme.Dim;
            _gameList.Items.Add(item);
        }
        FitColumns(_gameList);
        _gameList.EndUpdate();
        _gameList.ShowItemToolTips = true;
        try
        {
            var drive = new DriveInfo(Path.GetPathRoot(_p.DriveRoot)!);
            _driveLabel.Text = $"Drive {drive.Name.TrimEnd('\\')} {drive.AvailableFreeSpace / 1073741824.0:N0} GB free";
        }
        catch { _driveLabel.Text = ""; }
    }

    private IEnumerable<string> Ticked() =>
        _gameList.Items.Cast<ListViewItem>().Where(i => i.Checked).Select(i => ((GameInfo)i.Tag!).Name);

    /// <summary>Each column as wide as its widest cell or its header, whichever is wider.</summary>
    private static void FitColumns(ListView lv)
    {
        for (int i = 0; i < lv.Columns.Count; i++)
        {
            lv.AutoResizeColumn(i, ColumnHeaderAutoResizeStyle.HeaderSize);
            var header = lv.Columns[i].Width;
            lv.AutoResizeColumn(i, ColumnHeaderAutoResizeStyle.ColumnContent);
            lv.Columns[i].Width = Math.Max(header, lv.Columns[i].Width) + 12;
        }
    }

    private List<GameInfo> TickedGames(bool needSome = true)
    {
        var t = _gameList.Items.Cast<ListViewItem>().Where(i => i.Checked).Select(i => (GameInfo)i.Tag!).ToList();
        if (needSome && t.Count == 0) MessageBox.Show(this, "Tick at least one game in the list first.", "PSX Manager");
        return t;
    }

    private bool NeedPhone()
    {
        if (_phoneConnected) return true;
        var (conn, inst, _) = Games.Phone(_p);
        _phoneConnected = conn; _installed = inst;
        if (conn) return true;
        MessageBox.Show(this, "No phone found.\n\nPlug it in with USB, unlock it, and tap Allow on the 'USB debugging' prompt.\n(Settings > System > Developer options > USB debugging must be on.)",
            "PSX Manager", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        return false;
    }

    // ------------------------------------------------------------------ jobs
    private List<string> Pwsh(params string[] fileAndArgs)
    {
        var l = new List<string> { "-NoProfile", "-File" };
        l.AddRange(fileAndArgs);
        return l;
    }

    private Step BuildStep(GameInfo g, int speedMinutes, bool readPhone) => new()
    {
        Title = $"Build {g.Name}",
        Game = g.Name,
        Args = () =>
        {
            var a = Pwsh("go.ps1", "-Game", g.Name, "-Speed", "-NoInstall");
            if (speedMinutes > 0) { a.Add("-SpeedMinutes"); a.Add(speedMinutes.ToString()); }
            if (!readPhone) a.Add("-NoPhone");
            return a;
        },
    };

    private Step PhoneStep(string game, int testSec, Func<bool>? skipIf = null) => new()
    {
        Title = $"Put {game} on the phone",
        SkipIf = skipIf,
        Args = () =>
        {
            // phone-pass takes the newest APK of one date folder: the folder of this game's newest APK.
            var apk = new DirectoryInfo(_p.Apks).EnumerateFiles($"{game}-play-*.apk", SearchOption.AllDirectories)
                        .OrderBy(f => f.LastWriteTimeUtc).LastOrDefault();
            var date = apk?.Directory?.Name ?? DateTime.Now.ToString("yyyy-MM-dd");
            return Pwsh(Path.Combine("tools", "phone-pass.ps1"), "-TestSeconds", testSec.ToString(), "-Game", game, "-Date", date);
        },
    };

    private bool ConfirmBigCode(List<GameInfo> games)
    {
        var big = games.Where(g => g.GeneratedMb > 300).ToList();
        if (big.Count == 0) return true;
        return MessageBox.Show(this,
            $"{string.Join(", ", big.Select(b => b.Name))}: abnormally large generated code ({string.Join(", ", big.Select(b => $"{b.GeneratedMb:N0} MB"))}).\n\n" +
            "This is the 'data-as-code' problem (GT2, Legend of Dragoon). Building it can take many hours and may never finish linking.\n\nBuild anyway?",
            "PSX Manager", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) == DialogResult.Yes;
    }

    private void BuildJob()
    {
        var games = TickedGames(); if (games.Count == 0 || !ConfirmBigCode(games)) return;
        var readPhone = _readPhone.Checked;
        if (readPhone && !NeedPhone()) return;
        var steps = games.Select(g => BuildStep(g, (int)_speedMin.Value, readPhone)).ToList();
        if (_installAfter.Checked)
            steps.AddRange(games.Select(g => PhoneStep(g.Name, (int)_testSec.Value,
                () => !_runner.GameOk.GetValueOrDefault(g.Name) || !_phoneConnected)));
        Begin($"Build {games.Count} game(s)", steps);
    }

    private void OvernightJob()
    {
        var games = TickedGames(); if (games.Count == 0 || !ConfirmBigCode(games)) return;
        Begin($"Overnight speed for {games.Count} game(s)", games.Select(g => BuildStep(g, 240, false)));
    }

    private void PhoneJob()
    {
        var games = TickedGames(); if (games.Count == 0 || !NeedPhone()) return;
        var missing = games.Where(g => g.LastApk == null).Select(g => g.Name).ToList();
        if (missing.Count > 0) AppendLog($"Not built yet (skipped): {string.Join(", ", missing)}", LineKind.Warn);
        var ok = games.Where(g => g.LastApk != null).ToList();
        if (ok.Count == 0) return;
        Begin($"Put {ok.Count} game(s) on the phone", ok.Select(g => PhoneStep(g.Name, (int)_testSec.Value)));
    }

    private void TestJob()
    {
        var games = TickedGames(); if (games.Count == 0 || !NeedPhone()) return;
        var sec = (int)_testSec.Value;
        var steps = new List<Step>();
        foreach (var g in games.Where(g => _installed == null || _installed.Contains(g.Package)))
        {
            var outDir = Path.Combine(_p.WorkDir, g.Name, "phone-test", DateTime.Now.ToString("yyyyMMdd-HHmm"));
            steps.Add(new Step
            {
                Title = $"Test {g.Name} for {sec} s (hands off the phone)",
                Args = () => Pwsh(Path.Combine("tools", "phone.ps1"), "-Action", "play-test", "-Package", g.Package, "-OutDir", outDir, "-Seconds", sec.ToString()),
                After = (s, ok) =>
                {
                    var sum = Path.Combine(outDir, "summary.txt");
                    if (File.Exists(sum)) { var t = File.ReadAllText(sum).Trim(); _runner.Results.Add($"{g.Name}: {t}"); }
                    else _runner.Results.Add($"{g.Name}: not tested (pick the disc once in the app: Select game file)");
                },
            });
            steps.Add(new Step { Title = "Back to the home screen", Args = () => Pwsh(Path.Combine("tools", "phone.ps1"), "-Action", "home") });
        }
        if (steps.Count == 0) { MessageBox.Show(this, "None of the ticked games is installed on the phone.", "PSX Manager"); return; }
        Begin($"Test {games.Count} game(s)", steps);
    }

    private void AddGameJob()
    {
        using var dlg = new AddGameForm();
        if (dlg.ShowDialog(this) != DialogResult.OK) return;
        var game = dlg.GameName + "_recomp";
        var cues = dlg.Cues;
        // -Disc takes a list: it only binds through -Command (not -File), so build that command line.
        var cmd = $"& .\\go.ps1 -Game {Shell.Quote(game)} -Disc {string.Join(",", cues.Select(Shell.Quote))} -Speed -NoInstall -NoPhone";
        var steps = new List<Step>
        {
            new() { Title = $"Set up and build {game}", Game = game, Args = () => new List<string> { "-NoProfile", "-Command", cmd } },
        };
        if (dlg.InstallAfter) steps.Add(PhoneStep(game, (int)_testSec.Value, () => !_runner.GameOk.GetValueOrDefault(game)));
        Begin($"Add new game {game}", steps);
        AppendLog("A brand-new game may still need a programmer before it plays right (see easy\\README.md).", LineKind.Info);
    }

    private void ReportJob()
    {
        var games = TickedGames(); if (games.Count == 0) return;
        if (games.Count > 1) { MessageBox.Show(this, "Tick just ONE game to report on.", "PSX Manager"); return; }
        if (!NeedPhone()) return;
        var g = games[0];
        if (_installed != null && !_installed.Contains(g.Package)) { MessageBox.Show(this, $"{g.Name} isn't on the phone. Put it on the phone first.", "PSX Manager"); return; }
        MessageBox.Show(this, $"{g.Name} will open on the phone and everything it logs is recorded.\n\n" +
            "Press Play and play until the problem happens.\nThen close the game (swipe it away), or let it crash: the report finishes by itself.",
            "Report a problem", MessageBoxButtons.OK, MessageBoxIcon.Information);
        var started = DateTime.Now;
        Begin($"Report on {g.Name}", new[] { new Step
        {
            Title = $"Recording {g.Name} (close the game to finish)",
            Args = () => Pwsh(Path.Combine("tools", "report.ps1"), "-Package", g.Package, "-Game", g.Name),
            After = (s, ok) =>
            {
                // Newest report folder for this game, made by this run.
                var stem = g.Name.EndsWith("_recomp") ? g.Name[..^7] : g.Name;
                var dir = new DirectoryInfo(_p.Reports).Exists
                    ? new DirectoryInfo(_p.Reports).EnumerateDirectories(stem + "-*")
                        .Where(d => d.CreationTime >= started.AddMinutes(-1)).OrderBy(d => d.CreationTime).LastOrDefault()
                    : null;
                if (dir == null) { _runner.Results.Add($"{g.Name}: no report (recording never started)"); return; }
                var report = Path.Combine(dir.FullName, "REPORT.txt");
                if (!File.Exists(report))   // stopped with Stop: write the verdict from what was recorded
                    Shell.Run(_p.Pwsh, new[] { "-NoProfile", "-File", Path.Combine(_p.Tools, "tools", "report.ps1"), "-Analyze", dir.FullName }, 120000);
                if (!File.Exists(report)) { _runner.Results.Add($"{g.Name}: report folder {dir.FullName} (no verdict)"); return; }
                foreach (var l in File.ReadLines(report).SkipWhile(l => l != "VERDICT").Skip(1).TakeWhile(l => l.Length > 0))
                    _runner.Results.Add($"{g.Name}: {l.Trim()}");
                _runner.Results.Add($"{g.Name}: report in {dir.FullName}");
                try { Process.Start(new ProcessStartInfo("notepad.exe", report) { UseShellExecute = true }); } catch { }
            },
        } });
    }

    private void BackupJob()
    {
        if (!NeedPhone()) return;
        Begin("Back up all saves", new[] { new Step { Title = "Back up every game's memory cards", Args = () => Pwsh(Path.Combine("easy", "06-backup-saves.ps1")) } });
    }

    private void StorageJob()
    {
        if (!NeedPhone()) return;
        using var dlg = new StorageForm(_p, _games.Select(g => g.Name).ToList());
        dlg.ShowDialog(this);
        _ = RefreshPhone();
    }

    private void GithubJob()
    {
        if (!File.Exists(_p.Gh)) { MessageBox.Show(this, $"GitHub tool missing: {_p.Gh}", "PSX Manager"); return; }
        var st = Shell.Run(_p.Gh, new[] { "auth", "status" }, 15000);
        if (st.Code != 0)
        {
            MessageBox.Show(this, "This PC isn't signed in to GitHub yet. A window opens with a code: enter it at github.com/login/device, then press Save to GitHub again.",
                "PSX Manager", MessageBoxButtons.OK, MessageBoxIcon.Information);
            Shell.OpenConsole(_p, $"& {Shell.Quote(_p.Gh)} auth login --hostname github.com --git-protocol https --web", isCommand: true);
            return;
        }
        Begin("Save to GitHub", new[] { new Step { Title = "Upload games, scripts and engine", Args = () => Pwsh(Path.Combine("easy", "09-save-to-github.ps1")) } });
    }

    private void UpdateEngineJob()
    {
        if (MessageBox.Show(this, "The engine update is guided: it opens in its own window and asks before each big step.\n" +
                "It tests the new engine on Einhander first and changes nothing unless you say yes at the end.\n\nOpen it now?",
                "PSX Manager", MessageBoxButtons.YesNo, MessageBoxIcon.Information) != DialogResult.Yes) return;
        Shell.OpenConsole(_p, Path.Combine(_p.Tools, "easy", "10-update-psxrecomp.ps1"));
    }

    private void Begin(string name, IEnumerable<Step> steps)
    {
        _health.ResetPhase();
        _runner.Start(name, steps);
        UpdateButtons();
    }

    // ------------------------------------------------------------------ health + log
    private void UpdateHealth()
    {
        HealthReport r;
        try { r = _health.Check(_runner); } catch (Exception e) { _headline.Text = "Health check error: " + e.Message; return; }
        _memLabel.Text = $"PC memory: {r.FreeRamGb:F1} of {r.TotalRamGb:F0} GB free";
        _memLabel.ForeColor = r.FreeRamGb < 0.8 ? Theme.Bad : Theme.Text;
        (_verdictBar.BackColor, _headline.ForeColor) = r.Verdict switch
        {
            Verdict.Working => (Theme.Good, Theme.Good),
            Verdict.QuietBusy => (Theme.Warn, Theme.Warn),
            Verdict.Stuck => (Theme.Bad, Theme.Bad),
            Verdict.Problem => (Theme.Bad, Theme.Bad),
            _ => (Theme.Border, Theme.Dim),
        };
        _headline.Text = r.Headline;
        if (_runner.Busy)
        {
            var step = _runner.Current;
            _detail.Text = $"{_runner.JobName}: step {_runner.StepIndex} of {_runner.StepCount}: {step?.Title}  (this step: {Health.Fmt(DateTime.UtcNow - _runner.StepStartedUtc)})" +
                (r.Phase != "" ? $"\nPhase: {r.Phase} for {Health.Fmt(r.PhaseAge)}   |   last output {Health.Fmt(r.QuietFor)} ago" : $"\nLast output {Health.Fmt(r.QuietFor)} ago");
        }
        else _detail.Text = "Tick games on the left and press a job button.";
        _workers.BeginUpdate();
        _workers.Items.Clear();
        foreach (var w in r.Workers.Take(8))
        {
            var it = new ListViewItem(Health.FriendlyName(w.Name) + (w.Name == Health.FriendlyName(w.Name) ? "" : $"  [{w.Name}]"));
            it.SubItems.Add($"{w.CpuPercent:F0}%");
            it.SubItems.Add($"{w.MemGb:F1} GB");
            it.SubItems.Add(Health.Fmt(w.Age));
            _workers.Items.Add(it);
        }
        if (r.Workers.Count == 0) _workers.Items.Add(new ListViewItem("(no build tools running)"));
        _workers.Columns[^1].Width = -2;
        _workers.EndUpdate();
        var hints = string.Join(Environment.NewLine + Environment.NewLine, r.Hints.Distinct());
        if (_hints.Text != hints) _hints.Text = hints.Length > 0 ? hints : (_runner.Busy ? "No problems spotted." : "");
    }

    private void AppendLog(string line, LineKind kind)
    {
        var color = kind switch
        {
            LineKind.Header => Color.SkyBlue,
            LineKind.Good => Color.LightGreen,
            LineKind.Warn => Color.Khaki,
            LineKind.Bad => Color.Salmon,
            LineKind.Info => Color.Silver,
            LineKind.Hint => Color.Orange,
            _ => Color.Gainsboro,
        };
        if (_log.TextLength > 2_000_000) { _log.Select(0, 500_000); _log.SelectedText = ""; }
        _log.SelectionStart = _log.TextLength;
        _log.SelectionLength = 0;
        _log.SelectionColor = color;
        _log.AppendText(line + Environment.NewLine);
        _log.ScrollToCaret();
    }
}
