$script:WidgetState = @{
    ConfigPath = $null
    IsLocked   = $false
    SnapToGrid = $true
    TopMost    = $false
}
function global:Save-WidgetState {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.CloseReason]$CloseReason = "None"
    )
    if ($null -eq $script:WidgetState.ConfigPath) { return }
    $isActive = $true
    if ($CloseReason -eq 'UserClosing') {
        $isActive = $false
    }
    $state = @{
        X          = $Form.Location.X
        Y          = $Form.Location.Y
        Width      = $Form.Width
        Height     = $Form.Height
        Locked     = $Form.Tag.IsLocked
        SnapToGrid = $Form.Tag.SnapToGrid
        TopMost    = $Form.Tag.TopMost
        Active     = $isActive
    }
    $dir = Split-Path -Parent $script:WidgetState.ConfigPath
    $masterConfig = Join-Path $dir "config.json"
    $state | ConvertTo-Json | Set-Content -Path $masterConfig
    $isNamed = $script:WidgetState.ConfigPath -notlike "*\config.json"
    if ($isNamed) {
        if ($CloseReason -eq 'UserClosing') {
            if (Test-Path $script:WidgetState.ConfigPath) {
                Remove-Item $script:WidgetState.ConfigPath -Force
            }
        }
        else {
            $state | ConvertTo-Json | Set-Content -Path $script:WidgetState.ConfigPath
        }
    }
    else {
    }
}
