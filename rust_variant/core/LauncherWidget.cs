using System;
using System.Drawing;
using System.Windows.Forms;
using System.IO;
using System.Linq;

namespace DesktopWidgets {
    public class LauncherWidget : WidgetHost {

        public LauncherWidget() : base("Launcher", 64, 64, "Master") {
            HeaderPanel.Visible = false;
            Label p = new Label { Text = "+", ForeColor = Color.White, Font = new Font("Segoe UI Semibold", 32), TextAlign = ContentAlignment.MiddleCenter, Dock = DockStyle.Fill, Cursor = Cursors.Hand };
            ContentPanel.Controls.Add(p);
            ContentPanel.Dock = DockStyle.Fill;
            p.BringToFront();

            p.Click += (s, m) => {
                var sel = new WidgetSelector();
                sel.Location = new Point(Left, Top - sel.Height - 5);
                sel.Show();
            };

            EnableDrag(p);
            ContextMenuStrip ctx = new ContextMenuStrip();
            ctx.Items.Add("Quick Note").Click += delegate { Spawn("Note", new Point(150, 150)); };
            ctx.Items.Add(new ToolStripSeparator());
            ctx.Items.Add("Close All Widgets").Click += delegate { CloseAll(); };
            ctx.Items.Add("Exit Engine").Click += delegate { Application.Exit(); };
            ctx.Items.Add(new ToolStripSeparator());
            ctx.Items.Add("Clean Data").Click += delegate { if(Directory.Exists(DataDir)) Directory.Delete(DataDir, true); Application.Restart(); };
            ctx.Items.Add("Reset Master").Click += delegate { Location = new Point(100,100); Save(); };
            p.ContextMenuStrip = ctx;
        }

        private void CloseAll() {
            foreach(var w in WidgetHost.ActiveWidgets.ToList()) {
                if(w == this) continue;
                string p = Path.Combine(DataDir, w.WidgetType + "_" + w.WidgetId + ".json");
                if(File.Exists(p)) { string j = File.ReadAllText(p).Replace("\"Open\":true", "\"Open\":false"); File.WriteAllText(p, j); }
                w.Close();
            }
        }

        public void Spawn(string type, Point pos, Size? size = null) {
            WidgetHost w = CreateWidget(type);
            w.Location = pos;
            if (size.HasValue) w.Size = size.Value;
            w.Show(); w.Save();
        }

        public WidgetHost SpawnExisting(string type, string id) {
            WidgetHost w = CreateWidget(type, id);
            w.Show();
            return w;
        }

        public static WidgetHost CreateWidget(string type, string id = null) {
            if (type == "Clock") return new ClockWidget(id);
            if (type == "Timer") return new TimerWidget(id);
            if (type == "Browser") return new BrowserWidget(id);
            if (type == "Calculator") return new CalcWidget(id);
            if (type == "Battery") return new BatteryWidget(id);
            if (type == "System") return new SystemWidget(id);
            if (type == "Weather") return new WeatherWidget(id);
            WidgetHost mod = ModLoader.CreateMod(type, id);
            if (mod != null) return mod;
            return new StandardWidget(type, id);
        }
    }
}
