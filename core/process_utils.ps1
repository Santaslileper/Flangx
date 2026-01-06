function global:Stop-AllWidgets {
    [CmdletBinding()]
    param(
        [switch]$ShowOutput,
        [int]$IgnorePid
    )
    $currentPid = $PID
    if ($IgnorePid) { $currentPid = $IgnorePid }
    $count = 0
    if ($ShowOutput) { Write-Host "Searching for running widgets..." -ForegroundColor Cyan }
    try {
        $procs = Get-Process -Name powershell -ErrorAction SilentlyContinue 
    }
    catch { return 0 }
    foreach ($p in $procs) {
        if ($p.Id -eq $currentPid) { continue }
        $isWidget = $false
        $info = "Unknown"
        if ($p.MainWindowTitle -like "DesktopWidget_*") {
            $isWidget = $true
            $info = $p.MainWindowTitle
        }
        if (-not $isWidget) {
            try {
                $cimProc = Get-CimInstance Win32_Process -Filter "ProcessId = $($p.Id)" -ErrorAction SilentlyContinue
                if ($cimProc) {
                    $cmd = $cimProc.CommandLine
                    if ($cmd -match "desctop_wigets") {
                        $isWidget = $true
                        $info = "Project Path Match"
                    }
                }
            }
            catch {}
        }
        if ($isWidget) {
            if ($ShowOutput) { Write-Host "  Found Widget: $info (PID: $($p.Id))" -ForegroundColor Yellow }
            try {
                Stop-Process -Id $p.Id -Force -ErrorAction Stop
                if ($ShowOutput) { Write-Host "    [STOPPED]" -ForegroundColor Green }
                $count++
            }
            catch {
                if ($ShowOutput) { Write-Host "    [FAILED] $($_.Exception.Message)" -ForegroundColor Red }
            }
        }
    }
    return $count
}
