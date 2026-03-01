using System;
using System.Drawing;
using System.Windows.Forms;
using System.IO;

namespace DesktopWidgets {
    public class Engine { 
        [STAThread] static void Main() { 
            Application.EnableVisualStyles(); 
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string dataDir = Path.Combine(baseDir, "data");
            
            if(!Directory.Exists(dataDir)) Directory.CreateDirectory(dataDir);
            ModLoader.Load();

            if (Directory.GetFiles(dataDir, "*.json").Length == 0) {
                string welcomeId = "QuickStart";
                File.WriteAllText(Path.Combine(dataDir, "Note_" + welcomeId + "_content.txt"), "Welcome to Widgets!\r\n1. Drag the [+] icon to spawn.\r\n2. Click [+] for a searchable list.\r\n3. Use 'L/U' to lock or toggle Top-Level.");
                StandardWidget welcome = new StandardWidget("Note", welcomeId);
                welcome.Location = new Point(150, 150);
                welcome.Save();
                welcome.Show();
            } else {
                foreach(var f in Directory.GetFiles(dataDir, "*.json")) {
                    try {
                        string name = Path.GetFileNameWithoutExtension(f);
                        if (name == "Launcher_Master") continue; 
                        
                        int lastUnder = name.LastIndexOf('_');
                        if (lastUnder == -1) continue;
                        
                        string type = name.Substring(0, lastUnder);
                        string id = name.Substring(lastUnder + 1);
                        
                        string j = File.ReadAllText(f);
                        if (j.Contains("\"Open\":false")) continue;

                        WidgetHost w = LauncherWidget.CreateWidget(type, id);
                        if(w != null) w.Show();
                    } catch {}
                }
            }
            Application.Run(new LauncherWidget()); 
        } 
    }
}
