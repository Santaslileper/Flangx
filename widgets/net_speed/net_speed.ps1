param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFileName = "config.json"
if ($InstanceId) { $configFileName = "config_$InstanceId.json" }
$configPath = Join-Path $scriptDir $configFileName
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$rootDir\core\widget_base.ps1"
$theme = @{
    Background = [System.Drawing.Color]::FromArgb(25, 25, 30)
    Foreground = [System.Drawing.Color]::White
    DownColor  = [System.Drawing.Color]::FromArgb(0, 200, 255) 
    UpColor    = [System.Drawing.Color]::FromArgb(255, 100, 200) 
    GraphBg    = [System.Drawing.Color]::FromArgb(40, 40, 45)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}
$form = New-StandardWidget -Name "Net Speed" -Width 240 -Height 160 -ConfigPath $configPath -Theme $theme
$indicator = $form.Tag.Header
# $form.Controls.Add($indicator)
$panel = $form.Tag.ContentPanel
# $panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(10)
# $form.Controls.Add($panel)
$lblDown = New-Object System.Windows.Forms.Label
$lblDown.Text = "â¬‡ 0 KB/s"
$lblDown.ForeColor = $theme.DownColor
$lblDown.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$lblDown.AutoSize = $true
$lblDown.Location = New-Object System.Drawing.Point(10, 5)
$panel.Controls.Add($lblDown)
$lblUp = New-Object System.Windows.Forms.Label
$lblUp.Text = "â¬† 0 KB/s"
$lblUp.ForeColor = $theme.UpColor
$lblUp.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$lblUp.AutoSize = $true
$lblUp.Location = New-Object System.Drawing.Point(120, 5)
$panel.Controls.Add($lblUp)
$canvas = New-Object System.Windows.Forms.PictureBox
$canvas.Location = New-Object System.Drawing.Point(10, 35)
$canvas.Size = New-Object System.Drawing.Size(220, 80)
$canvas.BackColor = $theme.GraphBg
$canvas.BorderStyle = "None"
$panel.Controls.Add($canvas)
$lblTotal = New-Object System.Windows.Forms.Label
$lblTotal.Text = "Usage: Calculating..."
$lblTotal.ForeColor = [System.Drawing.Color]::Gray
$lblTotal.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblTotal.AutoSize = $true
$lblTotal.Location = New-Object System.Drawing.Point(10, 125)
$panel.Controls.Add($lblTotal)
$script:historyDown = New-Object System.Collections.Generic.List[int]
$script:historyUp = New-Object System.Collections.Generic.List[int]
$maxPoints = 50
for($i=0; $i -lt $maxPoints; $i++) { $script:historyDown.Add(0); $script:historyUp.Add(0) }
$script:prevBytesRecv = 0
$script:prevBytesSent = 0
$script:firstRun = $true
function Get-FriendlySize($bytes) {
    if ($bytes -ge 1GB) { return "{0:N1} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N1} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N0} KB" -f ($bytes / 1KB) }
    return "$bytes B"
}
function Update-Network {
    try {
        $stats = Get-NetAdapterStatistics -ErrorAction SilentlyContinue | Measure-Object -Property ReceivedBytes, SentBytes -Sum
        if ($stats.Count -eq 0) { return }
        $currRecv = $stats.Sum[0].Sum
        $currSent = $stats.Sum[1].Sum 
        if ($script:firstRun) {
            $script:prevBytesRecv = $currRecv
            $script:prevBytesSent = $currSent
            $script:firstRun = $false
            return
        }
        $diffRecv = $currRecv - $script:prevBytesRecv
        $diffSent = $currSent - $script:prevBytesSent
        if ($diffRecv -lt 0) { $diffRecv = 0 }
        if ($diffSent -lt 0) { $diffSent = 0 }
        $script:prevBytesRecv = $currRecv
        $script:prevBytesSent = $currSent
        $lblDown.Text = "â¬‡ $(Get-FriendlySize $diffRecv)/s"
        $lblUp.Text = "â¬† $(Get-FriendlySize $diffSent)/s"
        $script:historyDown.Add($diffRecv)
        $script:historyDown.RemoveAt(0)
        $script:historyUp.Add($diffSent)
        $script:historyUp.RemoveAt(0)
        $lblTotal.Text = "Total Session: â¬‡ $(Get-FriendlySize ($currRecv - $script:prevBytesRecvSession))"
        $canvas.Invalidate()
    }
    catch {}
}
$statsStart = Get-NetAdapterStatistics -ErrorAction SilentlyContinue | Measure-Object -Property ReceivedBytes, SentBytes -Sum
$script:prevBytesRecvSession = if($statsStart) { $statsStart.Sum[0].Sum } else { 0 }
$canvas.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = "AntiAlias"
    $w = $canvas.Width
    $h = $canvas.Height
    $maxVal = ($script:historyDown | Measure-Object -Maximum).Maximum
    $maxUp = ($script:historyUp | Measure-Object -Maximum).Maximum
    if ($maxUp -gt $maxVal) { $maxVal = $maxUp }
    if ($maxVal -lt 1024) { $maxVal = 1024 } 
    $ptsDown = @()
    for ($i=0; $i -lt $maxPoints; $i++) {
        $x = ($i / ($maxPoints - 1)) * $w
        $val = $script:historyDown[$i]
        $y = $h - (($val / $maxVal) * $h)
        $ptsDown += New-Object System.Drawing.PointF($x, $y)
    }
    $ptsUp = @()
    for ($i=0; $i -lt $maxPoints; $i++) {
        $x = ($i / ($maxPoints - 1)) * $w
        $val = $script:historyUp[$i]
        $y = $h - (($val / $maxVal) * $h)
        $ptsUp += New-Object System.Drawing.PointF($x, $y)
    }
    if ($ptsDown.Count -gt 1) { 
        $g.DrawLines((New-Object System.Drawing.Pen($theme.DownColor, 2)), $ptsDown) 
    }
    if ($ptsUp.Count -gt 1) { 
        $g.DrawLines((New-Object System.Drawing.Pen($theme.UpColor, 1)), $ptsUp) 
    }
})
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Update-Network })
$timer.Start()
Enable-WidgetDrag -Controls @($form, $panel, $lblDown, $lblUp, $lblTotal, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator
$form.ContextMenuStrip = New-WidgetContextMenu -Form $form -IndicatorPanel $indicator
[System.Windows.Forms.Application]::Run($form)
