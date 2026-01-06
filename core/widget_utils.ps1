function global:Ensure-SingleInstance {
    param([string]$ScriptPath)
    $currentPid = $PID
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    $others = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' AND CommandLine LIKE '%$scriptName%'" | Where-Object { $_.ProcessId -ne $currentPid }
    if ($others) { exit }
}
