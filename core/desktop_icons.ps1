# core/desktop_icons.ps1
# Desktop icon position tracking via Win32 ListView API
# Requires: core/window_utils.ps1 to be loaded first
# The DesktopIcons C# class is now defined in window_utils.ps1

# PowerShell wrapper
function Get-DesktopIconRects {
    return [DesktopWidgets.DesktopIcons]::GetIconRects()
}
