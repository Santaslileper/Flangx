function global:New-StandardWidget {
    param(
        [string]$Name,
        [int]$Width = 80,
        [int]$Height = 80,
        [string]$ConfigPath,
        [hashtable]$Theme,
        [bool]$ShowInTaskbar = $global:AppConfig.ShowInTaskbar,
        [bool]$NoHeader = $false,
        [int]$HeaderHeight = 24
    )
    $script:WidgetState.ConfigPath = $ConfigPath
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Name
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.FormBorderStyle = "None"
    $form.BackColor = $Theme.Background
    $form.ShowInTaskbar = $ShowInTaskbar
    $form.TopMost = $false
    $form.StartPosition = "CenterScreen" 
    $form.TransparencyKey = [System.Drawing.Color]::Empty
    try { [System.Console]::Title = "DesktopWidget_$Name" } catch {}
    $form.Tag = @{
        IsDragging      = $false
        DragStartX      = 0
        DragStartY      = 0
        IsLocked        = $false
        SnapToGrid      = $true
        TopMost         = $false
        PinnedToDesktop = $false
        ContentPanel    = $null
        Header          = $null
        StealthMode     = $true  # Default to Stealth Headers
    }
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $state = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($null -ne $state.X -and $null -ne $state.Y) {
                $form.StartPosition = "Manual"
                $form.Location = New-Object System.Drawing.Point($state.X, $state.Y)
            }
            if ($null -ne $state.Width -and $null -ne $state.Height) {
                $form.Size = New-Object System.Drawing.Size($state.Width, $state.Height)
            }
            if ($state.Locked) { 
                $script:WidgetState.IsLocked = $true
                $form.Tag.IsLocked = $true
            }
            if ($null -ne $state.SnapToGrid) { 
                $script:WidgetState.SnapToGrid = $state.SnapToGrid 
                $form.Tag.SnapToGrid = $state.SnapToGrid
            }
            if ($null -ne $state.TopMost) { 
                $script:WidgetState.TopMost = $state.TopMost 
                $form.TopMost = $state.TopMost
                $form.Tag.TopMost = $state.TopMost
            }
        }
        catch { Write-Warning "Config Load Error: $_" }
    }
    $updateRegion = {
        param($sender, $e) 
        if ($form.WindowState -eq 'Minimized') { return }
        # Square corners as requested
        # $radius = 20 ... (Disabled)
        $form.Region = $null 
        $form.Invalidate() 
    }.GetNewClosure()
    $form.Add_Load($updateRegion)
    $form.Add_Resize($updateRegion)
    
    $indicator = $null
    if (-not $NoHeader) {
        $indicator = New-WidgetHeader -Form $form -Theme $Theme -Height $HeaderHeight
        $form.Controls.Add($indicator)
        $indicator.BringToFront()
        $form.Tag.Header = $indicator
        # Stealth Mode Default: Hidden
        if ($form.Tag.StealthMode) {
            $indicator.Visible = $false
        }
    }
    
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Dock = "Fill"
    $contentPanel.BackColor = "Transparent"
    $contentPanel.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 10) 
    $form.Controls.Add($contentPanel)
    $contentPanel.BringToFront() 
    $form.Tag.ContentPanel = $contentPanel
    $form.Add_FormClosing({ 
            param($s, $e)
            global:Save-WidgetState -Form $form -CloseReason $e.CloseReason 
        })
    $form.Add_Load({
            try { 
                if (-not $ShowInTaskbar) {
                    Hide-FromAltTab -Handle $form.Handle 
                }
            }
            catch {}
        })

    # Stealth Mode Logic (Hover Detection)
    if ($indicator -and $form.Tag.StealthMode) {
        $stealthTimer = New-Object System.Windows.Forms.Timer
        $stealthTimer.Interval = 200
        $stealthTimer.Add_Tick({
            if ($form.IsDisposed -or $indicator.IsDisposed) { 
                $stealthTimer.Stop(); return 
            }
            $cursor = [System.Windows.Forms.Cursor]::Position
            $bounds = $form.Bounds
            # Add margin for easier grabbing
            $bounds.Inflate(10, 10) 
            if ($bounds.Contains($cursor)) {
                if (-not $indicator.Visible) { $indicator.Visible = $true }
            }
            else {
                # Keep visible if Menu is open or dragging
                if ($form.ContextMenuStrip.Visible -or $form.Tag.IsDragging -or $form.Tag.IsResizing) {
                    if (-not $indicator.Visible) { $indicator.Visible = $true }
                }
                elseif ($indicator.Visible) {
                    $indicator.Visible = $false
                }
            }
        }.GetNewClosure())
        $stealthTimer.Start()
        $form.Add_FormClosed({ $stealthTimer.Stop() })
    }

    if ($indicator) {
        Enable-WidgetDrag -Controls @($form, $indicator, $contentPanel) -Form $form -IndicatorPanel $indicator
        Enable-WidgetResize -Form $form -IndicatorPanel $indicator
        $form.ContextMenuStrip = New-WidgetContextMenu -Form $form -IndicatorPanel $indicator
    }
    return $form
}

function global:New-WidgetHeader {
    param(
        [System.Windows.Forms.Form]$Form,
        [hashtable]$Theme,
        [int]$Height = 24
    )
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = "Top"
    $header.Height = $Height
    $header.BackColor = if ($Theme.Indicator) { $Theme.Indicator } else { [System.Drawing.Color]::FromArgb(80, 255, 255, 255) }
    
    $closeBtn = New-Object System.Windows.Forms.Label
    $closeBtn.Text = [char]::ConvertFromUtf32(0x00D7) 
    $closeBtn.Dock = "Left"
    $closeBtn.Size = New-Object System.Drawing.Size($Height, $Height)
    $closeBtn.TextAlign = "MiddleCenter"
    $closeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $closeBtn.ForeColor = $Theme.Foreground
    $closeBtn.BackColor = "Transparent"
    $closeBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $closeBtn.Add_Click({
            $Form.Close()
        }.GetNewClosure())
    $closeBtn.Add_MouseEnter({ $this.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100) }.GetNewClosure())
    $closeBtn.Add_MouseLeave({ $this.ForeColor = $Theme.Foreground }.GetNewClosure())
    $header.Controls.Add($closeBtn)
    
    $btnPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnPanel.Dock = "Right"
    $btnPanel.AutoSize = $true
    $btnPanel.FlowDirection = "RightToLeft"
    $btnPanel.BackColor = "Transparent"
    $header.Controls.Add($btnPanel)
    
    $mkBtn = {
        param($txt, $tip)
        $b = New-Object System.Windows.Forms.Label
        $b.Text = $txt
        $b.AutoSize = $false
        $b.Size = New-Object System.Drawing.Size($Height, $Height)
        $b.TextAlign = "MiddleCenter"
        $b.ForeColor = $Theme.Foreground
        $b.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 8)
        $b.Cursor = [System.Windows.Forms.Cursors]::Hand
        return $b
    }
    
    $LOCK_LOCKED = [char]::ConvertFromUtf32(0x1F512) 
    $LOCK_UNLOCKED = [char]::ConvertFromUtf32(0x1F513) 
    $lockBtn = &$mkBtn $LOCK_UNLOCKED "Toggle Lock"
    $lockBtn.Add_Click({
            $Form.Tag.IsLocked = -not $Form.Tag.IsLocked
            $lockBtn.Text = if ($Form.Tag.IsLocked) { $LOCK_LOCKED } else { $LOCK_UNLOCKED }
            $closeBtn.Visible = -not $Form.Tag.IsLocked
            $closeBtn.Enabled = -not $Form.Tag.IsLocked
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    
    if ($Form.Tag.IsLocked) { 
        $lockBtn.Text = $LOCK_LOCKED 
        $closeBtn.Visible = $false
        $closeBtn.Enabled = $false
    }
    $btnPanel.Controls.Add($lockBtn)
    return $header
}
