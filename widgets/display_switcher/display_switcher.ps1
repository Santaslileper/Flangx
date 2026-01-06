# widgets/display_switcher/display_switcher.ps1
# Display Settings Widget - Minimal Toggle Version
param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)

# Generate unique instance ID if not provided
if (-not $InstanceId) {
    $InstanceId = (Get-Date -Format "yyyyMMddHHmmssfff") + "_" + (Get-Random -Maximum 9999)
}

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFileName = "config_$InstanceId.json"
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
    Background   = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Foreground   = [System.Drawing.Color]::White
    Accent       = [System.Drawing.Color]::FromArgb(100, 200, 255)
    Indicator    = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
    ButtonBg     = [System.Drawing.Color]::FromArgb(45, 45, 52)
    ButtonHover  = [System.Drawing.Color]::FromArgb(60, 60, 70)
    ButtonActive = [System.Drawing.Color]::FromArgb(100, 200, 255)
}

# Create Mini Widget Form
$widgetName = "Display ($InstanceId)"
$form = New-StandardWidget -Name $widgetName -Width 300 -Height 100 -ConfigPath $configPath -Theme $theme

if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}

# Store InstanceId in form tag
$form.Tag = $InstanceId

# Header
$indicator = New-WidgetHeader -Form $form -Theme $theme

# Add Close Button to Header
$closeBtn = New-Object System.Windows.Forms.Label
$closeBtn.Text = "×"
$closeBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$closeBtn.ForeColor = $theme.Foreground
$closeBtn.BackColor = "Transparent"
$closeBtn.Size = New-Object System.Drawing.Size(20, 20)
$closeBtn.Location = New-Object System.Drawing.Point(($form.Width - 30), 2)
$closeBtn.TextAlign = "MiddleCenter"
$closeBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$closeBtn.Add_MouseEnter({ $this.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100) })
$closeBtn.Add_MouseLeave({ $this.ForeColor = $theme.Foreground })
$closeBtn.Add_Click({
    $form.Close()
})
$indicator.Controls.Add($closeBtn)

$form.Controls.Add($indicator)

# Main Panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(15, 10, 15, 15)
$form.Controls.Add($panel)

# Helper: Get State (per-instance)
function Get-DisplayState {
    $stateFile = Join-Path $scriptDir "display_state_$InstanceId.txt"
    if (-not (Test-Path $stateFile)) { return "extended" }
    try {
        $txt = [System.IO.File]::ReadAllText($stateFile)
        if ([string]::IsNullOrWhiteSpace($txt)) { return "extended" }
        return $txt.Trim()
    }
    catch { return "extended" }
}

# Helper: Set State (per-instance)
function Set-DisplayState {
    param($Mode)
    $stateFile = Join-Path $scriptDir "display_state_$InstanceId.txt"
    try {
        [System.IO.File]::WriteAllText($stateFile, $Mode)
    }
    catch {}
}

# The Single Toggle Button
$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.Dock = "Fill"
$btnToggle.FlatStyle = "Flat"
$btnToggle.FlatAppearance.BorderSize = 0
$btnToggle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnToggle.Cursor = [System.Windows.Forms.Cursors]::Hand
$panel.Controls.Add($btnToggle)

# Simple text icons (cross-platform compatible)
$Icon_Single = "🖥"  # PC screen
$Icon_Extend = "🖥➜🖥"  # Two screens

# Refresh UI based on state
function Update-ButtonState {
    $mode = Get-DisplayState
    
    if ($mode -eq "internal") {
        # Currently Internal (PC Only). Button shows option to switch to Extended.
        $btnToggle.Text = "$Icon_Extend  Switch to Extended"
        $btnToggle.BackColor = $theme.ButtonBg
        $btnToggle.ForeColor = $theme.Foreground
        $btnToggle.Tag = "internal"
    } 
    else {
        # Currently Extended. Button shows option to switch to PC Only.
        $btnToggle.Text = "$Icon_Single  Switch to PC Only"
        $btnToggle.BackColor = $theme.Accent
        $btnToggle.ForeColor = [System.Drawing.Color]::White
        $btnToggle.Tag = "extended"
    }
}

# Button hover effects
$btnToggle.Add_MouseEnter({
    if ($this.Tag -eq "internal") {
        $this.BackColor = $theme.ButtonHover
    }
})

$btnToggle.Add_MouseLeave({
    if ($this.Tag -eq "internal") {
        $this.BackColor = $theme.ButtonBg
    } else {
        $this.BackColor = $theme.Accent
    }
})

# Click Logic
$btnToggle.Add_Click({
    $current = $btnToggle.Tag
    
    try {
        if ($current -eq "extended") {
            # Switch to Internal (PC Only)
            Start-Process "DisplaySwitch.exe" -ArgumentList "/internal" -WindowStyle Hidden
            Set-DisplayState "internal"
        } 
        else {
            # Switch to Extended
            Start-Process "DisplaySwitch.exe" -ArgumentList "/extend" -WindowStyle Hidden
            Set-DisplayState "extended"
        }
        
        # Update UI immediately (optimistic)
        Update-ButtonState
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error switching display mode: $_", 
            "Display Switcher Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Initial State
Update-ButtonState

# Drag Support
Enable-WidgetDrag -Controls @($form, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator

# Cleanup on close
$form.Add_FormClosing({
    # Clean up resources if needed
})

[System.Windows.Forms.Application]::Run($form)