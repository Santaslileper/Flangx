# widgets/launcher/drawer_logic.ps1
# Logic for the Widget Drawer (Selection Grid)

$script:drawerForm = $null

function Show-WidgetDrawer {
    param($LauncherForm, $AvailableWidgets, $WidgetsDir, $ManagedWidgets)

    if ($script:drawerForm -and -not $script:drawerForm.IsDisposed) {
        $script:drawerForm.Close(); $script:drawerForm = $null; return
    }
    
    # Drawer Configuration
    $drawerWidth = 230 
    $drawerHeight = 400
    
    $drawer = New-Object System.Windows.Forms.Form
    $drawer.FormBorderStyle = "None"
    $drawer.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $drawer.Size = New-Object System.Drawing.Size($drawerWidth, $drawerHeight)
    $drawer.StartPosition = "Manual"
    $drawer.TopMost = $true
    $drawer.ShowInTaskbar = $false
    
    # Position (Above or Below Launcher)
    $screen = [System.Windows.Forms.Screen]::FromControl($LauncherForm)
    $btnPos = $LauncherForm.PointToScreen([System.Drawing.Point]::Empty)
    
    $dx = $btnPos.X + ($LauncherForm.Width / 2) - ($drawerWidth / 2)
    $dy = $btnPos.Y - $drawerHeight - 10
    
    if ($dy -lt $screen.WorkingArea.Top) { $dy = $btnPos.Y + $LauncherForm.Height + 10 }
    if ($dx -lt $screen.WorkingArea.Left) { $dx = $screen.WorkingArea.Left + 10 }
    if (($dx + $drawerWidth) -gt $screen.WorkingArea.Right) { $dx = $screen.WorkingArea.Right - $drawerWidth - 10 }
    
    $drawer.Location = New-Object System.Drawing.Point([int]$dx, [int]$dy)
    
    # --- UI Layout ---
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock = "Top"
    $topPanel.Height = 40
    $topPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $topPanel.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $drawer.Controls.Add($topPanel)
    
    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Dock = "Fill"
    $searchBox.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
    $searchBox.ForeColor = "White"
    $searchBox.BorderStyle = "FixedSingle"
    $searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $searchBox.Text = "Search..."
    $topPanel.Controls.Add($searchBox)
    
    $searchBox.Add_GotFocus({ if ($this.Text -eq "Search...") { $this.Text = ""; $this.ForeColor = "White" } })
    $searchBox.Add_LostFocus({ if ($this.Text -eq "") { $this.Text = "Search..."; $this.ForeColor = "Gray" } })
    
    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Dock = "Bottom"
    $nameLabel.Height = 30
    $nameLabel.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 30)
    $nameLabel.ForeColor = "White"
    $nameLabel.TextAlign = "MiddleCenter"
    $nameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $nameLabel.Text = "Select a Widget"
    $drawer.Controls.Add($nameLabel)
    
    $grid = New-Object System.Windows.Forms.FlowLayoutPanel
    $grid.Dock = "Fill"
    $grid.AutoScroll = $true
    $grid.Padding = New-Object System.Windows.Forms.Padding(10)
    $grid.BackColor = "Transparent"
    $drawer.Controls.Add($grid)
    $grid.BringToFront()
    
    $script:AllItems = @()
    
    $PopulateGrid = {
        param($filter)
        $grid.SuspendLayout()
        
        $lbl = $nameLabel
        $wd = $WidgetsDir
        $mw = $ManagedWidgets
        
        while ($grid.Controls.Count -gt 0) {
            $c = $grid.Controls[0]
            $grid.Controls.RemoveAt(0)
            $c.Dispose()
        }
        
        foreach ($widget in $AvailableWidgets) {
            if ($null -eq $widget) { continue }
            if ($filter -and $filter -ne "Search..." -and $widget.Name -notmatch "(?i)$filter") { continue }
        
            $container = New-Object System.Windows.Forms.Panel
            $container.Size = New-Object System.Drawing.Size(84, 90)
            $container.Margin = New-Object System.Windows.Forms.Padding(3)
            $container.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
            $container.Cursor = [System.Windows.Forms.Cursors]::Hand
            $container.Tag = $widget

            $icon = New-Object System.Windows.Forms.Label
            $icon.Text = $widget.Icon
            $icon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 24)
            $icon.ForeColor = "White"
            $icon.BackColor = "Transparent"
            $icon.TextAlign = "MiddleCenter"
            $icon.Dock = "Top"
            $icon.Height = 55
            $icon.Tag = $widget 
            
            $text = New-Object System.Windows.Forms.Label
            $text.Text = $widget.Name
            $text.Font = New-Object System.Drawing.Font("Segoe UI", 7)
            $text.ForeColor = "Silver"
            $text.BackColor = "Transparent"
            $text.TextAlign = "TopCenter"
            $text.Dock = "Fill"
            $text.Tag = $widget 
            
            $container.Controls.Add($text)
            $container.Controls.Add($icon)
            
            $hoverEnter = { 
                param($s, $e)
                try {
                    $ctl = $this
                    if ($ctl -is [System.Windows.Forms.Label]) { $ctl = $ctl.Parent }
                    if ($ctl) {
                        $ctl.BackColor = [System.Drawing.Color]::FromArgb(80, 180, 255)
                        foreach ($c in $ctl.Controls) {
                            if ($c -is [System.Windows.Forms.Label] -and $c.Dock -eq "Fill") { $c.ForeColor = "Black" }
                        }
                        if ($lbl -and $ctl.Tag) { $lbl.Text = $ctl.Tag.Name }
                    }
                }
                catch {}
            }.GetNewClosure()
            
            $hoverLeave = { 
                param($s, $e) 
                try {
                    $ctl = $this
                    if ($ctl -is [System.Windows.Forms.Label]) { $ctl = $ctl.Parent }
                    if ($ctl) {
                        $ctl.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
                        foreach ($c in $ctl.Controls) {
                            if ($c -is [System.Windows.Forms.Label] -and $c.Dock -eq "Fill") { $c.ForeColor = "Silver" }
                        }
                        if ($lbl) { $lbl.Text = "Select a Widget" }
                    }
                }
                catch {}
            }.GetNewClosure()
            
            $dragLogic = {
                param($s, $e)
                try {
                    if ($e.Button -ne 'Left') { return }
                
                    $wInfo = $this.Tag
                    if ($null -eq $wInfo) { return }

                    $startPos = [System.Windows.Forms.Control]::MousePosition
                    $isDrag = $false
                    $dragThreshold = 5
                    $ghost = $null
                    
                    while ([System.Windows.Forms.Control]::MouseButtons -eq 'Left') {
                        $currPos = [System.Windows.Forms.Control]::MousePosition
                        
                        if (-not $isDrag -and ([Math]::Abs($currPos.X - $startPos.X) -gt $dragThreshold -or [Math]::Abs($currPos.Y - $startPos.Y) -gt $dragThreshold)) {
                            $isDrag = $true
                            
                            # Ghost Window (with standard rounded/transparent look)
                            $ghost = New-Object System.Windows.Forms.Form
                            $ghost.FormBorderStyle = "None"
                            $w = if ($wInfo.Width) { $wInfo.Width } else { 100 }
                            $h = if ($wInfo.Height) { $wInfo.Height } else { 100 }
                            $ghost.Size = New-Object System.Drawing.Size($w, $h)
                            $ghost.Opacity = 0.6
                            $ghost.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
                            $ghost.TopMost = $true
                            $ghost.ShowInTaskbar = $false
                            
                            # Rounded Corners for Ghost
                            $ghost.Add_Load({
                                    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                                    $rect = $ghost.ClientRectangle
                                    $radius = 20
                                    $d = $radius * 2
                                    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
                                    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
                                    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
                                    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
                                    $path.CloseFigure()
                                    $ghost.Region = New-Object System.Drawing.Region($path)
                                })
                            
                            $gLabel = New-Object System.Windows.Forms.Label
                            $gLabel.Text = $wInfo.Icon; $gLabel.Dock = "Fill"; $gLabel.TextAlign = "MiddleCenter"
                            $gLabel.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 24)
                            $gLabel.ForeColor = "White"
                            $ghost.Controls.Add($gLabel)
                            $ghost.Show() 
                        }
                        
                        if ($isDrag) {
                            # Snap Logic for Ghost
                            $w = $ghost.Width
                            $h = $ghost.Height
                            $rawX = $currPos.X - ($w / 2)
                            $rawY = $currPos.Y - ($h / 2)
                            
                            # Use Get-SnapPosition to find where it WOULD snap
                            $snapResult = global:Get-SnapPosition -CurrentX $rawX -CurrentY $rawY -WidgetWidth $w -WidgetHeight $h
                            
                            $ghost.Location = New-Object System.Drawing.Point($snapResult.X, $snapResult.Y)
                            
                            # Visual feedback for snap could be added (color change), but position snap is enough.
                        }
                        
                        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 10
                    }
                    
                    if ($isDrag) {
                        # Final Drop Location (Ghost Location)
                        $finalX = $ghost.Location.X
                        $finalY = $ghost.Location.Y
                        
                        $ghost.Close(); $ghost.Dispose()
                        if ($script:drawerForm) { $script:drawerForm.Close() }
                        
                        $wPath = Join-Path $wd $wInfo.Script
                        
                        if (Test-Path $wPath) {
                            $sanitizedName = $wInfo.Name -replace '\s+', ''
                            $instanceId = if ($wInfo.AllowMultiple) { (Get-Date -Format "yyyyMMddHHmmssfff") + "_" + (Get-Random -Maximum 9999) } else { $null }
                            
                            if (-not $wInfo.AllowMultiple) {
                                $widgetDir = Split-Path -Parent $wPath
                                $configPath = Join-Path $widgetDir "config.json"
                                $configData = @{ X = $finalX; Y = $finalY; Width = $wInfo.Width; Height = $wInfo.Height; Locked = $false; Active = $true; TopMost = $true }
                                $configData | ConvertTo-Json | Out-File $configPath -Encoding UTF8
                                
                                if ($mw["${sanitizedName}_Default"] -and -not $mw["${sanitizedName}_Default"].Process.HasExited) {
                                    try { $mw["${sanitizedName}_Default"].Process.Kill() } catch {}
                                }
                            }
                            
                            $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$wPath`"", "-X", "$finalX", "-Y", "$finalY", "-PassThru")
                            if ($instanceId) { $argsList += ("-InstanceId", "$instanceId") }

                            $proc = Start-Process powershell.exe -ArgumentList $argsList
                            
                            if ($mw) { 
                                $key = if ($instanceId) { "${sanitizedName}_${instanceId}" } else { "${sanitizedName}_Default" }
                                $mw[$key] = @{ Process = $proc; Type = $wInfo.Name } 
                            }
                        }
                    }
                    else {
                        # Just Clicked
                        $sanitizedName = $wInfo.Name -replace '\s+', ''
                        if (-not $wInfo.AllowMultiple -and $null -ne $mw["${sanitizedName}_Default"] -and -not $mw["${sanitizedName}_Default"].Process.HasExited) { return }
                        
                        $wPath = Join-Path $wd $wInfo.Script
                        if (Test-Path $wPath) {
                            $instanceId = if ($wInfo.AllowMultiple) { (Get-Date -Format "yyyyMMddHHmmssfff") + "_" + (Get-Random -Maximum 9999) } else { $null }
                            
                            $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$wPath`"", "-X", "-1", "-Y", "-1", "-PassThru")
                            if ($instanceId) { $argsList += ("-InstanceId", "$instanceId") }
                            
                            $proc = Start-Process powershell.exe -ArgumentList $argsList
                            if ($mw) { 
                                $key = if ($instanceId) { "${sanitizedName}_${instanceId}" } else { "${sanitizedName}_Default" }
                                $mw[$key] = @{ Process = $proc; Type = $wInfo.Name } 
                            }
                            if ($script:drawerForm) { $script:drawerForm.Close() }
                        }
                    }
                }
                catch { Write-Host "Error in Widget Event: $_" }
            }.GetNewClosure()

            $container.Add_MouseEnter($hoverEnter)
            $container.Add_MouseLeave($hoverLeave)
            $container.Add_MouseDown($dragLogic)
            $icon.Add_MouseEnter($hoverEnter); $text.Add_MouseEnter($hoverEnter)
            $icon.Add_MouseLeave($hoverLeave); $text.Add_MouseLeave($hoverLeave)
            $icon.Add_MouseDown($dragLogic); $text.Add_MouseDown($dragLogic)
            
            $grid.Controls.Add($container)
        }
        $grid.ResumeLayout()
    }.GetNewClosure()
    
    & $PopulateGrid $null
    
    $searchBox.Add_TextChanged({ & $PopulateGrid $searchBox.Text }.GetNewClosure())
    $drawer.Add_Deactivate({ $this.Close() })
    
    $script:drawerForm = $drawer
    $drawer.Show()
    $drawer.Activate()
}
