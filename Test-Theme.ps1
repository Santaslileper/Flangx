
try {
    . "$PSScriptRoot\core\theme_utils.ps1"
    Write-Host "Theme Utils Loaded Successfully"
    $r = New-Object DesktopWidgets.AppleMenuRenderer
    Write-Host "Renderer created: $($r.GetType().Name)"
}
catch {
    Write-Error $_
    Write-Error $_.ScriptStackTrace
}
