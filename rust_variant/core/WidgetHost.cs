using System;
using System.Drawing;
using System.Windows.Forms;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace DesktopWidgets {
    public class WidgetHost : Form {
        public string WidgetId, WidgetType;
        public Panel HeaderPanel, ContentPanel;
        public bool IsLocked = false, SnapToGrid = true, StickToDesktop = true;
        public float TargetOpacity = 1.0f;
        
        protected bool _isDragging = false, _isResizing = false;
        private Point _dragStart, _lastValidPos;
        private Size _resizeStartSize, _lastValidSize;
        private static Form _gridPreview;
        public static bool DebugGridEnabled = false;
        public static List<WidgetHost> ActiveWidgets = new List<WidgetHost>();

        public static int _gridX = 75, _gridY = 75, _offsetX = 0, _offsetY = 0;
        public static int _iconW = 64, _iconH = 64, _padX = 11, _padY = 11;
        private static IntPtr _lvHandle = IntPtr.Zero;

        protected string DataDir { 
            get { 
                string d = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data"); 
                if(!Directory.Exists(d)) Directory.CreateDirectory(d); 
                return d; 
            } 
        }

        protected override CreateParams CreateParams { get { CreateParams cp = base.CreateParams; cp.ExStyle |= Win32.WS_EX_TOOLWINDOW; return cp; } }

        public WidgetHost(string type, int w, int h, string id = null) {
            this.WidgetType = type; this.WidgetId = id ?? Guid.NewGuid().ToString().Substring(0, 8);
            this.FormBorderStyle = FormBorderStyle.None; this.Size = new Size(w, h);
            this.StartPosition = FormStartPosition.Manual; this.ShowInTaskbar = false;
            this.BackColor = Color.FromArgb(15, 15, 20);
            this._lastValidPos = Location; this._lastValidSize = Size;

            HeaderPanel = new Panel { Dock = DockStyle.Top, Height = 20, BackColor = Color.FromArgb(30, 30, 35) };
            ContentPanel = new Panel { Dock = DockStyle.Fill, BackColor = Color.Transparent };
            
            Label title = new Label { Text = WidgetId, ForeColor = Color.FromArgb(70, 70, 80), Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(5, 0, 0, 0), Font = new Font("Segoe UI", 6, FontStyle.Bold) };
            Label close = new Label { Text = "×", ForeColor = Color.FromArgb(60, 60, 70), Dock = DockStyle.Right, Width = 20, TextAlign = ContentAlignment.MiddleCenter, Cursor = Cursors.Hand };
            Label luBtn = new Label { Text = IsLocked ? "L" : "U", ForeColor = IsLocked ? Color.Red : Color.FromArgb(50, 50, 60), Dock = DockStyle.Right, Width = 15, TextAlign = ContentAlignment.MiddleCenter, Cursor = Cursors.Hand };

            Label resizer = new Label { Text = "◢", ForeColor = Color.FromArgb(20, 255, 255, 255), Anchor = AnchorStyles.Bottom | AnchorStyles.Right, Size = new Size(12, 12), TextAlign = ContentAlignment.BottomRight, Cursor = Cursors.SizeNWSE };
            resizer.Location = new Point(Width - 12, Height - 12);

            close.Click += delegate { 
                string p = Path.Combine(DataDir, WidgetType + "_" + WidgetId + ".json");
                if(File.Exists(p)) { string j = File.ReadAllText(p).Replace("\"Open\":true", "\"Open\":false"); File.WriteAllText(p, j); }
                Close(); 
            };
            close.MouseEnter += delegate { close.ForeColor = Color.Red; };
            close.MouseLeave += delegate { close.ForeColor = Color.FromArgb(60, 60, 70); };

            luBtn.Click += delegate { IsLocked = !IsLocked; luBtn.Text = IsLocked ? "L" : "U"; luBtn.ForeColor = IsLocked ? Color.Red : Color.FromArgb(50, 50, 60); Save(); };
            luBtn.MouseEnter += delegate { if(!IsLocked) luBtn.ForeColor = Color.White; };
            luBtn.MouseLeave += delegate { luBtn.ForeColor = IsLocked ? Color.Red : Color.FromArgb(50, 50, 60); };
            
            HeaderPanel.MouseWheel += (s, m) => {
                double nO = Opacity + (m.Delta > 0 ? 0.05 : -0.05);
                Opacity = (float)Math.Max(0.1, Math.Min(1.0, nO));
            };

            HeaderPanel.Controls.Add(title); HeaderPanel.Controls.Add(luBtn); HeaderPanel.Controls.Add(close);
            
            Controls.Add(HeaderPanel);
            Controls.Add(ContentPanel);
            Controls.Add(resizer);
            resizer.BringToFront();

            ContextMenuStrip ctx = new ContextMenuStrip();
            var topMode = new ToolStripMenuItem("Always on Top");
            topMode.Checked = !StickToDesktop;
            topMode.Click += delegate { StickToDesktop = !StickToDesktop; topMode.Checked = !StickToDesktop; UpdateZ(); Save(); };
            ctx.Items.Add(topMode);
            this.ContextMenuStrip = ctx;

            EnableDrag(title); EnableDrag(HeaderPanel); EnableResize(resizer);
            
            ActiveWidgets.Add(this);
            DoubleBuffered = true;
            this.Opacity = 1.0;

            FormClosing += delegate { ActiveWidgets.Remove(this); Save(); };
            this.Shown += (s, e) => { 
                if (Location.X == 0 && Location.Y == 0) CenterToScreen(); 
                this.BringToFront(); this.Activate(); UpdateZ(); 
            };
        }

        public void UpdateZ() { 
            if(!IsHandleCreated) return;
            IntPtr z = StickToDesktop ? Win32.HWND_BOTTOM : Win32.HWND_TOPMOST;
            Win32.SetWindowPos(Handle, z, 0, 0, 0, 0, Win32.SWP_NOMOVE | Win32.SWP_NOSIZE | Win32.SWP_NOACTIVATE); 
        }

        protected static bool TestCollision(Rectangle target, WidgetHost self) {
            bool onTop = self != null && !self.StickToDesktop;
            if(!onTop) {
                RustCore.WidgetRect[] icons = new RustCore.WidgetRect[100]; int ic = RustCore.get_desktop_icons(icons, 100);
                for(int i=0; i<ic; i++) { if(target.IntersectsWith(new Rectangle(icons[i].Left, icons[i].Top, icons[i].Width, icons[i].Height))) return true; }
            }
            foreach(var w in ActiveWidgets) { 
                if(w == self) continue; 
                if(onTop && w.StickToDesktop) continue;
                if(!onTop && !w.StickToDesktop) continue;
                if(target.IntersectsWith(w.Bounds)) return true; 
            }
            return false;
        }

        protected static Point FindFreeSlot(Rectangle current, WidgetHost self, Rectangle avoid) {
            InferGrid();
            for(int radius=1; radius<10; radius++) {
                for(int dx=-radius; dx<=radius; dx++) {
                    for(int dy=-radius; dy<=radius; dy++) {
                        if(Math.Abs(dx)!=radius && Math.Abs(dy)!=radius) continue;
                        int nx = (int)(Math.Round((current.X + dx*_gridX - _offsetX)/(float)_gridX)*_gridX)+_offsetX;
                        int ny = (int)(Math.Round((current.Y + dy*_gridY - _offsetY)/(float)_gridY)*_gridY)+_offsetY;
                        Rectangle test = new Rectangle(nx, ny, current.Width, current.Height);
                        if(test.IntersectsWith(avoid)) continue;
                        if(!TestCollision(test, self)) return new Point(nx, ny);
                    }
                }
            }
            return current.Location;
        }

        protected static void PushItems(Rectangle rect, WidgetHost self) {
            bool onTop = self != null && !self.StickToDesktop;
            foreach(var w in ActiveWidgets.ToList()) {
                if(w == self) continue;
                if(onTop && w.StickToDesktop) continue;
                if(!onTop && !w.StickToDesktop) continue;
                if(rect.IntersectsWith(w.Bounds)) {
                    Point p = FindFreeSlot(w.Bounds, w, rect);
                    w.Location = p; w.Save(); w.UpdateZ();
                }
            }
            if(!onTop) {
                RustCore.WidgetRect[] icons = new RustCore.WidgetRect[100]; int ic = RustCore.get_desktop_icons(icons, 100);
                for(int i=0; i<ic; i++) {
                    Rectangle r = new Rectangle(icons[i].Left, icons[i].Top, icons[i].Width, icons[i].Height);
                    if(rect.IntersectsWith(r)) {
                        Point p = FindFreeSlot(r, null, rect);
                        MoveIcon(i, p.X, p.Y);
                    }
                }
            }
        }

        private static void MoveIcon(int idx, int x, int y) {
            if(_lvHandle == IntPtr.Zero) {
                IntPtr pm = Win32.FindWindow("Progman", null);
                IntPtr sv = Win32.FindWindowEx(pm, IntPtr.Zero, "SHELLDLL_DefView", null);
                if(sv == IntPtr.Zero) {
                    IntPtr ww = IntPtr.Zero;
                    while((ww = Win32.FindWindowEx(IntPtr.Zero, ww, "WorkerW", null)) != IntPtr.Zero) {
                        sv = Win32.FindWindowEx(ww, IntPtr.Zero, "SHELLDLL_DefView", null);
                        if(sv != IntPtr.Zero) break;
                    }
                }
                _lvHandle = Win32.FindWindowEx(sv, IntPtr.Zero, "SysListView32", null);
            }
            if(_lvHandle != IntPtr.Zero) {
                IntPtr lp = (IntPtr)((y << 16) | (x & 0xFFFF));
                Win32.SendMessage(_lvHandle, Win32.LVM_SETITEMPOSITION, (IntPtr)idx, lp);
            }
        }

        protected static void InferGrid() {
            RustCore.WidgetRect[] icons = new RustCore.WidgetRect[100]; int ic = RustCore.get_desktop_icons(icons, 100);
            if (ic < 2) return;
            var rs = icons.Take(ic).ToList(); _iconW = (int)rs.Average(r => r.Width); _iconH = (int)rs.Average(r => r.Height);
            var sx = rs.Select(i => i.Left).Distinct().OrderBy(x => x).ToList();
            var sy = rs.Select(i => i.Top).Distinct().OrderBy(y => y).ToList();
            if (sx.Count > 1) { var dx = new List<int>(); for (int i = 1; i < sx.Count; i++) if (sx[i] - sx[i-1] > 20) dx.Add(sx[i] - sx[i-1]); if (dx.Count > 0) { _gridX = dx.GroupBy(v => v).OrderByDescending(g => g.Count()).First().Key; _offsetX = sx[0] % _gridX; } }
            if (sy.Count > 1) { var dy = new List<int>(); for (int i = 1; i < sy.Count; i++) if (sy[i] - sy[i-1] > 20) dy.Add(sy[i] - sy[i-1]); if (dy.Count > 0) { _gridY = dy.GroupBy(v => v).OrderByDescending(g => g.Count()).First().Key; _offsetY = sy[0] % _gridY; } }
            _padX = _gridX - _iconW; _padY = _gridY - _iconH;
        }

        protected void EnableDrag(Control c) {
            c.MouseDown += (s, m) => { if(m.Button==MouseButtons.Left && !IsLocked) { _isDragging=true; _dragStart=c.PointToScreen(m.Location); _lastValidPos=Location; InferGrid(); HeaderPanel.BackColor = Color.FromArgb(40, 60, 70); } };
            c.MouseMove += (s, m) => { if(!_isDragging) return; 
                Point cur = c.PointToScreen(m.Location);
                int nX = _lastValidPos.X + (cur.X - _dragStart.X), nY = _lastValidPos.Y + (cur.Y - _dragStart.Y);
                int oX, oY; RustCore.WidgetRect[] icons = new RustCore.WidgetRect[100]; int ic = RustCore.get_desktop_icons(icons, 100);
                RustCore.calculate_snap(nX, nY, Width, Height, ActiveWidgets.Where(w=>w!=this).Select(w=>new RustCore.WidgetRect{Left=w.Left,Top=w.Top,Width=w.Width,Height=w.Height}).ToArray(), ActiveWidgets.Count-1, icons, ic, out oX, out oY);
                int gX = (int)(Math.Round((oX-_offsetX)/(float)_gridX)*_gridX)+_offsetX, gY = (int)(Math.Round((oY-_offsetY)/(float)_gridY)*_gridY)+_offsetY;
                if(Location.X != gX || Location.Y != gY) {
                    Rectangle proposed = new Rectangle(gX, gY, Width, Height);
                    PushItems(proposed, this);
                    UpdateGrid(gX, gY, Width, Height, true); Location = new Point(gX, gY);
                }
            };
            c.MouseUp += delegate { _isDragging=false; HideGrid(); UpdateZ(); Save(); HeaderPanel.BackColor = Color.FromArgb(30, 30, 35); };
        }

        protected void EnableResize(Control c) {
            c.MouseDown += (s, m) => { if(m.Button==MouseButtons.Left && !IsLocked) { _isResizing=true; _dragStart=c.PointToScreen(m.Location); _resizeStartSize=Size; InferGrid(); } };
            c.MouseMove += (s, m) => { if(!_isResizing) return;
                Point cur = c.PointToScreen(m.Location);
                int nW_base = _resizeStartSize.Width + (cur.X - _dragStart.X), nH_base = _resizeStartSize.Height + (cur.Y - _dragStart.Y);
                int cols = (int)((nW_base + (_gridX * 0.4)) / _gridX), rows = (int)((nH_base + (_gridY * 0.4)) / _gridY);
                int nW = Math.Max(_gridX - _padX, (cols * _gridX) - _padX), nH = Math.Max(_gridY - 4, (rows * _gridY) - 4);
                nW = Math.Max(120, nW); nH = Math.Max(64, nH);
                if(Size.Width != nW || Size.Height != nH) {
                    UpdateGrid(Left, Top, nW, nH, true); Size = new Size(nW, nH);
                }
            };
            c.MouseUp += delegate { _isResizing=false; HideGrid(); UpdateZ(); Save(); };
        }

        public static void UpdateGrid(int x, int y, int w, int h, bool valid) {
            if(_gridPreview==null || _gridPreview.IsDisposed) {
                _gridPreview = new Form { FormBorderStyle=FormBorderStyle.None, Opacity=0.2, TopMost=true, ShowInTaskbar=false, StartPosition=FormStartPosition.Manual };
                typeof(Form).GetProperty("DoubleBuffered", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).SetValue(_gridPreview, true, null);
            }
            if(_gridPreview.Location.X != x || _gridPreview.Location.Y != y || _gridPreview.Size.Width != w || _gridPreview.Size.Height != h) {
                _gridPreview.Location=new Point(x,y); _gridPreview.Size=new Size(w,h); _gridPreview.BackColor=valid?Color.LightCyan:Color.Red; 
            }
            if(!_gridPreview.Visible) _gridPreview.Show();
        }
        public static void HideGrid() { if(_gridPreview!=null) _gridPreview.Hide(); }

        public virtual void Save() { 
            string p = Path.Combine(DataDir, WidgetType + "_" + WidgetId + ".json"); 
            File.WriteAllText(p, string.Format("{{\"X\":{0},\"Y\":{1},\"W\":{2},\"H\":{3},\"T\":{4},\"L\":{5},\"Open\":{6},\"O\":{7}}}", Left, Top, Width, Height, (!StickToDesktop).ToString().ToLower(), IsLocked.ToString().ToLower(), Visible.ToString().ToLower(), Opacity.ToString("F2").Replace(",", "."))); 
        }
        public new virtual void Load() { 
            try { 
                string p = Path.Combine(DataDir, WidgetType + "_" + WidgetId + ".json"); if(!File.Exists(p)) return; 
                string j = File.ReadAllText(p); Location = new Point(int.Parse(Ex(j,"X")), int.Parse(Ex(j,"Y"))); 
                if(j.Contains("\"W\":")) Size = new Size(int.Parse(Ex(j,"W")), int.Parse(Ex(j,"H"))); 
                if(j.Contains("\"O\":")) Opacity = float.Parse(Ex(j,"O").Replace(".", ","));
                StickToDesktop = !j.Contains("\"T\":true"); IsLocked = j.Contains("\"L\":true"); _lastValidPos=Location; _lastValidSize=Size;
                if(ContextMenuStrip != null && ContextMenuStrip.Items.Count > 0) {
                    ToolStripMenuItem mi = ContextMenuStrip.Items[0] as ToolStripMenuItem;
                    if(mi != null) mi.Checked = !StickToDesktop;
                }
            } catch {} 
        }
        protected string Ex(string j, string k) { 
            string key = "\"" + k + "\":";
            int s = j.IndexOf(key); 
            if(s == -1) return "0";
            s += key.Length;
            int e = j.IndexOfAny(new char[] { ',', '}' }, s); 
            if(e == -1) return "0";
            return j.Substring(s, e-s).Trim(' ', '\"', ':', '\r', '\n'); 
        }
    }
}
