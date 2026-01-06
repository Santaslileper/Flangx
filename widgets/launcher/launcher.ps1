try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)

    # Load Core
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    # widget_base.ps1 is the aggregator that loads all other core modules
    . "$rootDir\core\widget_base.ps1"

    # Configuration
    $configPath = Join-Path $scriptDir "config.json"
    $widgetsDir = Split-Path -Parent $scriptDir

    # Track spawned widgets
    $script:ManagedWidgets = @{}

    # Theme
    $theme = @{
        Background = [System.Drawing.Color]::FromArgb(60, 140, 220)
        Foreground = [System.Drawing.Color]::White
        Indicator  = [System.Drawing.Color]::FromArgb(100, 255, 255, 255)
    }

    # Widget Definitions & Dynamic Discovery
    $script:AvailableWidgets = @()
    $widgetDirs = Get-ChildItem -Path $widgetsDir -Directory
    
    foreach ($dir in $widgetDirs) {
        if ($dir.Name -eq "launcher") { continue }
        
        # Flexible script discovery
        $scriptPath = Join-Path $dir.FullName "$($dir.Name).ps1"
        if (-not (Test-Path $scriptPath)) {
            $psFiles = Get-ChildItem -Path $dir.FullName -Filter "*.ps1"
            if ($psFiles.Count -eq 1) {
                $scriptPath = $psFiles[0].FullName
            }
        }
        
        $metaPath = Join-Path $dir.FullName "metadata.json"
        
        if (Test-Path $scriptPath) {
            # Defaults
            $wName = $dir.Name
            $wIcon = "🧩"
            $wWidth = 200
            $wHeight = 200
            
            # Load Metadata if exists
            if (Test-Path $metaPath) {
                try {
                    $meta = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($meta.Name) { $wName = $meta.Name }
                    if ($meta.Icon) { $wIcon = $meta.Icon }
                    if ($meta.Width) { $wWidth = $meta.Width }
                    if ($meta.Height) { $wHeight = $meta.Height }
                    if ($meta.AllowMultiple) { $wAllowMultiple = $meta.AllowMultiple } else { $wAllowMultiple = $false }
                }
                catch {}
            }
            
            $relScript = $scriptPath.Substring($widgetsDir.Length + 1)
            
            $script:AvailableWidgets += @{ 
                Name          = $wName
                Icon          = $wIcon 
                Script        = $relScript
                Width         = $wWidth
                Height        = $wHeight 
                AllowMultiple = $wAllowMultiple
            }
        }
    }

    # Create Main Form
    # Size: 75x75 (1 cell) with Taskbar visibility
    # Factory handles Header (we might want a smaller header or no header for the launcher?)
    # Usually Launchers are small. The standard header (24px) consumes 1/3 of 75px. 
    # Let's increase size slightly to 90x90 or just keep it compact.
    # User asked for cell usage. 75x75 is one cell.
    # Header takes 24. Remaining 51.
    # If the user wants the Launcher to be a "Wiget" that opens the drawer, it should look like one.
    $form = New-StandardWidget -Name "Desktop Widgets" -Width 90 -Height 90 -ConfigPath $configPath -Theme $theme -ShowInTaskbar $true
    
    # Set Icon
    try {
        $iconPath = Join-Path $scriptDir "..\..\assets\clock_icon.ico"
        if (Test-Path $iconPath) {
            $form.Icon = [System.Drawing.Icon]::new($iconPath)
        }
        else {
            $iconPath = "$env:SystemRoot\System32\desk.cpl"
            if (Test-Path $iconPath) { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath) }
        }
    }
    catch {}

    # --- Launcher Specific UI ---
    
    # Use standard ContentPanel
    $panel = $form.Tag.ContentPanel
    $panel.Padding = New-Object System.Windows.Forms.Padding(0)

    # Plus Label
    $plusLabel = New-Object System.Windows.Forms.Label
    $plusLabel.Text = "+"
    $plusLabel.ForeColor = $theme.Foreground
    $plusLabel.Dock = "Fill"
    $plusLabel.TextAlign = "MiddleCenter"
    $plusLabel.Font = New-Object System.Drawing.Font("Segoe UI Light", 36, [System.Drawing.FontStyle]::Regular)
    $plusLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panel.Controls.Add($plusLabel)

    # --- Interaction Setup ---
    # Drag for Plus Label (Factory handles Form/Header)
    $indicator = $form.Tag.Header
    Enable-WidgetDrag -Controls @($plusLabel) -Form $form -IndicatorPanel $indicator
    
    # --- Drawer Logic ---
    . "$scriptDir\drawer_logic.ps1"

    $plusLabel.Add_Click({ 
            Show-WidgetDrawer -LauncherForm $form -AvailableWidgets $script:AvailableWidgets -WidgetsDir $widgetsDir -ManagedWidgets $script:ManagedWidgets
        })

    # Custom Context Menu (Append to existing Standard Menu)
    $ctx = $form.ContextMenuStrip

    # Add "Manage Widgets" Submenu
    $sep = New-Object System.Windows.Forms.ToolStripSeparator
    $ctx.Items.Insert($ctx.Items.Count - 2, $sep) # Insert before "Close"
    $widgetMenu = New-Object System.Windows.Forms.ToolStripMenuItem("Manage Widgets")

    # Close All
    $closeAll = $widgetMenu.DropDownItems.Add("Close All Active")
    $closeAll.Add_Click({
            foreach ($key in @($script:ManagedWidgets.Keys)) {
                $w = $script:ManagedWidgets[$key]
                if ($w.Process -and -not $w.Process.HasExited) {
                    try { $w.Process.Kill() } catch {}
                }
                $script:ManagedWidgets.Remove($key)
            }
        })
        
    # Active Count (Update on Hover)
    $widgetMenu.DropDown.Add_Opening({
            # Cleanup dead processes
            $keys = @($script:ManagedWidgets.Keys)
            foreach ($k in $keys) {
                if ($script:ManagedWidgets[$k].Process.HasExited) { $script:ManagedWidgets.Remove($k) }
            }
            $closeAll.Text = "Close All Active ($($script:ManagedWidgets.Count))"
            $closeAll.Enabled = ($script:ManagedWidgets.Count -gt 0)
        }.GetNewClosure())

    # Startup Separator
    $widgetMenu.DropDownItems.Add("-")

    # Run on Startup Toggle
    $startupItem = $widgetMenu.DropDownItems.Add("Run on Startup")
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DesktopWidgets.lnk"
        
    $startupItem.Add_Click({
            if (Test-Path $startupPath) {
                Remove-Item $startupPath -Force
            }
            else {
                $wScript = New-Object -ComObject WScript.Shell
                $sc = $wScript.CreateShortcut($startupPath)
                $sc.TargetPath = (Get-Command powershell.exe).Source
                $targetScript = Join-Path $widgetsDir "Start-Widgets.ps1"
                $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`""
                $sc.WorkingDirectory = $widgetsDir
                $sc.IconLocation = "shell32.dll,3" 
                $sc.Save()
            }
        })
        
    $widgetMenu.DropDown.Add_Opening({
            $startupItem.Checked = (Test-Path $startupPath)
        }.GetNewClosure())

    $ctx.Items.Insert($ctx.Items.Count - 2, $widgetMenu)

    # --- Session Restoration ---
    # Scan for existing configurations and launch them
    $wSubDirs = Get-ChildItem -Path $widgetsDir -Directory
    foreach ($dir in $wSubDirs) {
        if ($dir.Name -eq "launcher") { continue }
        
        $scriptPath = Join-Path $dir.FullName "$($dir.Name).ps1"
        if (-not (Test-Path $scriptPath)) { continue }
        
        # 1. Default Instance (config.json)
        $defaultConfig = Join-Path $dir.FullName "config.json"
        if (Test-Path $defaultConfig) {
            $shouldRun = $true
            try {
                $check = Get-Content $defaultConfig -Raw | ConvertFrom-Json
                if ($null -ne $check.Active -and $check.Active -eq $false) {
                    $shouldRun = $false
                }
            }
            catch {}

            if ($shouldRun) {
                $proc = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "-X", "-1", "-Y", "-1", "-WindowStyle", "Hidden", "-PassThru"
                $script:ManagedWidgets["$($dir.Name)_Default"] = @{ Process = $proc; Type = $dir.Name }
                continue 
            }
        }
    }

    Write-Host "About to Run Form"
    [System.Windows.Forms.Application]::Run($form)
}
catch {
    Write-Host "CRASH: $_"
    $_ | Out-File "$PSScriptRoot\launch_error.log"
}
