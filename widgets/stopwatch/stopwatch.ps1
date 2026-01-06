# widgets/stopwatch/stopwatch.ps1
# Stopwatch Widget

param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFileName = "config.json"
if ($InstanceId) { $configFileName = "config_$InstanceId.json" }
$configPath = Join-Path $scriptDir $configFileName

# Load Core
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$rootDir\core\window_utils.ps1"
. "$rootDir\core\desktop_icons.ps1"
. "$rootDir\core\grid_logic.ps1"
. "$rootDir\core\widget_base.ps1"

# Theme
$theme = @{
    Background = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Foreground = [System.Drawing.Color]::FromArgb(240, 240, 240)
    Accent     = [System.Drawing.Color]::FromArgb(0, 190, 255) # Blue for Stopwatch
    Dim        = [System.Drawing.Color]::FromArgb(100, 100, 100)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}

# Create Widget Form
# Width 250, Height 120
$form = New-StandardWidget -Name "Stopwatch" -Width 250 -Height 120 -ConfigPath $configPath -Theme $theme

if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}

# Header
$indicator = New-WidgetHeader -Form $form -Theme $theme
$form.Controls.Add($indicator)

# Padding Panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(10)
$form.Controls.Add($panel)

# Time Display
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "00:00.00"
$timeLabel.ForeColor = $theme.Foreground
$timeLabel.Font = New-Object System.Drawing.Font("Consolas", 32, [System.Drawing.FontStyle]::Bold)
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Dock = "Top"
$timeLabel.Height = 60
$panel.Controls.Add($timeLabel)

# Controls
$ctrlPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$ctrlPanel.Dock = "Bottom"
$ctrlPanel.Height = 40
$ctrlPanel.FlowDirection = "LeftToRight"
$ctrlPanel.WrapContents = $false
$ctrlPanel.AutoSize = $false
$ctrlPanel.Padding = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
$panel.Controls.Add($ctrlPanel)

# Helper for Buttons
$mkBtn = {
    param($text, $col)
    $b = New-Object System.Windows.Forms.Label
    $b.Text = $text
    $b.ForeColor = $col
    $b.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 16)
    $b.AutoSize = $true
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 20, 0)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $b
}

# Icons
$ICON_PLAY  = [char]0x25B6 # ▶
$ICON_PAUSE = [char]0x23F8 # ⏸ (or II) usually 23F8
$ICON_RESET = [char]0x21BB # ↻
$ICON_LAP   = [char]0x23F1 # ⏱

$btnStart = &$mkBtn $ICON_PLAY $theme.Accent
$btnReset = &$mkBtn $ICON_RESET $theme.Dim
$btnLap   = &$mkBtn $ICON_LAP $theme.Dim

$ctrlPanel.Controls.Add($btnStart)
$ctrlPanel.Controls.Add($btnLap)
$ctrlPanel.Controls.Add($btnReset)

# Logic
$script:startTime = $null
$script:accumulated = [TimeSpan]::Zero
$script:isRunning = $false
$script:stopwatch = New-Object System.Diagnostics.Stopwatch

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30 # ~30fps
$timer.Add_Tick({
    if ($script:isRunning) {
        $ts = $script:stopwatch.Elapsed
        $timeLabel.Text = $ts.ToString("mm\:ss\.ff")
    }
})

$btnStart.Add_Click({
    if ($script:isRunning) {
        # Pause
        $script:stopwatch.Stop()
        $script:isRunning = $false
        $btnStart.Text = $ICON_PLAY
        $btnStart.ForeColor = "Green"
    } else {
        # Start
        $script:stopwatch.Start()
        $script:isRunning = $true
        $timer.Start()
        $btnStart.Text = $ICON_PAUSE
        $btnStart.ForeColor = $theme.Accent
    }
})

$btnReset.Add_Click({
    $script:stopwatch.Reset()
    $script:isRunning = $false
    $timer.Stop()
    $timeLabel.Text = "00:00.00"
    $btnStart.Text = $ICON_PLAY
    $btnStart.ForeColor = $theme.Accent
})

# Interactions
Enable-WidgetDrag -Controls @($form, $panel, $timeLabel, $ctrlPanel, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator
$form.ContextMenuStrip = New-WidgetContextMenu -Form $form -IndicatorPanel $indicator

[System.Windows.Forms.Application]::Run($form)
