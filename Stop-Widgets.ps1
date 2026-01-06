# Stop-Widgets.ps1
# Stops all widget processes (Launcher, Clock, etc.)
# Run this to close everything cleanly.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\core\process_utils.ps1"

$count = Stop-AllWidgets -ShowOutput

if ($count -eq 0) {
    Write-Host "`nNo running widgets found." -ForegroundColor Gray
}
else {
    Write-Host "`nSuccessfully stopped $count widget processes." -ForegroundColor Green
}

Write-Host "`nPress Enter to exit..."
[void](Read-Host)
