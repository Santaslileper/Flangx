$EnableLogging = $false
function Write-WidgetLog {
    param(
        [string]$Message,
        [string]$File = "debug.log"
    )
    if ($global:EnableLogging) {
        $logPath = Join-Path (Split-Path -Parent $MyInvocation.PSCommandPath) $File
        $Message | Out-File $logPath -Append -ErrorAction SilentlyContinue
    }
}
