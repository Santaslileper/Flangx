$rootDir = "$PSScriptRoot"
$files = Get-ChildItem -Path $rootDir -Recurse -Filter "*.ps1"
$results = @()
foreach ($file in $files) {
    if ($file.Name -eq "Extract-Comments.ps1") { continue } 
    try {
        $content = Get-Content $file.FullName -Raw
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $errors = $null
        $tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        foreach ($t in $tokens) {
            if ($t.Type -eq "Comment") {
                # Handle multi-line comments by ensuring they display nicely in CSV
                $cleanComment = $t.Content.Trim() -replace "`r`n", " " -replace "`n", " "
                $results += [PSCustomObject]@{
                    File       = $file.Name
                    Line       = $t.StartLine
                    Comment    = $cleanComment
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to parse $($file.Name): $_"
    }
}
$outputPath = Join-Path $rootDir "comments.csv"
$results | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
Write-Host "Extracted $($results.Count) comments to $outputPath"
