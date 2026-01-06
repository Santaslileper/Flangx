# widgets/timer/timer.ps1
# Advanced Timer Widget

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
. "$rootDir\core\widget_utils.ps1"

# Theme
$theme = @{
    Background = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Foreground = [System.Drawing.Color]::FromArgb(240, 240, 240)
    Accent     = [System.Drawing.Color]::FromArgb(255, 140, 0) # Orange for Timer
    Dim        = [System.Drawing.Color]::FromArgb(100, 100, 100)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}

# Create Widget Form
# Default 2x1 size (Wide) for Timer to fit controls
$form = New-StandardWidget -Name "Timer" -Width 150 -Height 75 -ConfigPath $configPath -Theme $theme

# Header
$indicator = New-WidgetHeader -Form $form -Theme $theme
$form.Controls.Add($indicator)

# Inner Panel for Padding
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(5)
$form.Controls.Add($panel)

# State Variables
$script:DurationSeconds = 300 # Default 5 mins
$script:RemainingSeconds = 300
$script:IsRunning = $false
$script:TargetTime = $null

# --- UI Components ---

# Time Display (HH:mm:ss)
# Using a custom paint/label for flexibility? No, Label is fine but we want interaction.
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "05:00"
$timeLabel.ForeColor = $theme.Foreground
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Dock = "Top"
$timeLabel.Height = 50
$timeLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
$panel.Controls.Add($timeLabel)

# Controls Panel (Bottom)
$ctrlPanel = New-Object System.Windows.Forms.Panel
$ctrlPanel.Dock = "Bottom"
$ctrlPanel.Height = 25
$panel.Controls.Add($ctrlPanel)

# Start/Pause Button
$btnStart = New-Object System.Windows.Forms.Label
$btnStart.Text = "▶"
$btnStart.ForeColor = $theme.Accent
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 14)
$btnStart.TextAlign = "MiddleCenter"
$btnStart.Width = 75
$btnStart.Dock = "Left"
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$ctrlPanel.Controls.Add($btnStart)

# Reset Button
$btnReset = New-Object System.Windows.Forms.Label
$btnReset.Text = "↺"
$btnReset.ForeColor = $theme.Dim
$btnReset.Font = New-Object System.Drawing.Font("Segoe UI Symbol", 14)
$btnReset.TextAlign = "MiddleCenter"
$btnReset.Width = 75
$btnReset.Dock = "Right"
$btnReset.Cursor = [System.Windows.Forms.Cursors]::Hand
$ctrlPanel.Controls.Add($btnReset)

# Progress Overlay (Paint Event on Form)
# We draw a thin line at the bottom or a circle?
# Let's draw a progress bar at the very bottom of the time label.
$timeLabel.Add_Paint({
        param($s, $e)
        # Hint: Scroll to change
        if (-not $script:IsRunning) {
            # $e.Graphics.DrawString("Scroll to set", ... small font ...)
        }
    })

# --- Logic ---

function Format-Time($secs) {
    if ($secs -ge 3600) {
        return [TimeSpan]::FromSeconds($secs).ToString("hh\:mm\:ss")
    }
    else {
        return [TimeSpan]::FromSeconds($secs).ToString("mm\:ss")
    }
}

# Update function
function Update-TimerDisplay {
    $timeLabel.Text = Format-Time $script:RemainingSeconds
    
    # Progress indication could go here
    if ($script:IsRunning -and $script:DurationSeconds -gt 0) {
        $pct = $script:RemainingSeconds / $script:DurationSeconds
        # Maybe change color if low?
        if ($script:RemainingSeconds -lt 10) { $timeLabel.ForeColor = "Red" }
        else { $timeLabel.ForeColor = $theme.Foreground }
    }
}

# Ticker
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$timer.Add_Tick({
        if ($script:IsRunning) {
            $now = Get-Date
            $diff = $script:TargetTime - $now
            $script:RemainingSeconds = [Math]::Ceiling($diff.TotalSeconds)
        
            if ($script:RemainingSeconds -le 0) {
                $script:RemainingSeconds = 0
                $script:IsRunning = $false
                $timer.Stop()
                $btnStart.Text = "▶"
            
                # Alarm / Flash
                [System.Console]::Beep(440, 500)
                [System.Console]::Beep(550, 500)
                # Flash Color
                $form.BackColor = "Red"
                $timeLabel.ForeColor = "White"
            }
        
            Update-TimerDisplay
        }
    })

# --- Interactions ---

# Edit Time (Click)
Add-Type -AssemblyName Microsoft.VisualBasic
$timeLabel.Add_MouseClick({
        param($s, $e)
        if ($e.Button -eq 'Left') {
            if ($script:IsRunning) { return }
        
            $timeInput = [Microsoft.VisualBasic.Interaction]::InputBox("Enter duration (minutes or mm:ss):", "Set Timer", "5")
            if (-not [string]::IsNullOrWhiteSpace($timeInput)) {
                $newSecs = 0
                if ($timeInput -match "^(\d+):(\d+)$") {
                    $newSecs = ([int]$matches[1] * 60) + [int]$matches[2]
                }
                elseif ($timeInput -match "^\d+$") {
                    $newSecs = [int]$timeInput * 60
                }
            
                if ($newSecs -gt 0) {
                    $script:DurationSeconds = $newSecs
                    $script:RemainingSeconds = $script:DurationSeconds
                    Update-TimerDisplay
                }
            }
        }
    }.GetNewClosure())

# Presets Menu (Right Click on Label)
$presetsMenu = New-Object System.Windows.Forms.ContextMenuStrip
$presetTimes = @(1, 5, 10, 25, 30, 55, 60, 120)
foreach ($min in $presetTimes) {
    if ($min -eq 120) { $txt = "2 Hours" } else { $txt = "$min Minutes" }
    
    $item = $presetsMenu.Items.Add($txt)
    $item.Tag = $min
    $item.Add_Click({
            param($s, $e)
            if ($script:IsRunning) { return }
            $script:DurationSeconds = ($s.Tag * 60)
            $script:RemainingSeconds = $script:DurationSeconds
            Update-TimerDisplay
        }.GetNewClosure())
}
Apply-AppleMenuStyle -Menu $presetsMenu
$timeLabel.ContextMenuStrip = $presetsMenu

# Toggle Start/Pause
$btnStart.Add_Click({
        if ($script:RemainingSeconds -le 0) {
            # Reset if 0
            $script:RemainingSeconds = $script:DurationSeconds
        }

        $script:IsRunning = -not $script:IsRunning
    
        if ($script:IsRunning) {
            $script:TargetTime = (Get-Date).AddSeconds($script:RemainingSeconds)
            $timer.Start()
            $btnStart.Text = "⏸"
            $btnStart.ForeColor = $theme.Accent
            $timeLabel.ForeColor = $theme.Foreground
            $form.BackColor = $theme.Background
        }
        else {
            $timer.Stop()
            $btnStart.Text = "▶"
            $btnStart.ForeColor = "Green" # Resume color
        }
    }.GetNewClosure())

# Reset
$btnReset.Add_Click({
        $script:IsRunning = $false
        $timer.Stop()
        $btnStart.Text = "▶"
        $script:RemainingSeconds = $script:DurationSeconds
        Update-TimerDisplay
        $form.BackColor = $theme.Background
        $timeLabel.ForeColor = $theme.Foreground
    }.GetNewClosure())

# Scroll to Set (Mouse Wheel)
$timeLabel.Add_MouseWheel({
        param($s, $e)
        if ($script:IsRunning) { return }
    
        # Delta usually 120 per notch.
        $clicks = $e.Delta / 120
    
        # Check if shift held for larger increments?
        if ([System.Windows.Forms.Control]::ModifierKeys -eq "Shift") {
            $change = $clicks * 60 # Minutes
        }
        else {
            $change = $clicks * 10 # 10 Seconds
        }
    
        $script:DurationSeconds += $change
        if ($script:DurationSeconds -lt 10) { $script:DurationSeconds = 10 }
    
        $script:RemainingSeconds = $script:DurationSeconds
        Update-TimerDisplay
    
        # Save default?
    }.GetNewClosure())

# Ensure Timer focus for wheel events
$timeLabel.Add_MouseEnter({ $timeLabel.Focus() })

# Initial Render
Update-TimerDisplay

# Enable Drag & Context Menu
# Add resize support too!
Enable-WidgetDrag -Controls @($form, $panel, $timeLabel, $ctrlPanel, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator
$form.ContextMenuStrip = New-WidgetContextMenu -Form $form -IndicatorPanel $indicator

# Run
[System.Windows.Forms.Application]::Run($form)
