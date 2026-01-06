$EnableLogging = $global:AppConfig.EnableLogging

function Write-WidgetLog {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $EnableLogging) { return }
    
    $logDir = Join-Path $PSScriptRoot "..\logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    # Console output if enabled
    if ($global:AppConfig.EnableConsole) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            default { "Cyan" }
        }
        Write-Host $logLine -ForegroundColor $color
    }
    
    # File output
    $logFile = Join-Path $logDir "widget_debug.log"
    $logLine | Out-File $logFile -Append -Encoding UTF8
}
