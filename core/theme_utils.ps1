# core/theme_utils.ps1
# Utilities for Premium/Apple-like Styling

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$csharp = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace DesktopWidgets {
    public class AppleMenuRenderer : ToolStripProfessionalRenderer {
        public AppleMenuRenderer() : base(new AppleColorTable()) {}
        
        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e) {
            if (e.Item.Selected) {
                // Apple Blue Selection with Rounded Corners
                Rectangle rc = new Rectangle(Point.Empty, e.Item.Size);
                // Slight inset
                rc.Inflate(-1, -1);
                
                using (SolidBrush brush = new SolidBrush(Color.FromArgb(0, 122, 255))) {
                     // Simple rounded rect manual draw (WinForms doesn't have FillRoundedRect easily accessible without path)
                     // Falling back to standard fill but with specific color
                     e.Graphics.FillRectangle(brush, rc);
                }
            } else {
                base.OnRenderMenuItemBackground(e);
            }
        }
        
        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
             if (e.Item.Selected) {
                 e.TextColor = Color.White;
             }
             base.OnRenderItemText(e);
        }
    }

    public class AppleColorTable : ProfessionalColorTable {
        public override Color MenuItemSelected { get { return Color.FromArgb(0, 122, 255); } }
        public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(0, 122, 255); } }
        public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(0, 122, 255); } }
        public override Color MenuBorder { get { return Color.FromArgb(200, 200, 200); } }
        public override Color MenuItemBorder { get { return Color.Transparent; } }
        
        // Background
        public override Color ToolStripDropDownBackground { get { return Color.FromArgb(245, 245, 247); } } // Off-white
        
        public override Color ImageMarginGradientBegin { get { return Color.FromArgb(245, 245, 247); } }
        public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(245, 245, 247); } }
        public override Color ImageMarginGradientEnd { get { return Color.FromArgb(245, 245, 247); } }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'DesktopWidgets.AppleMenuRenderer').Type) {
    Add-Type -TypeDefinition $csharp -ReferencedAssemblies System.Windows.Forms, System.Drawing
}

function Apply-AppleMenuStyle {
    param([System.Windows.Forms.ContextMenuStrip]$Menu)
    $Menu.Renderer = New-Object DesktopWidgets.AppleMenuRenderer
    
    # Fonts
    $Menu.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    # Styles
    $Menu.ShowImageMargin = $false # Cleaner look unless we have icons everywhere
     
    # Padding
    # $Menu.Padding = New-Object System.Windows.Forms.Padding(5) # WinForms limitation: Padding on DropDown is limited
}
