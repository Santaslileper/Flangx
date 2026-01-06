# core/widget_interaction.ps1
# Drag, Drop, and Grid Interaction Logic with Full Collision Detection

# ============================================================================
# WIDGET REGISTRY - Track all active widgets for collision detection
# ============================================================================

if (-not $global:ActiveWidgets) {
    $global:ActiveWidgets = [System.Collections.ArrayList]::new()
}

function global:Register-Widget {
    param([System.Windows.Forms.Form]$Form)
    
    if (-not $global:ActiveWidgets.Contains($Form)) {
        $global:ActiveWidgets.Add($Form) | Out-Null
    }
    
    # Clean up disposed widgets
    $toRemove = @()
    foreach ($widget in $global:ActiveWidgets) {
        if ($widget.IsDisposed) {
            $toRemove += $widget
        }
    }
    foreach ($widget in $toRemove) {
        $global:ActiveWidgets.Remove($widget) | Out-Null
    }
}

function global:Unregister-Widget {
    param([System.Windows.Forms.Form]$Form)
    $global:ActiveWidgets.Remove($Form) | Out-Null
}

function global:Get-AllWidgetRects {
    $rects = @()
    foreach ($widget in $global:ActiveWidgets) {
        if (-not $widget.IsDisposed) {
            $rects += @{
                X = $widget.Location.X
                Y = $widget.Location.Y
                Width = $widget.Width
                Height = $widget.Height
                Form = $widget
            }
        }
    }
    return $rects
}

# ============================================================================
# COLLISION DETECTION - Check both icons and other widgets
# ============================================================================

function global:Test-IsOverlapping {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [System.Windows.Forms.Form]$ExcludeForm = $null,
        [int]$Tolerance = 5
    )
    
    # Check desktop icons
    try {
        $icons = Get-DesktopIconRects
        if ($icons -and $icons.Count -gt 0) {
            foreach ($icon in $icons) {
                # Rectangle overlap test with tolerance
                $overlapX = ($X -lt ($icon.Right + $Tolerance)) -and (($X + $Width) -gt ($icon.Left - $Tolerance))
                $overlapY = ($Y -lt ($icon.Bottom + $Tolerance)) -and (($Y + $Height) -gt ($icon.Top - $Tolerance))
                
                if ($overlapX -and $overlapY) {
                    return $true
                }
            }
        }
    }
    catch {
        Write-Host "Icon detection failed: $_"
        # Continue to check widgets even if icon detection fails
    }
    
    # Check other widgets
    try {
        $widgets = global:Get-AllWidgetRects
        foreach ($widget in $widgets) {
            # Skip self
            if ($ExcludeForm -and $widget.Form -eq $ExcludeForm) { continue }
            
            # Rectangle overlap test with tolerance
            $overlapX = ($X -lt ($widget.X + $widget.Width + $Tolerance)) -and (($X + $Width) -gt ($widget.X - $Tolerance))
            $overlapY = ($Y -lt ($widget.Y + $widget.Height + $Tolerance)) -and (($Y + $Height) -gt ($widget.Y - $Tolerance))
            
            if ($overlapX -and $overlapY) {
                return $true
            }
        }
    }
    catch {
        Write-Host "Widget collision detection failed: $_"
    }
    
    return $false
}

# ============================================================================
# DRAG FUNCTIONALITY
# ============================================================================

function global:Enable-WidgetDrag {
    param(
        [System.Windows.Forms.Control[]]$Controls,
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Panel]$IndicatorPanel = $null
    )
    
    # Auto-register on enable
    global:Register-Widget -Form $Form
    
    foreach ($ctrl in $Controls) {
        # Mouse Down
        $ctrl.Add_MouseDown({
            param($s, $e)
            if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
            if ($Form.Tag.IsLocked) { return }
            
            $Form.Tag.IsDragging = $true
            $Form.Tag.DragStartX = $e.X
            $Form.Tag.DragStartY = $e.Y
            $Form.Tag.OriginalX = $Form.Location.X
            $Form.Tag.OriginalY = $Form.Location.Y
            $Form.Tag.OriginalWidth = $Form.Width
            $Form.Tag.OriginalHeight = $Form.Height
            $Form.Opacity = 0.8
            
            if ($IndicatorPanel) { 
                $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 80) 
            }
        }.GetNewClosure())
        
        # Mouse Move
        $ctrl.Add_MouseMove({
            param($s, $e)
            if (-not $Form.Tag.IsDragging) { return }
            
            $newX = $Form.Left + ($e.X - $Form.Tag.DragStartX)
            $newY = $Form.Top + ($e.Y - $Form.Tag.DragStartY)
            
            # Keep within screen bounds
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $newX = [Math]::Max(0, [Math]::Min($newX, $screen.Width - $Form.Width))
            $newY = [Math]::Max(0, [Math]::Min($newY, $screen.Height - $Form.Height))
            
            # Check collision at new position
            $willCollide = global:Test-IsOverlapping -X $newX -Y $newY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
            
            # Snap Logic (only if enabled)
            if ($Form.Tag.SnapToGrid) {
                try {
                    $snap = Get-SnapPosition -CurrentX $newX -CurrentY $newY -WidgetWidth $Form.Width -WidgetHeight $Form.Height
                    
                    # Check collision at snap position
                    $pX = if ($snap.Snapped) { $snap.X } else { $newX }
                    $pY = if ($snap.Snapped) { $snap.Y } else { $newY }
                    
                    $snapWillCollide = global:Test-IsOverlapping -X $pX -Y $pY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
                    
                    # Update Preview - show collision state
                    $isValid = -not $snapWillCollide
                    global:Update-GridPreview -X $pX -Y $pY -Width $Form.Width -Height $Form.Height -IsSnapped $snap.Snapped -IsValid $isValid
                    
                    # Move to position if valid
                    if ($snap.Snapped -and -not $snapWillCollide) {
                        $Form.Location = New-Object System.Drawing.Point($snap.X, $snap.Y)
                    }
                    elseif (-not $willCollide) {
                        $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                    }
                    # If collision, stay at current position (sticky)
                }
                catch {
                    # Fallback to simple movement if snap fails
                    if (-not $willCollide) {
                        $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                    }
                }
            }
            else {
                # Free movement - only move if no collision
                if (-not $willCollide) {
                    $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                }
                else {
                     # If moving would cause collision, show red preview but don't move
                     global:Update-GridPreview -X $newX -Y $newY -Width $Form.Width -Height $Form.Height -IsSnapped $false -IsValid $false
                }
            }
        }.GetNewClosure())
        
        # Mouse Up
        $ctrl.Add_MouseUp({
            param($s, $e)
            if (-not $Form.Tag.IsDragging) { return }
            
            $Form.Tag.IsDragging = $false
            $Form.Opacity = 1.0
            
            # Hide Preview
            if ($global:GridPreview) { 
                $global:GridPreview.Close()
                $global:GridPreview = $null 
            }
            
            $finalX = $Form.Location.X
            $finalY = $Form.Location.Y

            # Final Snap Check (if enabled)
            if ($Form.Tag.SnapToGrid) {
                try {
                    $snap = Get-SnapPosition -CurrentX $Form.Left -CurrentY $Form.Top -WidgetWidth $Form.Width -WidgetHeight $Form.Height
                    if ($snap.Snapped) {
                        $finalX = $snap.X
                        $finalY = $snap.Y
                    }
                }
                catch {
                    Write-Host "Snap position failed: $_"
                }
            }

            # CRITICAL: Final Overlap Check
            try {
                $overlaps = global:Test-IsOverlapping -X $finalX -Y $finalY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
                
                if ($overlaps) {
                    # Revert to original position
                    $finalX = $Form.Tag.OriginalX
                    $finalY = $Form.Tag.OriginalY
                    if ($IndicatorPanel) { 
                        $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
                        global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                    }
                }
                else {
                    # Success - show green feedback
                    if ($IndicatorPanel) {
                        $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(100, 255, 100)
                        global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                    }
                }
            }
            catch {
                Write-Host "Final collision check failed: $_"
                # On error, safer to revert
                $finalX = $Form.Tag.OriginalX
                $finalY = $Form.Tag.OriginalY
                if ($IndicatorPanel) { 
                    $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 150, 0)
                    global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                }
            }

            $Form.Location = New-Object System.Drawing.Point($finalX, $finalY)
            
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    }
    
    # Quick Lock/Unlock on Indicator Double Click
    if ($IndicatorPanel) {
        $IndicatorPanel.Add_MouseDoubleClick({
            param($s, $e)
            if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
            
            # Toggle Lock
            $Form.Tag.IsLocked = -not $Form.Tag.IsLocked
            
            # Visual Feedback
            $color = if ($Form.Tag.IsLocked) { 
                [System.Drawing.Color]::FromArgb(150, 150, 150) 
            } else { 
                [System.Drawing.Color]::FromArgb(80, 255, 255, 255) 
            }
            $IndicatorPanel.BackColor = $color
            
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    }
}

# ============================================================================
# RESIZE FUNCTIONALITY
# ============================================================================

function global:Enable-WidgetResize {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Panel]$IndicatorPanel
    )

    # Resize Grip (Bottom Right)
    $grip = New-Object System.Windows.Forms.Label
    $grip.Size = New-Object System.Drawing.Size(16, 16)
    $grip.BackColor = "Transparent"
    $grip.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
    $grip.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $grip.Location = New-Object System.Drawing.Point(($Form.ClientRectangle.Width - 16), ($Form.ClientRectangle.Height - 16))
    $grip.Text = "◢"
    $grip.ForeColor = [System.Drawing.Color]::FromArgb(100, 255, 255, 255)
    $grip.TextAlign = "BottomRight"
    $Form.Controls.Add($grip)
    $grip.BringToFront()

    $Form.Tag.IsResizing = $false
    
    $grip.Add_MouseDown({
        param($s, $e)
        if ($e.Button -ne 'Left') { return }
        if ($Form.Tag.IsLocked) { return }
        
        $Form.Tag.IsResizing = $true
        $Form.Tag.ResizeStartX = $e.X
        $Form.Tag.ResizeStartY = $e.Y
        $Form.Tag.OriginalWidth = $Form.Width
        $Form.Tag.OriginalHeight = $Form.Height
        $Form.Opacity = 0.8
        
        if ($IndicatorPanel) { 
            $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 80) 
        }
    }.GetNewClosure())
    
    $grip.Add_MouseMove({
        param($s, $e)
        if (-not $Form.Tag.IsResizing) { return }
        
        # Calculate new size
        $currentWidth = $Form.Width
        $currentHeight = $Form.Height
        
        # Delta
        $dx = $e.X - $Form.Tag.ResizeStartX
        $dy = $e.Y - $Form.Tag.ResizeStartY
        
        $newWidth = [Math]::Max(100, $currentWidth + $dx)
        $newHeight = [Math]::Max(75, $currentHeight + $dy)
        
        # Check if new size would cause collision
        $willCollide = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $newWidth -Height $newHeight -ExcludeForm $Form
        
        if (-not $willCollide) {
            $Form.Size = New-Object System.Drawing.Size($newWidth, $newHeight)
            
            # Update preview if snap enabled
            if ($Form.Tag.SnapToGrid) {
                global:Update-GridPreview -X $Form.Location.X -Y $Form.Location.Y -Width $newWidth -Height $newHeight -IsSnapped $false -IsValid $true
            }
        }
        else {
            # Show red preview for invalid size
            if ($Form.Tag.SnapToGrid) {
                global:Update-GridPreview -X $Form.Location.X -Y $Form.Location.Y -Width $newWidth -Height $newHeight -IsSnapped $false -IsValid $false
            }
        }
        
    }.GetNewClosure())
    
    $grip.Add_MouseUp({
        param($s, $e)
        if (-not $Form.Tag.IsResizing) { return }
        
        $Form.Tag.IsResizing = $false
        $Form.Opacity = 1.0
        
        # Hide preview
        if ($global:GridPreview) { 
            $global:GridPreview.Close()
            $global:GridPreview = $null 
        }
        
        # Final collision check
        $willCollide = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
        
        if ($willCollide) {
            # Revert to original size
            $Form.Size = New-Object System.Drawing.Size($Form.Tag.OriginalWidth, $Form.Tag.OriginalHeight)
            if ($IndicatorPanel) { 
                $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
                global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
            }
        }
        else {
            # Snap size if enabled
            if ($Form.Tag.SnapToGrid) {
                try {
                    $icons = Get-DesktopIconRects
                    $metrics = Get-GridMetrics -IconRects $icons
                    
                    # Default fallbacks if metrics fail
                    $avgW = if ($metrics.AvgWidth -gt 10) { $metrics.AvgWidth } else { 75 }
                    $avgH = if ($metrics.AvgHeight -gt 10) { $metrics.AvgHeight } else { 75 }
                    $stepX = if ($metrics.StepX -gt 10) { $metrics.StepX } else { 100 }
                    $stepY = if ($metrics.StepY -gt 10) { $metrics.StepY } else { 100 }

                    # Calculate likely Column/Row Span
                    $rawCols = (($Form.Width - $avgW) / $stepX) + 1
                    $cols = [Math]::Max(1, [Math]::Round($rawCols))
                    
                    $rawRows = (($Form.Height - $avgH) / $stepY) + 1
                    $rows = [Math]::Max(1, [Math]::Round($rawRows))
                    
                    # Calculate Snapped Size
                    $snapW = $avgW + (($cols - 1) * $stepX)
                    $snapH = $avgH + (($rows - 1) * $stepY)
                    
                    # Verify snapped size doesn't cause collision
                    $snapCollision = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $snapW -Height $snapH -ExcludeForm $Form
                    
                    if (-not $snapCollision) {
                        $Form.Size = New-Object System.Drawing.Size([int]$snapW, [int]$snapH)
                    }
                }
                catch {
                    Write-Host "Size snap failed: $_"
                    # Keep current size if snap fails but no collision
                }
            }
            
            # Success feedback
            if ($IndicatorPanel) { 
                $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(100, 255, 100)
                global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
            }
        }
        
        global:Save-WidgetState -Form $Form
        
    }.GetNewClosure())
}

# ============================================================================
# PREVIEW AND VISUAL FEEDBACK
# ============================================================================

function global:Update-GridPreview {
    param(
        $X, 
        $Y, 
        $Width, 
        $Height, 
        $IsSnapped,
        $IsValid = $true
    )
    
    if (-not $global:GridPreview -or $global:GridPreview.IsDisposed) {
        $global:GridPreview = New-Object System.Windows.Forms.Form
        $global:GridPreview.FormBorderStyle = "None"
        $global:GridPreview.Opacity = 0.4
        $global:GridPreview.TopMost = $true
        $global:GridPreview.ShowInTaskbar = $false
        $global:GridPreview.StartPosition = "Manual"
        # Paint border
        $global:GridPreview.Add_Paint({
            param($sender, $paintArgs)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 100, 150, 255), 2)
            $paintArgs.Graphics.DrawRectangle($pen, 0, 0, $sender.Width - 1, $sender.Height - 1)
        })
        $global:GridPreview.Show()
    }
    
    $global:GridPreview.Size = New-Object System.Drawing.Size($Width, $Height)
    $global:GridPreview.Location = New-Object System.Drawing.Point($X, $Y)
    
    # Color coding:
    # Red = collision / invalid
    # Green = snapped and valid
    # Yellow = free-form and valid
    if (-not $IsValid) {
        $color = [System.Drawing.Color]::FromArgb(255, 100, 100)  # Red - collision
    }
    elseif ($IsSnapped) {
        $color = [System.Drawing.Color]::FromArgb(100, 255, 100)  # Green - snapped
    }
    else {
        $color = [System.Drawing.Color]::FromArgb(255, 200, 100)  # Yellow - free
    }
    
    $global:GridPreview.BackColor = $color
}

function global:Start-ColorResetTimer {
    param($Panel, $FormTag)
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1500
    $timer.Add_Tick({
        if ($FormTag.IsLocked) { 
            $Panel.BackColor = [System.Drawing.Color]::FromArgb(150, 150, 150) 
        }
        else { 
            $Panel.BackColor = [System.Drawing.Color]::FromArgb(80, 255, 255, 255) 
        }
        $this.Stop()
        $this.Dispose()
    }.GetNewClosure())
    $timer.Start()
}
