using System;
using System.Drawing;
using System.Windows.Forms;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace DesktopWidgets {
    public class WidgetSelector : Form {
        private TextBox _search;
        private FlowLayoutPanel _list;
        private List<string> _allTypes = new List<string> { "Clock", "Timer", "Browser", "Calculator", "Note", "Battery", "System", "Weather" };
        public Action<string> OnSelected;

        private bool _isDraggingItem = false;
        private string _dragType = "";
        private string _dragId = null;
        private Point _dragStartPos;

        private Button _btnAvailable, _btnClosed;
        private bool _showClosed = false;

        public WidgetSelector() {
            Size = new Size(200, 320); FormBorderStyle = FormBorderStyle.None;
            BackColor = Color.FromArgb(20, 20, 25); ShowInTaskbar = false; TopMost = true;
            DoubleBuffered = true;
            
            Panel tabs = new Panel { Dock = DockStyle.Top, Height = 30, BackColor = Color.FromArgb(25, 25, 30) };
            _btnAvailable = new Button { Text = "WIDGETS", Dock = DockStyle.Left, Width = 100, FlatStyle = FlatStyle.Flat, ForeColor = Color.White, Font = new Font("Segoe UI", 7, FontStyle.Bold) };
            _btnClosed = new Button { Text = "RECENTLY CLOSED", Dock = DockStyle.Fill, FlatStyle = FlatStyle.Flat, ForeColor = Color.Gray, Font = new Font("Segoe UI", 7, FontStyle.Bold) };
            _btnAvailable.FlatAppearance.BorderSize = 0; _btnClosed.FlatAppearance.BorderSize = 0;
            
            _btnAvailable.Click += delegate { _showClosed = false; _btnAvailable.ForeColor = Color.White; _btnClosed.ForeColor = Color.Gray; Filter(_search.Text); };
            _btnClosed.Click += delegate { _showClosed = true; _btnClosed.ForeColor = Color.White; _btnAvailable.ForeColor = Color.Gray; Filter(_search.Text); };
            tabs.Controls.Add(_btnClosed); tabs.Controls.Add(_btnAvailable);

            _search = new TextBox { Dock = DockStyle.Top, BackColor = Color.FromArgb(30,30,35), ForeColor = Color.White, BorderStyle = BorderStyle.FixedSingle, Font = new Font("Segoe UI", 10), Height = 30 };
            _list = new FlowLayoutPanel { Dock = DockStyle.Fill, AutoScroll = true, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(2) };
            
            _search.TextChanged += delegate { Filter(_search.Text); };
            
            Panel p = new Panel { Dock = DockStyle.Fill, Padding = new Padding(2) };
            p.Controls.Add(_list);
            Controls.Add(p); Controls.Add(_search); Controls.Add(tabs);
            Filter("");
            
            Deactivate += delegate { if(!_isDraggingItem) Close(); };
            Region = Region.FromHrgn(Win32_Extra.CreateRoundRectRgn(0, 0, Width, Height, 5, 5));
        }

        private void Filter(string txt) {
            _list.SuspendLayout(); _list.Controls.Clear();
            if (!_showClosed) {
                foreach(var t in _allTypes.Concat(ModLoader.ModTypes)) {
                    if(!string.IsNullOrEmpty(txt) && !t.ToLower().Contains(txt.ToLower())) continue;
                    AddListItem(t, null);
                }
            } else {
                string dataDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data");
                if (Directory.Exists(dataDir)) {
                    var files = Directory.GetFiles(dataDir, "*.json");
                    foreach (var f in files) {
                        string name = Path.GetFileNameWithoutExtension(f);
                        if (name == "Launcher_Master") continue;
                        if (WidgetHost.ActiveWidgets.Any(w => (w.WidgetType + "_" + w.WidgetId) == name)) continue;

                        int lastUnder = name.LastIndexOf('_');
                        if (lastUnder == -1) continue;
                        string type = name.Substring(0, lastUnder);
                        string id = name.Substring(lastUnder + 1);

                        if(!string.IsNullOrEmpty(txt) && !name.ToLower().Contains(txt.ToLower())) continue;
                        AddListItem(type, id);
                    }
                }
            }
            _list.ResumeLayout();
        }

        private void AddListItem(string type, string id) {
            string labelText = id == null ? type : type + " (" + id + ")";
            Label l = new Label { Text = "  " + labelText, ForeColor = Color.FromArgb(180, 185, 190), Width = 190, Height = 35, TextAlign = ContentAlignment.MiddleLeft, Cursor = Cursors.Hand, Font = new Font("Segoe UI Semibold", 9) };
            l.MouseEnter += delegate { l.BackColor = Color.FromArgb(50, 50, 60); l.ForeColor = Color.White; };
            l.MouseLeave += delegate { l.BackColor = Color.Transparent; l.ForeColor = Color.FromArgb(180, 185, 190); };
            
            l.MouseDown += (s, m) => {
                if (m.Button == MouseButtons.Left) {
                    _isDraggingItem = true;
                    _dragType = type;
                    _dragId = id;
                    _dragStartPos = m.Location;
                    this.Opacity = 0.5;
                }
            };

            l.MouseMove += (s, m) => {
                if (!_isDraggingItem) return;
                Point screenPos = l.PointToScreen(m.Location);
                
                int nW = 189, nH = 139; 
                int nX = screenPos.X - nW / 2, nY = screenPos.Y - nH / 2;
                
                WidgetHost.UpdateGrid(nX, nY, nW, nH, true); 
            };

            l.MouseUp += (s, m) => {
                if (!_isDraggingItem) return;
                _isDraggingItem = false;
                WidgetHost.HideGrid();
                
                Point screenPos = l.PointToScreen(m.Location);
                LauncherWidget main = Application.OpenForms.OfType<LauncherWidget>().FirstOrDefault();
                if (main != null) {
                    if (_dragId == null) main.Spawn(_dragType, new Point(screenPos.X - 95, screenPos.Y - 70));
                    else main.SpawnExisting(_dragType, _dragId).Location = new Point(screenPos.X - 95, screenPos.Y - 70);
                }
                Close();
            };

            l.Click += delegate { 
                if (!_isDraggingItem) {
                    LauncherWidget main = Application.OpenForms.OfType<LauncherWidget>().FirstOrDefault();
                    if (main != null) {
                        if (id == null) main.Spawn(type, new Point(150, 150));
                        else main.SpawnExisting(type, id);
                    }
                    Close(); 
                }
            };

            _list.Controls.Add(l);
        }
    }
}
