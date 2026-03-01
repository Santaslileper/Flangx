using System;
using System.Drawing;
using System.Windows.Forms;
using System.IO;
using System.Diagnostics;
using System.Net;

namespace DesktopWidgets {
    public class StandardWidget : WidgetHost {
        private RichTextBox _editor;
        public StandardWidget(string type = "Note", string id = null) : base(type, 189, 139, id) {
            _editor = new RichTextBox { Dock = DockStyle.Fill, BackColor = Color.FromArgb(15, 15, 20), ForeColor = Color.FromArgb(150, 160, 170), BorderStyle = BorderStyle.None, Font = new Font("Consolas", 10), AcceptsTab = true };
            _editor.Text = type + " Widget\r\nStorage: data/" + WidgetType + "_" + WidgetId + "_content.txt";
            ContentPanel.Controls.Add(_editor);
            _editor.TextChanged += delegate { Save(); };
            Load();
        }
        public override void Save() { base.Save(); string p = Path.Combine(DataDir, WidgetType + "_" + WidgetId + "_content.txt"); File.WriteAllText(p, _editor.Text); }
        public override void Load() { base.Load(); string p = Path.Combine(DataDir, WidgetType + "_" + WidgetId + "_content.txt"); if(File.Exists(p)) _editor.Text = File.ReadAllText(p); }
    }

    public class ClockWidget : WidgetHost {
        private Label _timeLabel;
        private Timer _timer;
        public ClockWidget(string id = null) : base("Clock", 189, 80, id) {
            _timeLabel = new Label { Dock = DockStyle.Fill, ForeColor = Color.White, Font = new Font("Segoe UI", 32, FontStyle.Bold), TextAlign = ContentAlignment.MiddleCenter };
            ContentPanel.Controls.Add(_timeLabel);
            _timer = new Timer { Interval = 1000 };
            _timer.Tick += delegate { _timeLabel.Text = DateTime.Now.ToString("HH:mm"); };
            _timer.Start();
            _timeLabel.Text = DateTime.Now.ToString("HH:mm");
            Load();
        }
    }

    public class TimerWidget : WidgetHost {
        private Label _disp;
        private Timer _timer;
        private int _seconds = 0;
        public TimerWidget(string id = null) : base("Timer", 189, 100, id) {
            _disp = new Label { Dock = DockStyle.Fill, ForeColor = Color.Cyan, Font = new Font("Consolas", 24), TextAlign = ContentAlignment.MiddleCenter, Text = "00:00" };
            TextBox input = new TextBox { Dock = DockStyle.Top, BackColor = Color.FromArgb(30,30,35), ForeColor = Color.White, BorderStyle = BorderStyle.None, TextAlign = HorizontalAlignment.Center };
            input.KeyDown += delegate(object s, KeyEventArgs e) { 
                int m;
                if(e.KeyCode == Keys.Enter && int.TryParse(input.Text, out m)) { _seconds = m * 60; _timer.Start(); input.Visible = false; } 
            };
            _timer = new Timer { Interval = 1000 };
            _timer.Tick += delegate { 
                if(_seconds <= 0) { _timer.Stop(); input.Visible = true; return; } 
                _seconds--; _disp.Text = string.Format("{0:D2}:{1:D2}", _seconds / 60, _seconds % 60); 
            };
            ContentPanel.Controls.Add(_disp); ContentPanel.Controls.Add(input);
            _disp.Click += delegate { _timer.Stop(); input.Visible = true; };
            Load();
        }
    }

    public class BrowserWidget : WidgetHost {
        public BrowserWidget(string id = null) : base("Browser", 400, 300, id) {
            WebBrowser wb = new WebBrowser { Dock = DockStyle.Fill, ScrollBarsEnabled = true };
            wb.Navigate("https://www.google.com");
            ContentPanel.Controls.Add(wb);
            Load();
        }
    }

    public class CalcWidget : WidgetHost {
        private Label _display;
        private string _curr = "";
        public CalcWidget(string id = null) : base("Calculator", 189, 240, id) {
            _display = new Label { Dock = DockStyle.Top, Height = 40, ForeColor = Color.White, Font = new Font("Consolas", 14), TextAlign = ContentAlignment.MiddleRight, Text = "0" };
            ContentPanel.Controls.Add(_display);
            string[] btns = { "7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", "C", "=", "+" };
            TableLayoutPanel g = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 4 };
            for(int i=0; i<4; i++) { g.RowStyles.Add(new RowStyle(SizeType.Percent, 25)); g.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25)); }
            foreach(var b in btns) {
                Button btn = new Button { Text = b, Dock = DockStyle.Fill, FlatStyle = FlatStyle.Flat, ForeColor = Color.Gray, Font = new Font("Segoe UI", 8) };
                btn.FlatAppearance.BorderSize = 0;
                btn.Click += delegate(object s, EventArgs e) {
                    string t = ((Button)s).Text;
                    if(t == "C") _curr = ""; 
                    else if(t == "=") { try { _curr = new System.Data.DataTable().Compute(_curr, null).ToString(); } catch { _curr = "ERR"; } }
                    else _curr += t;
                    _display.Text = string.IsNullOrEmpty(_curr) ? "0" : _curr;
                };
                g.Controls.Add(btn);
            }
            ContentPanel.Controls.Add(g);
            Load();
        }
    }

    public class BatteryWidget : WidgetHost {
        private Label _stat;
        private Timer _timer;
        public BatteryWidget(string id = null) : base("Battery", 189, 80, id) {
            _stat = new Label { Dock = DockStyle.Fill, ForeColor = Color.Lime, Font = new Font("Segoe UI", 24, FontStyle.Bold), TextAlign = ContentAlignment.MiddleCenter };
            ContentPanel.Controls.Add(_stat);
            _timer = new Timer { Interval = 10000 };
            _timer.Tick += delegate { UpdateStatus(); };
            _timer.Start();
            UpdateStatus();
            Load();
        }
        private void UpdateStatus() {
            PowerStatus ps = SystemInformation.PowerStatus;
            int pct = (int)(ps.BatteryLifePercent * 100);
            _stat.Text = pct + "%";
            _stat.ForeColor = pct > 20 ? Color.Lime : Color.OrangeRed;
        }
    }

    public class SystemWidget : WidgetHost {
        private Label _ram;
        private Timer _timer;
        public SystemWidget(string id = null) : base("System", 189, 80, id) {
            _ram = new Label { Dock = DockStyle.Fill, ForeColor = Color.White, Font = new Font("Consolas", 14), TextAlign = ContentAlignment.MiddleCenter };
            ContentPanel.Controls.Add(_ram);
            _timer = new Timer { Interval = 2000 };
            _timer.Tick += delegate { UpdateRam(); };
            _timer.Start();
            UpdateRam();
            Load();
        }
        private void UpdateRam() {
            long mem = Process.GetCurrentProcess().WorkingSet64 / 1024 / 1024;
            _ram.Text = "EXE RAM: " + mem + "MB";
        }
    }

    public class WeatherWidget : WidgetHost {
        private WebBrowser _wb;
        public WeatherWidget(string id = null) : base("Weather", 300, 400, id) {
            _wb = new WebBrowser { Dock = DockStyle.Fill, ScrollBarsEnabled = false, ScriptErrorsSuppressed = true };
            _wb.Navigate("https://wttr.in/?0&m&T&n"); 
            ContentPanel.Controls.Add(_wb);
            Load();
        }
    }
}
