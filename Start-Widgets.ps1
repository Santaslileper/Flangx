param(
    [switch]$Hidden
)

$scriptDir = $PSScriptRoot

# Load App Config
if (Test-Path "$scriptDir\core\app_config.ps1") {
    . "$scriptDir\core\app_config.ps1"
}

# Auto-Hide Console Logic based on Config
if (-not $Hidden -and $global:AppConfig -and -not $global:AppConfig.EnableConsole) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptDir\Start-Widgets.ps1`" -Hidden"
    exit
}

# Cleanup existing widgets
if (Test-Path "$scriptDir\core\process_utils.ps1") {
    . "$scriptDir\core\process_utils.ps1"  
    Stop-AllWidgets -IgnorePid $PID
}

# Start the Launcher
$launcherPath = "$scriptDir\widgets\launcher\launcher.ps1"

if (-not (Test-Path $launcherPath)) {
    Write-Error "Launcher not found at: $launcherPath"
    exit 1
}

# Launch mechanism
if ($Hidden) {
    Start-Process powershell.exe -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$launcherPath`""
    )
}
else {
    # Run in current console (Visible)
    & $launcherPath
}
