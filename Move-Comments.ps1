$rootDir = "$PSScriptRoot"
$files = Get-ChildItem -Path $rootDir -Recurse -Filter "*.ps1"
foreach ($file in $files) {
    if ($file.Name -eq "Move-Comments.ps1" -or $file.Name -eq "Extract-Comments.ps1") { continue }
    try {
        # Read raw content to preserve newlines/encoding positions
        $content = [IO.File]::ReadAllText($file.FullName)
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $errors = $null
        $tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        # Get only comments
        $commentTokens = $tokens | Where-Object { $_.Type -eq "Comment" }
        # Sort descending by Start offset so we can delete safely from the end backwards
        $commentTokens = $commentTokens | Sort-Object Start -Descending
        if ($commentTokens.Count -gt 0) {
            $sb = New-Object System.Text.StringBuilder($content)
            foreach ($t in $commentTokens) {
                $sb.Remove($t.Start, $t.Length)
            }
            $newContent = $sb.ToString()
            # Optional: Clean up empty lines created by removing full-line comments?
            # User just said "remove comments". Preserving line structure is safer for debugging relative to the CSV line numbers.
            # But let's trim trailing whitespace on lines that had inline comments.
            [IO.File]::WriteAllText($file.FullName, $newContent)
            Write-Host "Processed $($file.Name): Removed $($commentTokens.Count) comments."
        }
    }
    catch {
        Write-Warning "Failed to process $($file.Name): $_"
    }
}
