namespace PsxManager;

/// <summary>Add a new game: pick its .cue file(s) (disc order matters) and a short name.</summary>
public sealed class AddGameForm : Form
{
    private readonly ListBox _cues = new() { Dock = DockStyle.Fill, HorizontalScrollbar = true };
    private readonly TextBox _name = new() { Width = 220 };
    private readonly CheckBox _install = new() { Text = "Put it on the phone when built", AutoSize = true, Checked = true };
    public List<string> Cues => _cues.Items.Cast<string>().ToList();
    public string GameName => new string(_name.Text.ToLowerInvariant().Where(char.IsAsciiLetterOrDigit).ToArray());
    public bool InstallAfter => _install.Checked;

    public AddGameForm()
    {
        Text = "Add a new game";
        Width = 760; Height = 420; StartPosition = FormStartPosition.CenterParent;
        Font = new Font("Segoe UI", 9.5f);
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Padding = new Padding(8) };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.Controls.Add(new Label { Text = "1. Your disc's .cue file(s), Disc 1 first (several discs: add them all, in order):", AutoSize = true });
        layout.Controls.Add(_cues);
        var cueBar = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill };
        var add = new Button { Text = "Add .cue file(s)...", AutoSize = true };
        var up = new Button { Text = "Move up", AutoSize = true };
        var remove = new Button { Text = "Remove", AutoSize = true };
        add.Click += (_, _) =>
        {
            using var f = new OpenFileDialog { Filter = "Disc images (*.cue)|*.cue", Multiselect = true, Title = "Pick the .cue file(s)" };
            if (f.ShowDialog(this) != DialogResult.OK) return;
            foreach (var c in f.FileNames.OrderBy(x => x)) if (!_cues.Items.Contains(c)) _cues.Items.Add(c);
            if (_name.Text.Length == 0 && _cues.Items.Count > 0)
            {
                var n = Path.GetFileNameWithoutExtension((string)_cues.Items[0]!);
                var cut = n.IndexOf('(');
                if (cut > 0) n = n[..cut];
                _name.Text = new string(n.ToLowerInvariant().Where(char.IsAsciiLetterOrDigit).ToArray());
            }
        };
        up.Click += (_, _) =>
        {
            var i = _cues.SelectedIndex;
            if (i <= 0) return;
            var x = _cues.Items[i]; _cues.Items.RemoveAt(i); _cues.Items.Insert(i - 1, x!); _cues.SelectedIndex = i - 1;
        };
        remove.Click += (_, _) => { if (_cues.SelectedIndex >= 0) _cues.Items.RemoveAt(_cues.SelectedIndex); };
        cueBar.Controls.AddRange(new Control[] { add, up, remove });
        layout.Controls.Add(cueBar);
        var nameBar = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill };
        nameBar.Controls.Add(new Label { Text = "2. Short name (lowercase letters and numbers, e.g. spyro):", AutoSize = true, Padding = new Padding(0, 6, 0, 0) });
        nameBar.Controls.Add(_name);
        nameBar.Controls.Add(_install);
        layout.Controls.Add(nameBar);
        var okBar = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft };
        var ok = new Button { Text = "Set up and build", AutoSize = true };
        var cancel = new Button { Text = "Cancel", AutoSize = true, DialogResult = DialogResult.Cancel };
        ok.Click += (_, _) =>
        {
            if (_cues.Items.Count == 0) { MessageBox.Show(this, "Add the disc's .cue file first."); return; }
            if (GameName.Length == 0) { MessageBox.Show(this, "Type a short name."); return; }
            DialogResult = DialogResult.OK;
        };
        okBar.Controls.AddRange(new Control[] { ok, cancel });
        layout.Controls.Add(okBar);
        Controls.Add(layout);
        AcceptButton = ok; CancelButton = cancel;
        Theme.Apply(this);
    }
}

/// <summary>Phone storage: free space, and the disc copies in the phone's Download folder. A copy is "spare"
/// when the game's app already holds its own copy of the disc (files/gamedata). Only spare copies can be
/// ticked for removal, and only after the user confirms.</summary>
public sealed class StorageForm : Form
{
    private readonly Paths _p;
    private readonly List<string> _games;
    private readonly ListView _list = new() { View = View.Details, CheckBoxes = true, Dock = DockStyle.Fill, FullRowSelect = true };
    private readonly Label _free = new() { Dock = DockStyle.Top, Height = 30, Padding = new Padding(4, 8, 4, 0) };
    private readonly Button _remove = new() { Text = "Remove ticked spare copies", AutoSize = true, Enabled = false };

    public StorageForm(Paths p, List<string> games)
    {
        _p = p; _games = games;
        Text = "Phone storage"; Width = 760; Height = 520; StartPosition = FormStartPosition.CenterParent;
        Font = new Font("Segoe UI", 9.5f);
        _list.Columns.Add("Download folder", 220);
        _list.Columns.Add("Size", 80);
        _list.Columns.Add("App has its own copy?", 220);
        var info = new Label
        {
            Dock = DockStyle.Top, Height = 54, Padding = new Padding(4),
            Text = "Each game app copies its disc into its own storage when you pick the disc. After that, the copy in\n" +
                   "Download\\<game> is spare. Only spare copies can be removed; to reinstall a game later, 'Put on phone' copies the disc back.",
        };
        var bar = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, FlowDirection = FlowDirection.RightToLeft };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        bar.Controls.AddRange(new Control[] { close, _remove });
        _remove.Click += async (_, _) => await RemoveTicked();
        _list.ItemCheck += (_, e) => { if (_list.Items[e.Index].Tag is not true) e.NewValue = CheckState.Unchecked; };
        Controls.Add(_list); Controls.Add(info); Controls.Add(_free); Controls.Add(bar);
        CancelButton = close;
        Theme.Apply(this);
        Shown += async (_, _) => await LoadRows();
    }

    private async Task LoadRows()
    {
        _free.Text = "Reading the phone...";
        var rows = await Task.Run(() =>
        {
            var r = new List<(string game, string size, int discs)>();
            foreach (var g in _games)
            {
                var du = Shell.Run(_p.Adb, new[] { "shell", $"du -sh '/sdcard/Download/{g}' 2>/dev/null" }, 15000).Output.Trim();
                if (du.Length == 0) continue;
                var size = du.Split('\t', ' ')[0];
                var pkg = Paths.PackageOf(g);
                var ls = Shell.Run(_p.Adb, new[] { "shell", $"run-as {pkg} ls files/gamedata 2>/dev/null" }, 15000).Output;
                var discs = ls.Split('\n').Count(l => l.Trim().EndsWith(".cue", StringComparison.OrdinalIgnoreCase));
                r.Add((g, size, discs));
            }
            return r;
        });
        var (conn, _, free) = await Task.Run(() => Games.Phone(_p));
        _free.Text = conn ? $"Phone: {free}" : "Phone not connected.";
        _list.Items.Clear();
        foreach (var (game, size, discs) in rows)
        {
            var spare = discs > 0;
            var it = new ListViewItem($"Download\\{game}") { Tag = spare, Checked = spare };
            it.SubItems.Add(size);
            it.SubItems.Add(spare ? $"yes ({discs} disc{(discs > 1 ? "s" : "")}): spare copy" : "NO: keep (pick the disc in the app first)");
            if (!spare) it.ForeColor = Theme.Dim;
            _list.Items.Add(it);
        }
        if (rows.Count == 0) _list.Items.Add(new ListViewItem("(no game disc copies in Download)"));
        _remove.Enabled = rows.Any(r => r.discs > 0);
    }

    private async Task RemoveTicked()
    {
        var pick = _list.Items.Cast<ListViewItem>().Where(i => i.Checked && i.Tag is true).Select(i => i.Text["Download\\".Length..]).ToList();
        if (pick.Count == 0) return;
        if (MessageBox.Show(this, $"Permanently delete these {pick.Count} spare disc copies from the phone?\n\n" + string.Join("\n", pick.Select(x => "Download\\" + x)),
                "Phone storage", MessageBoxButtons.YesNo, MessageBoxIcon.Warning) != DialogResult.Yes) return;
        _remove.Enabled = false;
        foreach (var g in pick)
            await Task.Run(() => Shell.Run(_p.Adb, new[] { "shell", $"rm -r '/sdcard/Download/{g}'" }, 60000));
        await LoadRows();
    }
}
