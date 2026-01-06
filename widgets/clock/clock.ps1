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

# Theme - Transparent Setup
# We use a specific "Chroma Key" color for transparency to make the background invisible.
$chromaKey = [System.Drawing.Color]::Magenta 
$theme = @{
    Background = $chromaKey
    Foreground = [System.Drawing.Color]::White
    Accent     = [System.Drawing.Color]::FromArgb(100, 200, 255)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}

# Create Standard Widget Form with No Header
$form = New-StandardWidget -Name "Clock" -Width 240 -Height 100 -ConfigPath $configPath -Theme $theme -NoHeader $true

# Apply Transparency
$form.TransparencyKey = $chromaKey

# Override Manual Position if passed
if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}

# --- Widget Specific UI ---

$panel = $form.Tag.ContentPanel
# Remove padding to allow text to hit edges
$panel.Padding = New-Object System.Windows.Forms.Padding(0)

# Time Label
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = Get-Date -Format "HH:mm:ss"
$timeLabel.ForeColor = $theme.Foreground
$timeLabel.BackColor = "Transparent"
$timeLabel.AutoSize = $false
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Dock = "Top"
$timeLabel.Height = 70 # Initial split
# Use a Font that scales well
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
$panel.Controls.Add($timeLabel)

# Date Label
$dateLabel = New-Object System.Windows.Forms.Label
$dateLabel.Text = Get-Date -Format "dddd, MMMM dd, yyyy"
$dateLabel.ForeColor = $theme.Accent
$dateLabel.BackColor = "Transparent"
$dateLabel.AutoSize = $false
$dateLabel.TextAlign = "TopCenter"
$dateLabel.Dock = "Fill" 
$dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
$panel.Controls.Add($dateLabel)

# Dynamic Resizing Logic
$resizeLogic = {
    $h = $panel.Height
    
    # Check if too small
    if ($h -lt 50) { return }

    # Ratios
    $timeH = [Math]::Floor($h * 0.70)
    $dateH = $h - $timeH
    
    $timeLabel.Height = $timeH
    
    # Scale Fonts
    # Time font ~ 50% of its container height
    $timeFontSize = [Math]::Max(8, $timeH * 0.6)
    $dateFontSize = [Math]::Max(6, $dateH * 0.4)
    
    $timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", $timeFontSize, [System.Drawing.FontStyle]::Bold)
    $dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", $dateFontSize, [System.Drawing.FontStyle]::Regular)
}

$form.Add_Resize({ & $resizeLogic })
# Initial Call
& $resizeLogic

# Update Timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ 
        $timeLabel.Text = Get-Date -Format "HH:mm:ss"
        $dateLabel.Text = Get-Date -Format "dddd, MMMM dd, yyyy"
    })
$timer.Start()

# Enable Drag for Labels (since no header)
# We use the Form as the "Indicator" argument so drag triggers correctly
Enable-WidgetDrag -Controls @($timeLabel, $dateLabel, $panel, $form) -Form $form
Enable-WidgetResize -Form $form -IndicatorPanel $null # Resize without indicator color change

$timeLabel.ContextMenuStrip = $form.ContextMenuStrip
$dateLabel.ContextMenuStrip = $form.ContextMenuStrip

# Run
[System.Windows.Forms.Application]::Run($form)