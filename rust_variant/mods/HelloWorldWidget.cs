using System;
using System.Drawing;
using System.Windows.Forms;
using DesktopWidgets;

public class HelloWorldWidget : WidgetHost {
    public HelloWorldWidget(string id = null) : base("HelloWorld", 200, 100, id) {
        Label l = new Label { 
            Text = "HELLO FROM MOD!", 
            ForeColor = Color.Gold, 
            Dock = DockStyle.Fill, 
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Segoe UI", 12, FontStyle.Bold)
        };
        ContentPanel.Controls.Add(l);
        Load();
    }
}
