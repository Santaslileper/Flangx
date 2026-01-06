$configPath = ".\widgets\launcher\config.json"
if (Test-Path $configPath) {
    Write-Host "Deleting config file to reset position..." -ForegroundColor Yellow
    Remove-Item $configPath -Force
    Write-Host "Config deleted. Restart the widgets to see them centered." -ForegroundColor Green
}
else {
    Write-Host "No config file found - widgets should already be centered." -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Now stopping any running widget processes..." -ForegroundColor Yellow
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
    if ($cmdLine -like "*widgets*" -or $cmdLine -like "*launcher.ps1*") {
        Write-Host "Stopping process $($_.Id)..." -ForegroundColor Yellow
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
}
Write-Host ""
Write-Host "Done! Now run Start-Widgets.ps1 to launch with centered position." -ForegroundColor Green
