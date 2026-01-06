param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFileName = "config.json"
if ($InstanceId) { $configFileName = "config_$InstanceId.json" }
$configPath = Join-Path $scriptDir $configFileName
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$rootDir\core\window_utils.ps1"
. "$rootDir\core\desktop_icons.ps1"
. "$rootDir\core\grid_logic.ps1"
. "$rootDir\core\widget_base.ps1"
$chromaKey = [System.Drawing.Color]::Magenta 
$theme = @{
    Background = $chromaKey
    Foreground = [System.Drawing.Color]::White
    Accent     = [System.Drawing.Color]::FromArgb(100, 200, 255)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}
$form = New-StandardWidget -Name "Clock" -Width 240 -Height 130 -ConfigPath $configPath -Theme $theme
$form.TransparencyKey = $chromaKey
if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}
$panel = $form.Tag.ContentPanel
$panel.Padding = New-Object System.Windows.Forms.Padding(0)
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = Get-Date -Format "HH:mm:ss"
$timeLabel.ForeColor = $theme.Foreground
$timeLabel.BackColor = "Transparent"
$timeLabel.AutoSize = $false
$timeLabel.TextAlign = "MiddleCenter"
$timeLabel.Dock = "Top"
$timeLabel.Height = 70 
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
$panel.Controls.Add($timeLabel)
$dateLabel = New-Object System.Windows.Forms.Label
$dateLabel.Text = Get-Date -Format "dddd, MMMM dd, yyyy"
$dateLabel.ForeColor = $theme.Accent
$dateLabel.BackColor = "Transparent"
$dateLabel.AutoSize = $false
$dateLabel.TextAlign = "TopCenter"
$dateLabel.Dock = "Fill" 
$dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
$panel.Controls.Add($dateLabel)
$resizeLogic = {
    $h = $panel.Height
    if ($h -lt 50) { return }
    $timeH = [Math]::Floor($h * 0.70)
    $dateH = $h - $timeH
    $timeLabel.Height = $timeH
    $timeFontSize = [Math]::Max(8, $timeH * 0.6)
    $dateFontSize = [Math]::Max(6, $dateH * 0.4)
    $timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", $timeFontSize, [System.Drawing.FontStyle]::Bold)
    $dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", $dateFontSize, [System.Drawing.FontStyle]::Regular)
}
$form.Add_Resize({ & $resizeLogic })
& $resizeLogic
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ 
        $timeLabel.Text = Get-Date -Format "HH:mm:ss"
        $dateLabel.Text = Get-Date -Format "dddd, MMMM dd, yyyy"
    })
$timer.Start()
$timeLabel.ContextMenuStrip = $form.ContextMenuStrip
$dateLabel.ContextMenuStrip = $form.ContextMenuStrip
[System.Windows.Forms.Application]::Run($form)
