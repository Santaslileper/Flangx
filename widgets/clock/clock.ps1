# widgets/clock/clock.ps1
# Digital Clock Widget

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
    Foreground = [System.Drawing.Color]::White
    Accent     = [System.Drawing.Color]::FromArgb(100, 200, 255)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}

# Create Standard Widget Form
# Width 240, Height 110 (Increased slightly for header)
$form = New-StandardWidget -Name "Clock" -Width 240 -Height 110 -ConfigPath $configPath -Theme $theme

# Override Manual Position if passed
if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}

# --- Widget Specific UI ---
# Standard Factory handles Background, Rounded Corners, Border, Header.

$panel = $form.Tag.ContentPanel
# Content Panel already has padding (10,5,10,10)

# Time Label
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = Get-Date -Format "HH:mm:ss"
$timeLabel.ForeColor = $theme.Foreground
$timeLabel.BackColor = "Transparent"
$timeLabel.AutoSize = $false
$timeLabel.Width = 220
$timeLabel.Height = 45
$timeLabel.Left = 0
$timeLabel.Top = 5
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
$panel.Controls.Add($timeLabel)

# Date Label
$dateLabel = New-Object System.Windows.Forms.Label
$dateLabel.Text = Get-Date -Format "dddd, MMMM dd, yyyy"
$dateLabel.ForeColor = $theme.Accent
$dateLabel.BackColor = "Transparent"
$dateLabel.AutoSize = $false
$dateLabel.Width = 220
$dateLabel.Height = 25
$dateLabel.Left = 0
$dateLabel.Top = 50
$dateLabel.TextAlign = "MiddleCenter"
$dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$panel.Controls.Add($dateLabel)

# Update Timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ 
        $timeLabel.Text = Get-Date -Format "HH:mm:ss"
        $dateLabel.Text = Get-Date -Format "dddd, MMMM dd, yyyy"
    })
$timer.Start()

# Enable Drag for specific labels
$indicator = $form.Tag.Header
Enable-WidgetDrag -Controls @($timeLabel, $dateLabel) -Form $form -IndicatorPanel $indicator
$timeLabel.ContextMenuStrip = $form.ContextMenuStrip
$dateLabel.ContextMenuStrip = $form.ContextMenuStrip

# Run
[System.Windows.Forms.Application]::Run($form)