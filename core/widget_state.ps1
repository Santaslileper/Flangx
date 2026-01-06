# State management

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
    
    # 1. Capture State
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
    
    # 2. Always update the MASTER record (config.json)
    # This satisfies "keep 1 on record at all times with past size/pos"
    $dir = Split-Path -Parent $script:WidgetState.ConfigPath
    $masterConfig = Join-Path $dir "config.json"
    
    # If master config exists, we might want to preserve other fields if any? 
    # But currently we overwrite. 
    # If we are overwriting, we must ensure we don't accidentally mark it inactive if we are just moving it.
    # Wait! If I move the widget, Save-WidgetState is called with reason "None".
    # So isActive will be $true. Correct.
    # If I close it, reason "UserClosing", isActive = $false. Correct.
    
    $state | ConvertTo-Json | Set-Content -Path $masterConfig
    
    # 3. Handle Instance Config
    $isNamed = $script:WidgetState.ConfigPath -notlike "*\config.json"
    
    if ($isNamed) {
        if ($CloseReason -eq 'UserClosing') {
            # "Gone from record" - User explicitly closed it
            if (Test-Path $script:WidgetState.ConfigPath) {
                Remove-Item $script:WidgetState.ConfigPath -Force
            }
        }
        else {
            # Shutdown/Restart - Save instance state for restoration
            $state | ConvertTo-Json | Set-Content -Path $script:WidgetState.ConfigPath
        }
    }
    else {
        # It's the default config, we already saved it above.
    }
}
