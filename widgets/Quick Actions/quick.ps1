# widgets/quick_actions/quick_actions.ps1
# Quick Actions Panel - System Maintenance & Cleanup

param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)

# Wrappers for global error handling
try {
    # Logging
    $debugLog = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "debug.log"
    # "Starting Quick Actions..." | Out-File $debugLog -Append

    # Encoding Safe Icons
    $Icon_Restart = [char]::ConvertFromUtf32(0x1F504) # 🔄
    $Icon_Monitor = [char]::ConvertFromUtf32(0x1F5A5) # 🖥️
    $Icon_Warning = [char]::ConvertFromUtf32(0x26A0)  # ⚠️
    $Icon_Clipboard = [char]::ConvertFromUtf32(0x1F4CB) # 📋
    $Icon_Trash = [char]::ConvertFromUtf32(0x1F5D1) # 🗑️
    $Icon_Folder = [char]::ConvertFromUtf32(0x1F4C1) # 📁
    $Icon_Globe = [char]::ConvertFromUtf32(0x1F310) # 🌐
    $Icon_Image = [char]::ConvertFromUtf32(0x1F5BC) # 🖼️
    $Icon_Update = [char]::ConvertFromUtf32(0x1F504) # 🔄
    $Icon_Earth = [char]::ConvertFromUtf32(0x1F30D) # 🌍
    $Icon_Lightning = [char]::ConvertFromUtf32(0x26A1)  # ⚡

    # Paths
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $configFileName = "config.json"
    if ($InstanceId) { $configFileName = "config_$InstanceId.json" }
    $configPath = Join-Path $scriptDir $configFileName

    # Load Core
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    . "$rootDir\core\window_utils.ps1"
    . "$rootDir\core\desktop_icons.ps1"
    . "$rootDir\core\grid_logic.ps1"
    . "$rootDir\core\widget_base.ps1"

    # Theme
    $theme = @{
        Background  = [System.Drawing.Color]::FromArgb(30, 30, 35)
        Foreground  = [System.Drawing.Color]::White
        Accent      = [System.Drawing.Color]::FromArgb(100, 200, 255)
        Success     = [System.Drawing.Color]::FromArgb(80, 200, 120)
        Warning     = [System.Drawing.Color]::FromArgb(255, 180, 0)
        Indicator   = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
        ButtonBg    = [System.Drawing.Color]::FromArgb(45, 45, 52)
        ButtonHover = [System.Drawing.Color]::FromArgb(60, 60, 70)
    }

    # Create Standard Widget Form
    # Width 320, Height 480
    $form = New-StandardWidget -Name "Quick Actions" -Width 320 -Height 480 -ConfigPath $configPath -Theme $theme

    # Override Manual Position if passed
    if ($X -ne -1 -and $Y -ne -1) {
        $form.StartPosition = "Manual"
        $form.Location = New-Object System.Drawing.Point($X, $Y)
    }

    # --- Widget Specific UI ---

    # Main Container provided by Factory
    $mainPanel = $form.Tag.ContentPanel
    # Adjust padding if needed, but factory default (10,5,10,10) is okay. 
    # Original was (15, 30, 15, 15). We might want 15 side padding.
    $mainPanel.Padding = New-Object System.Windows.Forms.Padding(15, 5, 15, 15)

    # Scrollable Container
    $container = New-Object System.Windows.Forms.Panel
    $container.Dock = "Fill"
    $container.BackColor = "Transparent"
    $container.AutoScroll = $true
    $mainPanel.Controls.Add($container)

    # Current Y position for layout
    $currentY = 0
    $spacing = 8
    $buttonHeight = 42
    $sectionSpacing = 15

    # Helper function to create section header
    function New-SectionHeader {
        param(
            [string]$Text,
            [int]$Y
        )
        
        $header = New-Object System.Windows.Forms.Label
        $header.Text = $Text
        $header.ForeColor = $theme.Accent
        $header.BackColor = "Transparent"
        $header.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $header.Width = 270 # Adjusted for scrollbar space
        $header.Height = 25
        $header.Left = 0
        $header.Top = $Y
        $header.TextAlign = "MiddleLeft"
        $container.Controls.Add($header)
        
        return 30
    }

    # Helper function to create action button
    function New-ActionButton {
        param(
            [string]$Text,
            [string]$Icon,
            [int]$Y,
            [scriptblock]$Action
        )
        
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = "$Icon  $Text"
        $btn.Width = 270 # Adjusted
        $btn.Height = $buttonHeight
        $btn.Left = 0
        $btn.Top = $Y
        $btn.FlatStyle = "Flat"
        $btn.FlatAppearance.BorderSize = 1
        $btn.FlatAppearance.BorderColor = $theme.Indicator
        $btn.BackColor = $theme.ButtonBg
        $btn.ForeColor = $theme.Foreground
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
        $btn.TextAlign = "MiddleLeft"
        $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        
        # Hover effect
        $btn.Add_MouseEnter({
                $this.BackColor = $theme.ButtonHover
            })
        $btn.Add_MouseLeave({
                $this.BackColor = $theme.ButtonBg
            })
        
        # Click action with visual feedback
        $btn.Add_Click({
                $originalColor = $this.BackColor
                $this.BackColor = $theme.Success
                $this.Enabled = $false
            
                try {
                    & $Action
                    Start-Sleep -Milliseconds 300
                }
                catch {
                    $this.BackColor = [System.Drawing.Color]::FromArgb(200, 80, 80)
                    [System.Windows.Forms.MessageBox]::Show("Error: $_", "Quick Actions", "OK", "Error")
                }
                finally {
                    $this.BackColor = $originalColor
                    $this.Enabled = $true
                }
            })
        
        $container.Controls.Add($btn)
        return $buttonHeight + $spacing
    }

    # Status Label at top
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Ready"
    $statusLabel.ForeColor = $theme.Success
    $statusLabel.BackColor = "Transparent"
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $statusLabel.Width = 270
    $statusLabel.Height = 20
    $statusLabel.Left = 0
    $statusLabel.Top = $currentY
    $statusLabel.TextAlign = "MiddleCenter"
    $container.Controls.Add($statusLabel)
    $currentY += 25

    # Function to update status
    function Update-Status {
        param([string]$Message, [string]$Type = "success")
        
        $statusLabel.Text = $Message
        
        switch ($Type) {
            "success" { $statusLabel.ForeColor = $theme.Success }
            "warning" { $statusLabel.ForeColor = $theme.Warning }
            "error" { $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 80, 80) }
            default { $statusLabel.ForeColor = $theme.Foreground }
        }
        
        $form.Refresh()
    }

    # --- SYSTEM MAINTENANCE SECTION ---
    $currentY += New-SectionHeader -Text "🔧 System Maintenance" -Y $currentY

    $currentY += New-ActionButton -Text "Restart Explorer" -Icon $Icon_Restart -Y $currentY -Action {
        Update-Status "Restarting Explorer..." "warning"
        Stop-Process -Name explorer -Force
        Start-Process explorer
        Update-Status "Explorer restarted ✓" "success"
    }

    $currentY += New-ActionButton -Text "Refresh Desktop Icons" -Icon $Icon_Monitor -Y $currentY -Action {
        Update-Status "Refreshing desktop..." "warning"
        # Force desktop refresh
        $shell = New-Object -ComObject Shell.Application
        $shell.Windows() | ForEach-Object { $_.Refresh() }
        # Alternative method
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Update-Status "Desktop refreshed ✓" "success"
    }

    $currentY += New-ActionButton -Text "End Non-Responding Tasks" -Icon $Icon_Warning -Y $currentY -Action {
        Update-Status "Checking for hung processes..." "warning"
        $hung = Get-Process | Where-Object { $_.Responding -eq $false }
        if ($hung) {
            $count = $hung.Count
            $hung | Stop-Process -Force
            Update-Status "Ended $count non-responding task(s) ✓" "success"
        }
        else {
            Update-Status "No hung processes found ✓" "success"
        }
    }

    # --- CLEANUP SECTION ---
    $currentY += $sectionSpacing
    $currentY += New-SectionHeader -Text "🧹 Cleanup Actions" -Y $currentY

    $currentY += New-ActionButton -Text "Clear Clipboard" -Icon $Icon_Clipboard -Y $currentY -Action {
        Update-Status "Clearing clipboard..." "warning"
        [System.Windows.Forms.Clipboard]::Clear()
        Update-Status "Clipboard cleared ✓" "success"
    }

    $currentY += New-ActionButton -Text "Empty Recycle Bin" -Icon $Icon_Trash -Y $currentY -Action {
        Update-Status "Emptying Recycle Bin..." "warning"
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(0xA)
        $itemCount = $recycleBin.Items().Count
        
        if ($itemCount -gt 0) {
            $recycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
            # Also use Windows API method
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Update-Status "Emptied $itemCount item(s) ✓" "success"
        }
        else {
            Update-Status "Recycle Bin already empty ✓" "success"
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    }

    $currentY += New-ActionButton -Text "Clear Temp Files" -Icon $Icon_Folder -Y $currentY -Action {
        Update-Status "Clearing temp files..." "warning"
        
        $tempPaths = @(
            $env:TEMP,
            "C:\Windows\Temp",
            "$env:LOCALAPPDATA\Temp"
        )
        
        $totalDeleted = 0
        $totalSize = 0
        
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                try {
                    $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    $totalSize += ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    $totalDeleted++
                }
                catch {}
            }
        }
        
        $sizeMB = [math]::Round($totalSize / 1MB, 2)
        Update-Status "Cleared ${sizeMB}MB temp files ✓" "success"
    }

    $currentY += New-ActionButton -Text "Flush DNS Cache" -Icon $Icon_Globe -Y $currentY -Action {
        Update-Status "Flushing DNS cache..." "warning"
        ipconfig /flushdns | Out-Null
        Update-Status "DNS cache flushed ✓" "success"
    }

    # --- QUICK CLEANUP SECTION ---
    $currentY += $sectionSpacing
    $currentY += New-SectionHeader -Text "⚡ Quick Cleanup" -Y $currentY

    $currentY += New-ActionButton -Text "Clear Thumbnail Cache" -Icon $Icon_Image -Y $currentY -Action {
        Update-Status "Clearing thumbnail cache..." "warning"
        
        $thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        if (Test-Path $thumbCachePath) {
            Get-ChildItem -Path $thumbCachePath -Filter "thumbcache_*.db" -Force | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -Path $thumbCachePath -Filter "iconcache_*.db" -Force | Remove-Item -Force -ErrorAction SilentlyContinue
        }
        
        Update-Status "Thumbnail cache cleared ✓" "success"
    }

    $currentY += New-ActionButton -Text "Clear Windows Update Cache" -Icon $Icon_Update -Y $currentY -Action {
        Update-Status "Clearing update cache..." "warning"
        
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $updatePath = "C:\Windows\SoftwareDistribution\Download"
        if (Test-Path $updatePath) {
            Get-ChildItem -Path $updatePath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        
        Update-Status "Update cache cleared ✓" "success"
    }

    $currentY += New-ActionButton -Text "Clear Browser Cache" -Icon $Icon_Earth -Y $currentY -Action {
        Update-Status "Clearing browser caches..." "warning"
        
        # Edge cache
        $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        if (Test-Path $edgePath) {
            Get-ChildItem -Path $edgePath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Chrome cache
        $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        if (Test-Path $chromePath) {
            Get-ChildItem -Path $chromePath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Update-Status "Browser caches cleared ✓" "success"
    }

    # --- DANGER ZONE ---
    $currentY += $sectionSpacing
    $currentY += New-SectionHeader -Text "⚠️ Clean All (Use Carefully)" -Y $currentY

    # Clean All Button (larger, more prominent)
    $btnCleanAll = New-Object System.Windows.Forms.Button
    $btnCleanAll.Text = "$Icon_Trash CLEAN ALL"
    $btnCleanAll.Width = 270 # Adjusted
    $btnCleanAll.Height = 50
    $btnCleanAll.Left = 0
    $btnCleanAll.Top = $currentY
    $btnCleanAll.FlatStyle = "Flat"
    $btnCleanAll.FlatAppearance.BorderSize = 2
    $btnCleanAll.FlatAppearance.BorderColor = $theme.Warning
    $btnCleanAll.BackColor = [System.Drawing.Color]::FromArgb(60, 50, 50)
    $btnCleanAll.ForeColor = $theme.Warning
    $btnCleanAll.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnCleanAll.TextAlign = "MiddleCenter"
    $btnCleanAll.Cursor = [System.Windows.Forms.Cursors]::Hand

    $btnCleanAll.Add_MouseEnter({
            $this.BackColor = [System.Drawing.Color]::FromArgb(80, 60, 60)
        })
    $btnCleanAll.Add_MouseLeave({
            $this.BackColor = [System.Drawing.Color]::FromArgb(60, 50, 50)
        })

    $btnCleanAll.Add_Click({
            $result = [System.Windows.Forms.MessageBox]::Show(
                "This will perform ALL cleanup actions. Continue?",
                "Confirm Clean All",
                "YesNo",
                "Warning"
            )
        
            if ($result -eq "Yes") {
                Update-Status "Running all cleanup tasks..." "warning"
                $this.Enabled = $false
            
                # Clear Clipboard
                [System.Windows.Forms.Clipboard]::Clear()
            
                # Empty Recycle Bin
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            
                # Clear Temp Files
                $tempPaths = @($env:TEMP, "C:\Windows\Temp", "$env:LOCALAPPDATA\Temp")
                foreach ($path in $tempPaths) {
                    if (Test-Path $path) {
                        Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | 
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            
                # Flush DNS
                ipconfig /flushdns | Out-Null
            
                # Clear Thumbnail Cache
                $thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                Get-ChildItem -Path $thumbCachePath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue | 
                Remove-Item -Force -ErrorAction SilentlyContinue
            
                # Clear Windows Update Cache
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                $updatePath = "C:\Windows\SoftwareDistribution\Download"
                if (Test-Path $updatePath) {
                    Get-ChildItem -Path $updatePath -Recurse -Force -ErrorAction SilentlyContinue | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            
                # Clear Browser Caches
                $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                @($edgePath, $chromePath) | ForEach-Object {
                    if (Test-Path $_) {
                        Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | 
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            
                Update-Status "All cleanup tasks completed ✓" "success"
                $this.Enabled = $true
            }
        })

    $container.Controls.Add($btnCleanAll)
    $currentY += 60

    # Add some bottom padding
    $currentY += 20

    # Drag specific controls if needed (factory default drags everything not handled)
    # But for scroll panel, it can catch mouse.
    # We rely on Factory drag for header/border.
    
    # Run
    [System.Windows.Forms.Application]::Run($form)

}
catch {
    $err = "$_`n$($_.ScriptStackTrace)"
    $err | Out-File (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "error.log") -Append
}