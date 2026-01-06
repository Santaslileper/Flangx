# Start-Widgets.ps1
# Main entry point for the Desktop Widgets application
# Run this script to start the widget launcher

param(
    [switch]$Hidden
)

$scriptDir = $PSScriptRoot
# Cleanup existing widgets
. "$scriptDir\core\process_utils.ps1"  
Stop-AllWidgets -IgnorePid $PID

# Start the Launcher
$launcherPath = "$scriptDir\widgets\launcher\launcher.ps1"

if (-not (Test-Path $launcherPath)) {
    Write-Error "Launcher not found at: $launcherPath"
    exit 1
}

# If -Hidden, launch without visible window
if ($Hidden) {
    Start-Process powershell.exe -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$launcherPath`""
    )
}
else {
    # Run directly (useful for debugging)
    & $launcherPath
}
