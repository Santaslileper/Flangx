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
        [int]$Tolerance = 5
    )
    try {
        $icons = Get-DesktopIconRects
        if ($icons -and $icons.Count -gt 0) {
            foreach ($icon in $icons) {
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
    }
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
    catch {
        Write-Host "Widget collision detection failed: $_"
    }
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
            $virtualBounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
            if ($newX -gt $virtualBounds.Right - 50) { $newX = $virtualBounds.Right - 50 }
            if ($newX -lt $virtualBounds.Left) { $newX = $virtualBounds.Left }
            if ($newY -gt $virtualBounds.Bottom - 50) { $newY = $virtualBounds.Bottom - 50 }
            if ($newY -lt $virtualBounds.Top) { $newY = $virtualBounds.Top }
            $willCollide = global:Test-IsOverlapping -X $newX -Y $newY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
            if ($Form.Tag.SnapToGrid) {
                try {
                    $snap = Get-SnapPosition -CurrentX $newX -CurrentY $newY -WidgetWidth $Form.Width -WidgetHeight $Form.Height
                    $pX = if ($snap.Snapped) { $snap.X } else { $newX }
                    $pY = if ($snap.Snapped) { $snap.Y } else { $newY }
                    $snapWillCollide = global:Test-IsOverlapping -X $pX -Y $pY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
                    $isValid = -not $snapWillCollide
                    global:Update-GridPreview -X $pX -Y $pY -Width $Form.Width -Height $Form.Height -IsSnapped $snap.Snapped -IsValid $isValid
                    if ($snap.Snapped -and -not $snapWillCollide) {
                        $Form.Location = New-Object System.Drawing.Point($snap.X, $snap.Y)
                    }
                    elseif (-not $willCollide) {
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
                if (-not $willCollide) {
                    $Form.Location = New-Object System.Drawing.Point($newX, $newY)
                }
                else {
                     global:Update-GridPreview -X $newX -Y $newY -Width $Form.Width -Height $Form.Height -IsSnapped $false -IsValid $false
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
            try {
                $overlaps = global:Test-IsOverlapping -X $finalX -Y $finalY -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
                if ($overlaps) {
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
            catch {
                Write-Host "Final collision check failed: $_"
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
    if ($IndicatorPanel) {
        $IndicatorPanel.Add_MouseDoubleClick({
            param($s, $e)
            if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
            $Form.Tag.IsLocked = -not $Form.Tag.IsLocked
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
        if ($IndicatorPanel) { 
            $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 80) 
        }
    }.GetNewClosure())
    $grip.Add_MouseMove({
        param($s, $e)
        if (-not $Form.Tag.IsResizing) { return }
        $currentWidth = $Form.Width
        $currentHeight = $Form.Height
        $dx = $e.X - $Form.Tag.ResizeStartX
        $dy = $e.Y - $Form.Tag.ResizeStartY
        $newWidth = [Math]::Max(100, $currentWidth + $dx)
        $newHeight = [Math]::Max(75, $currentHeight + $dy)
        $willCollide = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $newWidth -Height $newHeight -ExcludeForm $Form
        if (-not $willCollide) {
            $Form.Size = New-Object System.Drawing.Size($newWidth, $newHeight)
            if ($Form.Tag.SnapToGrid) {
                global:Update-GridPreview -X $Form.Location.X -Y $Form.Location.Y -Width $newWidth -Height $newHeight -IsSnapped $false -IsValid $true
            }
        }
        else {
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
        if ($global:GridPreview) { 
            $global:GridPreview.Close()
            $global:GridPreview = $null 
        }
        $willCollide = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $Form.Width -Height $Form.Height -ExcludeForm $Form
        if ($willCollide) {
            $Form.Size = New-Object System.Drawing.Size($Form.Tag.OriginalWidth, $Form.Tag.OriginalHeight)
            if ($IndicatorPanel) { 
                $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
                global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
            }
        }
        else {
            if ($Form.Tag.SnapToGrid) {
                try {
                    $icons = Get-DesktopIconRects
                    $metrics = Get-GridMetrics -IconRects $icons
                    $avgW = if ($metrics.AvgWidth -gt 10) { $metrics.AvgWidth } else { 75 }
                    $avgH = if ($metrics.AvgHeight -gt 10) { $metrics.AvgHeight } else { 75 }
                    $stepX = if ($metrics.StepX -gt 10) { $metrics.StepX } else { 100 }
                    $stepY = if ($metrics.StepY -gt 10) { $metrics.StepY } else { 100 }
                    $rawCols = (($Form.Width - $avgW) / $stepX) + 1
                    $cols = [Math]::Max(1, [Math]::Round($rawCols))
                    $rawRows = (($Form.Height - $avgH) / $stepY) + 1
                    $rows = [Math]::Max(1, [Math]::Round($rawRows))
                    $snapW = $avgW + (($cols - 1) * $stepX)
                    $snapH = $avgH + (($rows - 1) * $stepY)
                    $snapCollision = global:Test-IsOverlapping -X $Form.Location.X -Y $Form.Location.Y -Width $snapW -Height $snapH -ExcludeForm $Form
                    if (-not $snapCollision) {
                        $Form.Size = New-Object System.Drawing.Size([int]$snapW, [int]$snapH)
                    }
                }
                catch {
                    Write-Host "Size snap failed: $_"
                }
            }
            if ($IndicatorPanel) { 
                $IndicatorPanel.BackColor = [System.Drawing.Color]::FromArgb(100, 255, 100)
                global:Start-ColorResetTimer -Panel $IndicatorPanel -FormTag $Form.Tag
            }
        }
        global:Save-WidgetState -Form $Form
    }.GetNewClosure())
}
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
        $global:GridPreview.Add_Paint({
            param($sender, $paintArgs)
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 100, 150, 255), 2)
            $paintArgs.Graphics.DrawRectangle($pen, 0, 0, $sender.Width - 1, $sender.Height - 1)
        })
        $global:GridPreview.Show()
    }
    $global:GridPreview.Size = New-Object System.Drawing.Size($Width, $Height)
    $global:GridPreview.Location = New-Object System.Drawing.Point($X, $Y)
    if (-not $IsValid) {
        $color = [System.Drawing.Color]::FromArgb(255, 100, 100)  
    }
    elseif ($IsSnapped) {
        $color = [System.Drawing.Color]::FromArgb(100, 255, 100)  
    }
    else {
        $color = [System.Drawing.Color]::FromArgb(255, 200, 100)  
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
