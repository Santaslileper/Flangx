param([int]$X = -1, [int]$Y = -1)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$rootDir\core\window_utils.ps1"
. "$rootDir\core\desktop_icons.ps1"
. "$rootDir\core\grid_logic.ps1"
. "$rootDir\core\widget_base.ps1"
Ensure-SingleInstance -ScriptPath $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.json"
$script:currentValue = ""
$script:previousValue = ""
$script:operation = ""
$script:newNumber = $true
$theme = @{
    Background = [System.Drawing.Color]::FromArgb(30, 30, 35)
    Display    = [System.Drawing.Color]::FromArgb(25, 25, 30)
    Foreground = [System.Drawing.Color]::White
    ButtonBg   = [System.Drawing.Color]::FromArgb(50, 50, 55)
    ButtonOp   = [System.Drawing.Color]::FromArgb(70, 130, 180)
    ButtonEq   = [System.Drawing.Color]::FromArgb(100, 180, 100)
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
}
$form = New-StandardWidget -Name "Calculator" -Width 230 -Height 250 -ConfigPath $configPath -Theme $theme
if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}
$panel = $form.Tag.ContentPanel
$display = New-Object System.Windows.Forms.Label
$display.Text = "0"
$display.ForeColor = $theme.Foreground
$display.BackColor = $theme.Display
$display.Location = New-Object System.Drawing.Point(5, 5) 
$display.Size = New-Object System.Drawing.Size(200, 35) 
$display.TextAlign = "MiddleRight"
$display.Font = New-Object System.Drawing.Font("Consolas", 18, [System.Drawing.FontStyle]::Bold)
$display.Padding = New-Object System.Windows.Forms.Padding(0, 0, 5, 0)
$panel.Controls.Add($display)
$buttonDefs = @(
    @("C", "Â±", "%", "Ã·"),
    @("7", "8", "9", "Ã—"),
    @("4", "5", "6", "âˆ’"),
    @("1", "2", "3", "+"),
    @("0", "0", ".", "=")
)
$padding = 4
$gridY = 45 
$gridW = 200 
$btnWidth = 47 
$btnHeight = 32
function Update-Display {
    $val = if ($script:currentValue -eq "" -or $script:currentValue -eq "-") { "0" } else { $script:currentValue }
    if ($val.Length -gt 15) { $val = $val.Substring(0, 15) }
    $display.Text = $val
}
function Do-Calculate {
    if ($script:previousValue -eq "" -or $script:currentValue -eq "") { return }
    $a = [double]$script:previousValue
    $b = [double]$script:currentValue
    $result = 0
    switch ($script:operation) {
        "+" { $result = $a + $b }
        "âˆ’" { $result = $a - $b }
        "Ã—" { $result = $a * $b }
        "Ã·" { $result = if ($b -ne 0) { $a / $b } else { "Error" } }
    }
    if ($result -eq "Error") {
        $script:currentValue = "Error"
    } else {
        $result = [Math]::Round($result, 8)
        $script:currentValue = $result.ToString()
    }
    $script:previousValue = ""
    $script:operation = ""
    $script:newNumber = $true
    Update-Display
}
for ($row = 0; $row -lt $buttonDefs.Count; $row++) {
    $col = 0
    $prevLabel = ""
    for ($c = 0; $c -lt $buttonDefs[$row].Count; $c++) {
        $label = $buttonDefs[$row][$c]
        if ($label -eq "0" -and $prevLabel -eq "0") { continue }
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $label
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 0
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $btn.ForeColor = $theme.Foreground
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $width = $btnWidth
        if ($label -eq "0" -and $row -eq 4) { $width = ($btnWidth * 2) + $padding }
        $btn.Size = New-Object System.Drawing.Size($width, $btnHeight)
        $btn.Location = New-Object System.Drawing.Point(($padding + $col * ($btnWidth + $padding)), ($gridY + $row * ($btnHeight + $padding)))
        if ($label -match "^[0-9.]$") { $btn.BackColor = $theme.ButtonBg }
        elseif ($label -eq "=") { $btn.BackColor = $theme.ButtonEq }
        elseif ($label -match "[Ã·Ã—âˆ’+]") { $btn.BackColor = $theme.ButtonOp }
        else { $btn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65) }
        $btn.Add_Click({
            param($sender)
            $txt = $sender.Text
            switch ($txt) {
                "C" { $script:currentValue = ""; $script:previousValue = ""; $script:operation = ""; $script:newNumber = $true; Update-Display }
                "Â±" { if ($script:currentValue -ne "" -and $script:currentValue -ne "0") { $script:currentValue = if ($script:currentValue.StartsWith("-")) { $script:currentValue.Substring(1) } else { "-"+$script:currentValue }; Update-Display } }
                "%" { if ($script:currentValue -ne "") { $script:currentValue = ([double]$script:currentValue / 100).ToString(); Update-Display } }
                "=" { Do-Calculate }
                { $_ -match "[Ã·Ã—âˆ’+]" } { if ($script:currentValue -ne "") { if ($script:previousValue -ne "") { Do-Calculate }; $script:previousValue = $script:currentValue; $script:operation = $txt; $script:newNumber = $true } }
                "." { if ($script:newNumber) { $script:currentValue = "0."; $script:newNumber = $false } elseif (-not $script:currentValue.Contains(".")) { $script:currentValue += "." }; Update-Display }
                default { if ($script:newNumber) { $script:currentValue = $txt; $script:newNumber = $false } else { $script:currentValue += $txt }; Update-Display }
            }
        })
        $panel.Controls.Add($btn)
        if ($label -eq "0" -and $row -eq 4) { $col += 2 } else { $col++ }
        $prevLabel = $label
    }
}
$indicator = $form.Tag.Header
Enable-WidgetDrag -Controls @($display) -Form $form -IndicatorPanel $indicator
$display.ContextMenuStrip = $form.ContextMenuStrip
[System.Windows.Forms.Application]::Run($form)
