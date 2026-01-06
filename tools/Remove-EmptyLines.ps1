$rootDir = "$PSScriptRoot"
$files = Get-ChildItem -Path $rootDir -Recurse -Filter "*.ps1"

foreach ($file in $files) {
    if ($file.Name -eq "Remove-EmptyLines.ps1") { continue }
    
    try {
        $lines = Get-Content $file.FullName
        $nonEmptyLines = $lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        
        if ($lines.Count -ne $nonEmptyLines.Count) {
            $nonEmptyLines | Set-Content $file.FullName -Encoding UTF8
            Write-Host "Cleaned $($file.Name)"
        }
    }
    catch {
        Write-Warning "Failed to process $($file.Name): $_"
    }
}
