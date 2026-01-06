param(
    [switch]$Hidden
)
$scriptDir = $PSScriptRoot
. "$scriptDir\core\process_utils.ps1"  
Stop-AllWidgets -IgnorePid $PID
$launcherPath = "$scriptDir\widgets\launcher\launcher.ps1"
if (-not (Test-Path $launcherPath)) {
    Write-Error "Launcher not found at: $launcherPath"
    exit 1
}
if ($Hidden) {
    Start-Process powershell.exe -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$launcherPath`""
    )
}
else {
    & $launcherPath
}
