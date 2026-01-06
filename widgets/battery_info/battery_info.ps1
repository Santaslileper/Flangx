# widgets/battery_info/battery_info.ps1
# Battery Status Widget

param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)

# Setup
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFileName = "config.json"
if ($InstanceId) { $configFileName = "config_$InstanceId.json" }
$configPath = Join-Path $scriptDir $configFileName

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$rootDir\core\widget_base.ps1"

# Theme
$theme = @{
    Background = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Foreground = [System.Drawing.Color]::White
    Accent     = [System.Drawing.Color]::FromArgb(0, 200, 100) # Green
    Alert      = [System.Drawing.Color]::FromArgb(255, 60, 60)
    Dim        = [System.Drawing.Color]::FromArgb(150, 150, 150)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}

$form = New-StandardWidget -Name "Battery Info" -Width 220 -Height 150 -ConfigPath $configPath -Theme $theme

# Header
$indicator = New-WidgetHeader -Form $form -Theme $theme
$form.Controls.Add($indicator)

# Content Panel
$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(15, 10, 15, 10)
$form.Controls.Add($panel)

# UI Elements
$iconLabel = New-Object System.Windows.Forms.Label
$iconLabel.Text = [char]::ConvertFromUtf32(0x1F50B) # Battery
$iconLabel.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 28)
$iconLabel.ForeColor = $theme.Accent
$iconLabel.AutoSize = $true
$iconLabel.Location = New-Object System.Drawing.Point(10, 5)
$panel.Controls.Add($iconLabel)

$pctLabel = New-Object System.Windows.Forms.Label
$pctLabel.Text = "--%"
$pctLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$pctLabel.ForeColor = $theme.Foreground
$pctLabel.AutoSize = $true
$pctLabel.Location = New-Object System.Drawing.Point(65, 5)
$panel.Controls.Add($pctLabel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Scanning..."
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$statusLabel.ForeColor = $theme.Dim
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(15, 60)
$panel.Controls.Add($statusLabel)

$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = ""
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$timeLabel.ForeColor = $theme.Dim
$timeLabel.AutoSize = $true
$timeLabel.Location = New-Object System.Drawing.Point(15, 80)
$panel.Controls.Add($timeLabel)

# Logic
function Update-BatteryInfo {
    try {
        $batt = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($null -eq $batt) {
            $pctLabel.Text = "N/A"
            $statusLabel.Text = "No Battery Found"
            $iconLabel.Text = [char]::ConvertFromUtf32(0x1F50C) # Plug
            return
        }
        
        # Percentage
        $pct = $batt.EstimatedChargeRemaining
        $pctLabel.Text = "$pct%"
        
        # Color
        if ($pct -le 20) { 
            $pctLabel.ForeColor = $theme.Alert
            $iconLabel.Text = [char]::ConvertFromUtf32(0x26A0) # Warning
        }
        else { 
            $pctLabel.ForeColor = $theme.Foreground
            $iconLabel.Text = [char]::ConvertFromUtf32(0x1F50B) # Battery
        }
        
        # Status
        $statusMap = @{ 1 = "Discharging"; 2 = "AC Power"; 3 = "Fully Charged"; 4 = "Low"; 5 = "Critical"; 6 = "Charging"; 7 = "Charging"; 8 = "Charging"; 9 = "Charging"; 10 = "Undefined"; 11 = "Partially Charged" }
        $stTxt = $statusMap[[int]$batt.BatteryStatus]
        if (-not $stTxt) { $stTxt = "Status: $($batt.BatteryStatus)" }
        $statusLabel.Text = $stTxt
        
        # Time Remaining
        if ($batt.BatteryStatus -eq 1 -and $batt.EstimatedRunTime -gt 0) {
            $mins = $batt.EstimatedRunTime
            $timeLabel.Text = "$([math]::Floor($mins / 60))h $(($mins % 60))m remaining"
        }
        elseif ($batt.BatteryStatus -eq 2 -or $batt.BatteryStatus -ge 6) {
            $timeLabel.Text = "On AC Power"
        }
        else {
            $timeLabel.Text = ""
        }
    }
    catch {
        $statusLabel.Text = "Error reading battery"
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({ Update-BatteryInfo })
$timer.Start()

# Initial Update
Update-BatteryInfo

# Interaction
Enable-WidgetDrag -Controls @($form, $panel, $iconLabel, $pctLabel, $statusLabel, $timeLabel, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator
$form.ContextMenuStrip = New-WidgetContextMenu -Form $form -IndicatorPanel $indicator

[System.Windows.Forms.Application]::Run($form)
