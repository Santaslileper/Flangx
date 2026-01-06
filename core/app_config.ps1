# core/app_config.ps1
# centralized configuration for Desktop Widgets

$global:AppConfig = @{
    # UI Visibility
    ShowInTaskbar   = $false    # If false, hides from Taskbar and attempts to hide from Alt-Tab
    
    # Debugging
    EnableLogging   = $false    # Enable debug logs to disk/console
    
    # Runtime
    EnableConsole   = $false    # If false, launcher/widgets try to run hidden (no console window)
}
