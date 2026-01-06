# widgets/temp_monitor/temp_monitor.ps1
# System Temperature & Load Monitor
# NOTE: Temperature readings require driver support and often Elevation.

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
    Background = [System.Drawing.Color]::FromArgb(20, 20, 25)
    Foreground = [System.Drawing.Color]::White
    Hot        = [System.Drawing.Color]::FromArgb(255, 80, 80)
    Cool       = [System.Drawing.Color]::FromArgb(80, 180, 255)
    Warn       = [System.Drawing.Color]::FromArgb(255, 200, 50)
    BarBg      = [System.Drawing.Color]::FromArgb(40, 40, 45)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}

$form = New-StandardWidget -Name "Temp Monitor" -Width 200 -Height 180 -ConfigPath $configPath -Theme $theme

# Header
$indicator = New-WidgetHeader -Form $form -Theme $theme
$form.Controls.Add($indicator)

$panel = New-Object System.Windows.Forms.Panel
$panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(10)
$form.Controls.Add($panel)


# Components Helper
function Add-Section {
    param($parent, $title, $y)
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $title
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::Gray
    $lbl.Location = New-Object System.Drawing.Point(10, $y)
    $lbl.AutoSize = $true
    $parent.Controls.Add($lbl)
    
    return $lbl
}

# CPU GUI
Add-Section $panel "CPU" 5
$lblCpuTemp = New-Object System.Windows.Forms.Label
$lblCpuTemp.Text = "--°C"
$lblCpuTemp.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblCpuTemp.ForeColor = $theme.Foreground
$lblCpuTemp.Location = New-Object System.Drawing.Point(10, 25)
$lblCpuTemp.AutoSize = $true
$panel.Controls.Add($lblCpuTemp)

$lblCpuLoad = New-Object System.Windows.Forms.Label
$lblCpuLoad.Text = "Load: --%"
$lblCpuLoad.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblCpuLoad.ForeColor = $theme.Foreground
$lblCpuLoad.Location = New-Object System.Drawing.Point(100, 30)
$lblCpuLoad.AutoSize = $true
$panel.Controls.Add($lblCpuLoad)

# GPU GUI
Add-Section $panel "GPU" 65
$lblGpuTemp = New-Object System.Windows.Forms.Label
$lblGpuTemp.Text = "--°C"
$lblGpuTemp.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblGpuTemp.ForeColor = $theme.Foreground
$lblGpuTemp.Location = New-Object System.Drawing.Point(10, 85)
$lblGpuTemp.AutoSize = $true
$panel.Controls.Add($lblGpuTemp)

$lblFan = New-Object System.Windows.Forms.Label
$lblFan.Text = "Fan: N/A"
$lblFan.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblFan.ForeColor = [System.Drawing.Color]::Gray
$lblFan.Location = New-Object System.Drawing.Point(100, 90)
$lblFan.AutoSize = $true
$panel.Controls.Add($lblFan)

# Info/Warning
$lblMsg = New-Object System.Windows.Forms.Label
$lblMsg.Text = "Monitoring..."
$lblMsg.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblMsg.ForeColor = [System.Drawing.Color]::Gray
$lblMsg.Location = New-Object System.Drawing.Point(10, 130)
$lblMsg.AutoSize = $true
$panel.Controls.Add($lblMsg)

# Logic
function Update-Temps {
    # 1. CPU Load (Easy)
    try {
        $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
        $load = [math]::Round($cpu.Average)
        $lblCpuLoad.Text = "Load: $load%"
        
        # Colorize load
        if ($load -gt 80) { $lblCpuLoad.ForeColor = $theme.Hot }
        else { $lblCpuLoad.ForeColor = $theme.Foreground }
    } catch {}

    # 2. Temps (Hard - MSAcpi_ThermalZoneTemperature is usually in Kelvin x 10)
    # 273.15 K = 0 C.   (Temp - 2732) / 10
    
    $foundCpuTemp = $false
    try {
        $tZones = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($tZones) {
             # Take max temp found as CPU approximation
             $maxT = 0
             foreach ($z in $tZones) {
                 $k = $z.CurrentTemperature
                 if ($k -gt $maxT) { $maxT = $k }
             }
             if ($maxT -gt 2732) {
                 $c = ($maxT - 2732) / 10
                 $lblCpuTemp.Text = "$([math]::Round($c))°C"
                 $foundCpuTemp = $true
                 
                 if ($c -gt 80) { $lblCpuTemp.ForeColor = $theme.Hot; $lblMsg.Text = "High Temp Warning!" }
                 else { $lblCpuTemp.ForeColor = $theme.Cool; $lblMsg.Text = "Normal" }
             }
        }
    } catch {}
    
    if (-not $foundCpuTemp) {
        $lblCpuTemp.Text = "N/A"
        $lblMsg.Text = "Drivers required"
    }

    # 3. GPU (Only works if Nvidia/AMD drivers expose WMI or via special tools, usually standard WMI doesn't show GPU temp easily)
    # Placeholder for now unless we find a specific provider.
    $lblGpuTemp.Text = "N/A" 
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ Update-Temps })
$timer.Start()

Enable-WidgetDrag -Controls @($form, $panel, $lblCpuTemp, $lblCpuLoad, $lblGpuTemp, $lblFan, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator
$form.ContextMenuStrip = New-WidgetContextMenu -Form $form -IndicatorPanel $indicator

[System.Windows.Forms.Application]::Run($form)
