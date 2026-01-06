param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)
if (-not $InstanceId) {
    $InstanceId = (Get-Date -Format "yyyyMMddHHmmssfff") + "_" + (Get-Random -Maximum 9999)
}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFileName = "config_$InstanceId.json"
$configPath = Join-Path $scriptDir $configFileName
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$rootDir\core\window_utils.ps1"
. "$rootDir\core\desktop_icons.ps1"
. "$rootDir\core\grid_logic.ps1"
. "$rootDir\core\widget_base.ps1"
$theme = @{
    Background   = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Foreground   = [System.Drawing.Color]::White
    Accent       = [System.Drawing.Color]::FromArgb(100, 200, 255)
    Indicator    = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
    ButtonBg     = [System.Drawing.Color]::FromArgb(45, 45, 52)
    ButtonHover  = [System.Drawing.Color]::FromArgb(60, 60, 70)
    ButtonActive = [System.Drawing.Color]::FromArgb(100, 200, 255)
}
$widgetName = "Display ($InstanceId)"
$form = New-StandardWidget -Name $widgetName -Width 300 -Height 100 -ConfigPath $configPath -Theme $theme
if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}
$form.Tag = $InstanceId
$indicator = $form.Tag.Header
$closeBtn = New-Object System.Windows.Forms.Label
$closeBtn.Text = "Ã—"
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
# $form.Controls.Add($indicator)
$panel = $form.Tag.ContentPanel
# $panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.Padding = New-Object System.Windows.Forms.Padding(15, 10, 15, 15)
# $form.Controls.Add($panel)
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
function Set-DisplayState {
    param($Mode)
    $stateFile = Join-Path $scriptDir "display_state_$InstanceId.txt"
    try {
        [System.IO.File]::WriteAllText($stateFile, $Mode)
    }
    catch {}
}
$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.Dock = "Fill"
$btnToggle.FlatStyle = "Flat"
$btnToggle.FlatAppearance.BorderSize = 0
$btnToggle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnToggle.Cursor = [System.Windows.Forms.Cursors]::Hand
$panel.Controls.Add($btnToggle)
$Icon_Single = "ðŸ–¥"  
$Icon_Extend = "ðŸ–¥âžœðŸ–¥"  
function Update-ButtonState {
    $mode = Get-DisplayState
    if ($mode -eq "internal") {
        $btnToggle.Text = "$Icon_Extend  Switch to Extended"
        $btnToggle.BackColor = $theme.ButtonBg
        $btnToggle.ForeColor = $theme.Foreground
        $btnToggle.Tag = "internal"
    } 
    else {
        $btnToggle.Text = "$Icon_Single  Switch to PC Only"
        $btnToggle.BackColor = $theme.Accent
        $btnToggle.ForeColor = [System.Drawing.Color]::White
        $btnToggle.Tag = "extended"
    }
}
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
$btnToggle.Add_Click({
    $current = $btnToggle.Tag
    try {
        if ($current -eq "extended") {
            Start-Process "DisplaySwitch.exe" -ArgumentList "/internal" -WindowStyle Hidden
            Set-DisplayState "internal"
        } 
        else {
            Start-Process "DisplaySwitch.exe" -ArgumentList "/extend" -WindowStyle Hidden
            Set-DisplayState "extended"
        }
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
Update-ButtonState
Enable-WidgetDrag -Controls @($form, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator
$form.Add_FormClosing({
})
[System.Windows.Forms.Application]::Run($form)
