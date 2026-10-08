using System.Runtime.InteropServices;

namespace PsxManager;

/// <summary>Dark mode everywhere (the only theme): colours for every control, a dark title bar, dark list
/// headers (owner-drawn) and dark scrollbars (Windows' own dark Explorer theme).</summary>
public static class Theme
{
    public static readonly Color Bg = Color.FromArgb(30, 30, 34);
    public static readonly Color Panel = Color.FromArgb(38, 38, 44);
    public static readonly Color Field = Color.FromArgb(46, 46, 53);
    public static readonly Color Border = Color.FromArgb(70, 70, 80);
    public static readonly Color Text = Color.FromArgb(228, 228, 232);
    public static readonly Color Dim = Color.FromArgb(150, 150, 160);
    public static readonly Color Good = Color.FromArgb(120, 210, 140);
    public static readonly Color Warn = Color.FromArgb(235, 200, 100);
    public static readonly Color Bad = Color.FromArgb(240, 120, 110);
    public static readonly Color Accent = Color.FromArgb(90, 150, 230);
    public static readonly Color RowBad = Color.FromArgb(80, 36, 36);
    public static readonly Color HintsBg = Color.FromArgb(40, 36, 28);

    [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] private static extern int SetWindowTheme(IntPtr hwnd, string? app, string? idList);

    /// <summary>Call from a form's constructor after building its controls.</summary>
    public static void Apply(Form form)
    {
        form.BackColor = Bg;
        form.ForeColor = Text;
        form.HandleCreated += (_, _) =>
        {
            int on = 1;
            if (DwmSetWindowAttribute(form.Handle, 20, ref on, sizeof(int)) != 0)       // dark title bar (Win 10 20H1+/11)
                DwmSetWindowAttribute(form.Handle, 19, ref on, sizeof(int));            // older Windows 10 builds
        };
        Walk(form);
    }

    private static void Walk(Control parent)
    {
        foreach (Control c in parent.Controls)
        {
            Style(c);
            if (c.HasChildren) Walk(c);
        }
    }

    private static void Style(Control c)
    {
        switch (c)
        {
            case Button b:
                b.FlatStyle = FlatStyle.Flat;
                b.FlatAppearance.BorderColor = Border;
                b.FlatAppearance.MouseOverBackColor = Color.FromArgb(60, 60, 70);
                b.FlatAppearance.MouseDownBackColor = Color.FromArgb(75, 75, 88);
                if (b.BackColor == SystemColors.Control || b.BackColor == Color.Empty || b.BackColor.ToArgb() == Control.DefaultBackColor.ToArgb())
                { b.BackColor = Field; b.ForeColor = Text; }
                b.UseVisualStyleBackColor = false;
                break;
            case ListView lv:
                lv.BackColor = Field; lv.ForeColor = Text; lv.BorderStyle = BorderStyle.None;
                DarkHeaders(lv);
                lv.HandleCreated += (_, _) => SetWindowTheme(lv.Handle, "DarkMode_Explorer", null);
                break;
            case RichTextBox rt:
                rt.BackColor = Color.FromArgb(22, 22, 26); rt.ForeColor = Text;
                rt.HandleCreated += (_, _) => SetWindowTheme(rt.Handle, "DarkMode_Explorer", null);
                break;
            case TextBox tb:
                if (tb.BackColor.ToArgb() != HintsBg.ToArgb()) tb.BackColor = Field;
                tb.ForeColor = tb.BackColor.ToArgb() == HintsBg.ToArgb() ? Warn : Text;
                tb.BorderStyle = BorderStyle.FixedSingle;
                tb.HandleCreated += (_, _) => SetWindowTheme(tb.Handle, "DarkMode_Explorer", null);
                break;
            case ListBox lb:
                lb.BackColor = Field; lb.ForeColor = Text; lb.BorderStyle = BorderStyle.FixedSingle;
                lb.HandleCreated += (_, _) => SetWindowTheme(lb.Handle, "DarkMode_Explorer", null);
                break;
            case NumericUpDown n:
                n.BackColor = Field; n.ForeColor = Text; n.BorderStyle = BorderStyle.FixedSingle;
                break;
            case GroupBox g:
                g.ForeColor = Dim; g.BackColor = Bg;
                break;
            case CheckBox cb:
                cb.ForeColor = Text; cb.BackColor = Color.Transparent;
                break;
            case SplitContainer sc:
                sc.BackColor = Border; sc.Panel1.BackColor = Bg; sc.Panel2.BackColor = Bg;
                break;
            case Label l:
                if (l.ForeColor.ToArgb() == SystemColors.ControlText.ToArgb() || l.ForeColor.ToArgb() == Control.DefaultForeColor.ToArgb()) l.ForeColor = Text;
                if (l.BackColor.ToArgb() == SystemColors.Control.ToArgb()) l.BackColor = Color.Transparent;
                break;
            case FlowLayoutPanel or TableLayoutPanel or System.Windows.Forms.Panel:
                if (c.BackColor.ToArgb() == SystemColors.Control.ToArgb() || c.BackColor == Color.Empty) c.BackColor = Bg;
                c.ForeColor = Text;
                break;
        }
    }

    /// <summary>ListView column headers ignore BackColor; draw them ourselves, rows stay default.</summary>
    private static void DarkHeaders(ListView lv)
    {
        if (lv.View != View.Details) return;
        lv.OwnerDraw = true;
        lv.DrawColumnHeader += (_, e) =>
        {
            using var bg = new SolidBrush(Panel);
            e.Graphics.FillRectangle(bg, e.Bounds);
            using var pen = new Pen(Border);
            e.Graphics.DrawLine(pen, e.Bounds.Right - 1, e.Bounds.Top + 4, e.Bounds.Right - 1, e.Bounds.Bottom - 4);
            e.Graphics.DrawLine(pen, e.Bounds.Left, e.Bounds.Bottom - 1, e.Bounds.Right, e.Bounds.Bottom - 1);
            TextRenderer.DrawText(e.Graphics, e.Header?.Text, lv.Font, Rectangle.Inflate(e.Bounds, -6, 0), Dim,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
        };
        lv.DrawItem += (_, e) => e.DrawDefault = true;
        lv.DrawSubItem += (_, e) => e.DrawDefault = true;
    }
}
