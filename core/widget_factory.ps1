function global:New-StandardWidget {
    param(
        [string]$Name,
        [int]$Width = 80,
        [int]$Height = 80,
        [string]$ConfigPath,
        [hashtable]$Theme,
        [bool]$ShowInTaskbar = $false,
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
        $radius = 20
        $d = $radius * 2
        $rect = $form.ClientRectangle
        if ($rect.Width -le $d -or $rect.Height -le $d) { return }
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
        $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
        $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        $form.Invalidate() 
    }.GetNewClosure()
    $form.Add_Load($updateRegion)
    $form.Add_Resize($updateRegion)
    $form.Add_Paint({
        param($s, $e)
    })
    $indicator = $null
    if (-not $NoHeader) {
        $indicator = New-WidgetHeader -Form $form -Theme $Theme -Height $HeaderHeight
        $form.Controls.Add($indicator)
        $indicator.BringToFront()
        $form.Tag.Header = $indicator
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
