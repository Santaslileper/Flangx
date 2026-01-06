if (-not $global:ActiveWidgets) {
    $global:ActiveWidgets = [System.Collections.ArrayList]::new()
}
function global:Register-Widget {
    param([System.Windows.Forms.Form]$Form)
    if (-not $global:ActiveWidgets.Contains($Form)) {
        $global:ActiveWidgets.Add($Form) | Out-Null
    }
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
function global:Test-IsOverlapping {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [System.Windows.Forms.Form]$ExcludeForm = $null,
        [int]$Tolerance = 0
    )
    try {
        $icons = Get-DesktopIconRects
        if ($icons -and $icons.Count -gt 0) {
            foreach ($icon in $icons) {
                # Strict check (User requested "act like icons")
                $overlapX = ($X -lt ($icon.Right + $Tolerance)) -and (($X + $Width) -gt ($icon.Left - $Tolerance))
                $overlapY = ($Y -lt ($icon.Bottom + $Tolerance)) -and (($Y + $Height) -gt ($icon.Top - $Tolerance))
                if ($overlapX -and $overlapY) {
                    return $true
                }
            }
        }
    }
    catch { }
    try {
        $widgets = global:Get-AllWidgetRects
        foreach ($widget in $widgets) {
            if ($ExcludeForm -and $widget.Form -eq $ExcludeForm) { continue }
            $overlapX = ($X -lt ($widget.X + $widget.Width + $Tolerance)) -and (($X + $Width) -gt ($widget.X - $Tolerance))
            $overlapY = ($Y -lt ($widget.Y + $widget.Height + $Tolerance)) -and (($Y + $Height) -gt ($widget.Y - $Tolerance))
            if ($overlapX -and $overlapY) {
                return $true
            }
        }
    }
    catch { }
    return $false
}
function global:Enable-WidgetDrag {
    param(
        [System.Windows.Forms.Control[]]$Controls,
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Panel]$IndicatorPanel = $null
    )
    global:Register-Widget -Form $Form
    foreach ($ctrl in $Controls) {
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
        $ctrl.Add_MouseMove({
            param($s, $e)
            if (-not $Form.Tag.IsDragging) { return }
            $newX = $Form.Left + ($e.X - $Form.Tag.DragStartX)
            $newY = $Form.Top + ($e.Y - $Form.Tag.DragStartY)
            # Virtual Screen Bounds
            $virtualBounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
            if ($newX -gt $virtualBounds.Right - 50) { $newX = $virtualBounds.Right - 50 }
            if ($newX -lt $virtualBounds.Left) { $newX = $virtualBounds.Left }
            if ($newY -gt $virtualBounds.Bottom - 50) { $newY = $virtualBounds.Bottom - 50 }
            if ($newY -lt $virtualBounds.Top) { $newY = $virtualBounds.Top }
            
            if ($Form.Tag.SnapToGrid) {
                $willCollide = global:Test-IsOverlapping -X $newX -Y $newY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form -Tolerance 0
                try {
                    $snap = Get-SnapPosition -CurrentX $newX -CurrentY $newY -WidgetWidth $Form.Width -WidgetHeight $Form.Height
                    $pX = if ($snap.Snapped) { $snap.X } else { $newX }
                    $pY = if ($snap.Snapped) { $snap.Y } else { $newY }
                    $snapWillCollide = global:Test-IsOverlapping -X $pX -Y $pY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form -Tolerance 0
                    $isValid = -not $snapWillCollide
                    
                    global:Update-GridPreview -X $pX -Y $pY -Width $Form.Width -Height $Form.Height -IsSnapped $snap.Snapped -IsValid $isValid
                    
                    if ($snap.Snapped -and -not $snapWillCollide) {
                        $Form.Location = New-Object System.Drawing.Point($snap.X, $snap.Y)
                    }
                    elseif (-not $willCollide) {
                        # Fluid drag if not snapping to valid target
                        $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                    }
                }
                catch {
                    if (-not $willCollide) {
                        $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                    }
                }
            }
            else {
                # FREE MODE: 100% Control - Always Move
                $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                if ($global:GridPreview) { 
                    $global:GridPreview.Close()
                    $global:GridPreview = $null 
                }
            }
        }.GetNewClosure())
        $ctrl.Add_MouseUp({
            param($s, $e)
            if (-not $Form.Tag.IsDragging) { return }
            $Form.Tag.IsDragging = $false
            $Form.Opacity = 1.0
            if ($global:GridPreview) { 
                $global:GridPreview.Close()
                $global:GridPreview = $null 
            }
            $finalX = $Form.Location.X
            $finalY = $Form.Location.Y
            
            # Only enforce overlap Revert if SnapToGrid is enabled
            if ($Form.Tag.SnapToGrid) {
                $overlaps = global:Test-IsOverlapping -X $finalX -Y $finalY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form -Tolerance 0
                if ($overlaps) {
                    # Collision -> Revert
                    $finalX = $Form.Tag.OriginalX
                    $finalY = $Form.Tag.OriginalY
                    if ($IndicatorPanel) { 
                        $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
                        global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                    }
                }
                else {
                    if ($IndicatorPanel) {
                        $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(100, 255, 100)
                        global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                    }
                }
            }
            
            $Form.Location = New-Object System.Drawing.Point($finalX, $finalY)
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    }
    if ($IndicatorPanel) {
        $IndicatorPanel.Add_MouseDoubleClick({
            param($s, $e)
            if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
            $Form.Tag.IsLocked = -not $Form.Tag.IsLocked
            $color = if ($Form.Tag.IsLocked) { [System.Drawing.Color]::FromArgb(150, 150, 150) } else { [System.Drawing.Color]::FromArgb(80, 255, 255, 255) }
            $IndicatorPanel.BackColor = $color
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    }
}
function global:Enable-WidgetResize {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Panel]$IndicatorPanel
    )
    $grip = New-Object System.Windows.Forms.Label
    $grip.Size = New-Object System.Drawing.Size(16, 16)
    $grip.BackColor = "Transparent"
    $grip.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
    $grip.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $grip.Location = New-Object System.Drawing.Point(($Form.ClientRectangle.Width - 16), ($Form.ClientRectangle.Height - 16))
    $grip.Text = "â—¢"
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
        
        # Cache Grid Metrics for Stepped Scaling
        if ($Form.Tag.SnapToGrid) {
            try {
                $icons = Get-DesktopIconRects
                $metrics = Get-GridMetrics -IconRects $icons
                $Form.Tag.ResizeMetrics = $metrics
            } catch { $Form.Tag.ResizeMetrics = $null }
        }
        
        if ($IndicatorPanel) { 
            $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 80) 
        }
    }.GetNewClosure())
    $grip.Add_MouseMove({
        param($s, $e)
        if (-not $Form.Tag.IsResizing) { return }
        
        $targetW = $Form.Tag.OriginalWidth + ($e.X - $Form.Tag.ResizeStartX)
        $targetH = $Form.Tag.OriginalHeight + ($e.Y - $Form.Tag.ResizeStartY)
        
        $finalW = $targetW
        $finalH = $targetH
        
        # STEPPED RESIZE LOGIC (Only if SnapToGrid)
        if ($Form.Tag.SnapToGrid -and $Form.Tag.ResizeMetrics) {
            $m = $Form.Tag.ResizeMetrics
            $baseW = if ($m.AvgWidth -gt 10) { $m.AvgWidth } else { 75 }
            $baseH = if ($m.AvgHeight -gt 10) { $m.AvgHeight } else { 75 }
            $stepX = if ($m.StepX -gt 10) { $m.StepX } else { 100 }
            $stepY = if ($m.StepY -gt 10) { $m.StepY } else { 100 }
            
            # Col/Row Calculation
            $cols = [Math]::Max(1, [Math]::Round(($targetW - $baseW) / $stepX))
            $rows = [Math]::Max(1, [Math]::Round(($targetH - $baseH) / $stepY))
            
            # Snap to increments
            $finalW = $baseW + ($cols * $stepX)
            $finalH = $baseH + ($rows * $stepY)
        }
        
        $finalW = [Math]::Max(50, $finalW)
        $finalH = [Math]::Max(50, $finalH)
        
        $Form.Size = New-Object System.Drawing.Size($finalW, $finalH)
        
        if ($Form.Tag.SnapToGrid) {
            $willCollide = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $finalW -Height $finalH -ExcludeForm $Form -Tolerance 0
             # Preview matches current form size
             global:Update-GridPreview -X $Form.Location.X -Y $Form.Location.Y -Width $finalW -Height $finalH -IsSnapped $true -IsValid (-not $willCollide)
        }
    }.GetNewClosure())
    $grip.Add_MouseUp({
        param($s, $e)
        if (-not $Form.Tag.IsResizing) { return }
        $Form.Tag.IsResizing = $false
        $Form.Opacity = 1.0
        if ($global:GridPreview) { 
            $global:GridPreview.Close()
            $global:GridPreview = $null 
        }
        
        # Only enforce Revert if SnapToGrid
        if ($Form.Tag.SnapToGrid) {
            $willCollide = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $Form.Width -Height $Form.Height -ExcludeForm $Form -Tolerance 0
            if ($willCollide) {
                # Snap Back if Invalid
                $Form.Size = New-Object System.Drawing.Size($Form.Tag.OriginalWidth, $Form.Tag.OriginalHeight)
                if ($IndicatorPanel) { 
                    $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
                    global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                }
            }
            else {
                if ($IndicatorPanel) { 
                    $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(100, 255, 100)
                    global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
                }
            }
        }
        global:Save-WidgetState -Form $Form
    }.GetNewClosure())
}
function global:Update-GridPreview {
    param($X, $Y, $Width, $Height, $IsSnapped, $IsValid = $true)
    if (-not $global:GridPreview -or $global:GridPreview.IsDisposed) {
        $global:GridPreview = New-Object System.Windows.Forms.Form
        $global:GridPreview.FormBorderStyle = "None"
        $global:GridPreview.Opacity = 0.4
        $global:GridPreview.TopMost = $true
        $global:GridPreview.ShowInTaskbar = $false
        $global:GridPreview.StartupPosition = "Manual"
        $global:GridPreview.Add_Paint({
            param($sender, $paintArgs)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 100, 150, 255), 2)
            $paintArgs.Graphics.DrawRectangle($pen, 0, 0, $sender.Width - 1, $sender.Height - 1)
        })
        $global:GridPreview.Show()
    }
    $global:GridPreview.Size = New-Object System.Drawing.Size($Width, $Height)
    $global:GridPreview.Location = New-Object System.Drawing.Point($X, $Y)
    if (-not $IsValid) { $color = [System.Drawing.Color]::FromArgb(255, 100, 100) }
    elseif ($IsSnapped) { $color = [System.Drawing.Color]::FromArgb(100, 255, 100) }
    else { $color = [System.Drawing.Color]::FromArgb(255, 200, 100) }
    $global:GridPreview.BackColor = $color
}
function global:Start-ColorResetTimer {
    param($Panel, $FormTag)
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1500
    $timer.Add_Tick({
        if ($FormTag.IsLocked) { $Panel.BackColor = [System.Drawing.Color]::FromArgb(150, 150, 150) }
        else { $Panel.BackColor = [System.Drawing.Color]::FromArgb(80, 255, 255, 255) }
        $this.Stop(); $this.Dispose()
    }.GetNewClosure())
    $timer.Start()
}
