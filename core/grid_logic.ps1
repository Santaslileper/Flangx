# core/grid_logic.ps1

Add-Type -AssemblyName System.Windows.Forms

function global:Get-GridMetrics {
    param([System.Collections.Generic.List[System.Drawing.Rectangle]]$IconRects)
    $metrics = @{
        AvgWidth  = 75
        AvgHeight = 75
        StepX     = 100
        StepY     = 100
        OffsetX   = 0
        OffsetY   = 0
    }
    if ($IconRects.Count -eq 0) { return $metrics }
    $avgW = ($IconRects | Measure-Object -Property Width -Average).Average
    $avgH = ($IconRects | Measure-Object -Property Height -Average).Average
    $metrics.AvgWidth = [Math]::Max(50, [int]$avgW)
    $metrics.AvgHeight = [Math]::Max(50, [int]$avgH)
    $sysX = [System.Windows.Forms.SystemInformation]::IconHorizontalSpacing
    $sysY = [System.Windows.Forms.SystemInformation]::IconVerticalSpacing
    if ($sysX -le 0) { $sysX = $metrics.AvgWidth + 20 }
    if ($sysY -le 0) { $sysY = $metrics.AvgHeight + 20 }
    if ($IconRects.Count -gt 1) {
        $Xs = ($IconRects | Select-Object -ExpandProperty X | Sort-Object -Unique)
        $Ys = ($IconRects | Select-Object -ExpandProperty Y | Sort-Object -Unique)
        $gapsX = @()
        for ($i = 0; $i -lt $Xs.Count - 1; $i++) { 
            $gap = $Xs[$i + 1] - $Xs[$i]
            if ($gap -gt 30) { $gapsX += $gap }
        }
        $commonX = $gapsX | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
        if ($commonX -and [int]$commonX.Name -le 200) { $metrics.StepX = [int]$commonX.Name }
        else { $metrics.StepX = $sysX }
        $gapsY = @()
        for ($i = 0; $i -lt $Ys.Count - 1; $i++) { 
            $gap = $Ys[$i + 1] - $Ys[$i]
            if ($gap -gt 30) { $gapsY += $gap }
        }
        $commonY = $gapsY | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
        if ($commonY -and [int]$commonY.Name -le 200) { $metrics.StepY = [int]$commonY.Name }
        else { $metrics.StepY = $sysY }
    }
    else {
        $metrics.StepX = $sysX
        $metrics.StepY = $sysY
    }
    $metrics.OffsetX = ($IconRects | Measure-Object -Property X -Minimum).Minimum
    $metrics.OffsetY = ($IconRects | Measure-Object -Property Y -Minimum).Minimum
    while ($metrics.OffsetX -ge $metrics.StepX) { $metrics.OffsetX -= $metrics.StepX }
    while ($metrics.OffsetY -ge $metrics.StepY) { $metrics.OffsetY -= $metrics.StepY }
    return $metrics
}

function global:Test-IsOverlappingIcon {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [System.Collections.Generic.List[System.Drawing.Rectangle]]$IconRects
    )
    foreach ($icon in $IconRects) {
        if ($icon.Left -lt ($X + $Width) -and 
            ($icon.Left + $icon.Width) -gt $X -and
            $icon.Top -lt ($Y + $Height) -and 
            ($icon.Top + $icon.Height) -gt $Y) {
            return $true
        }
    }
    return $false
}

function global:Get-SnapPosition {
    param(
        [int]$CurrentX,
        [int]$CurrentY,
        [int]$WidgetWidth,
        [int]$WidgetHeight
    )
    $icons = Get-DesktopIconRects
    $metrics = Get-GridMetrics -IconRects $icons
    $stepX = $metrics.StepX
    $stepY = $metrics.StepY
    $offsetX = $metrics.OffsetX
    $offsetY = $metrics.OffsetY
    $col = [Math]::Round(($CurrentX - $offsetX) / $stepX)
    $row = [Math]::Round(($CurrentY - $offsetY) / $stepY)
    $targetX = $offsetX + ($col * $stepX)
    $targetY = $offsetY + ($row * $stepY)
    
    $peers = Get-OtherWidgetRects -ExcludePid $PID
    $snapThreshold = 20
    $peerSnapX = $null
    $peerSnapY = $null
    
    foreach ($peer in $peers) {
        # Normalize with explicit casting
        $pX = if ($null -ne $peer.X) { [int]$peer.X } else { [int]$peer.Left }
        $pY = if ($null -ne $peer.Y) { [int]$peer.Y } else { [int]$peer.Top }
        $pW = [int]$peer.Width
        $pH = [int]$peer.Height
        $pRight  = $pX + $pW
        $pBottom = $pY + $pH

        # --- X Axis Snapping (Left/Right) ---
        # 1. Snap Left-to-Right (Stacking): My Left touches Peer Right + Gap
        if ([Math]::Abs($CurrentX - ($pRight + 10)) -lt $snapThreshold) { 
            $peerSnapX = $pRight + 10 
        }
        # 2. Snap Right-to-Left (Stacking): My Right touches Peer Left - Gap
        elseif ([Math]::Abs(($CurrentX + $WidgetWidth) - ($pX - 10)) -lt $snapThreshold) { 
            $peerSnapX = ($pX - 10) - $WidgetWidth 
        }
        # 3. Snap Left-to-Left (Aligning): My Left aligns with Peer Left
        elseif ([Math]::Abs($CurrentX - $pX) -lt $snapThreshold) { 
            $peerSnapX = $pX 
        }
        # 4. Snap Right-to-Right (Aligning): My Right aligns with Peer Right
        elseif ([Math]::Abs(($CurrentX + $WidgetWidth) - $pRight) -lt $snapThreshold) { 
            $peerSnapX = $pRight - $WidgetWidth 
        }

        # --- Y Axis Snapping (Up/Down) ---
        # 1. Snap Top-to-Bottom (Stacking): My Top touches Peer Bottom + Gap
        if ([Math]::Abs($CurrentY - ($pBottom + 10)) -lt $snapThreshold) { 
            $peerSnapY = $pBottom + 10 
        }
        # 2. Snap Bottom-to-Top (Stacking): My Bottom touches Peer Top - Gap
        elseif ([Math]::Abs(($CurrentY + $WidgetHeight) - ($pY - 10)) -lt $snapThreshold) { 
            $peerSnapY = ($pY - 10) - $WidgetHeight 
        }
        # 3. Snap Top-to-Top (Aligning): My Top aligns with Peer Top
        elseif ([Math]::Abs($CurrentY - $pY) -lt $snapThreshold) { 
            $peerSnapY = $pY 
        }
        # 4. Snap Bottom-to-Bottom (Aligning): My Bottom aligns with Peer Bottom
        elseif ([Math]::Abs(($CurrentY + $WidgetHeight) - $pBottom) -lt $snapThreshold) { 
            $peerSnapY = $pBottom - $WidgetHeight 
        }
    }
    
    $finalX = if ($null -ne $peerSnapX) { $peerSnapX } else { $targetX }
    $finalY = if ($null -ne $peerSnapY) { $peerSnapY } else { $targetY }
    
    $overlapFound = $false
    foreach ($peer in $peers) {
        $pX = if ($null -ne $peer.X) { [int]$peer.X } else { [int]$peer.Left }
        $pY = if ($null -ne $peer.Y) { [int]$peer.Y } else { [int]$peer.Top }
        $pW = [int]$peer.Width
        $pH = [int]$peer.Height
        if ($pX -lt ($finalX + $WidgetWidth) -and 
            ($pX + $pW) -gt $finalX -and
            $pY -lt ($finalY + $WidgetHeight) -and 
            ($pY + $pH) -gt $finalY) {
            $overlapFound = $true
            break
        }
    }
    
    if ($overlapFound) {
        $overlapGrid = $false
        foreach ($peer in $peers) {
            $pX = if ($null -ne $peer.X) { [int]$peer.X } else { [int]$peer.Left }
            $pY = if ($null -ne $peer.Y) { [int]$peer.Y } else { [int]$peer.Top }
            $pW = [int]$peer.Width
            $pH = [int]$peer.Height
            if ($pX -lt ($targetX + $WidgetWidth) -and 
                ($pX + $pW) -gt $targetX -and
                $pY -lt ($targetY + $WidgetHeight) -and 
                ($pY + $pH) -gt $targetY) {
                $overlapGrid = $true
                break
            }
        }
        if (-not $overlapGrid) {
            $finalX = $targetX
            $finalY = $targetY
        }
        else {
            return @{ X = $CurrentX; Y = $CurrentY; Snapped = $false }
        }
    }
    
    $finalOverlapIcon = Test-IsOverlappingIcon -X $finalX -Y $finalY -Width $WidgetWidth -Height $WidgetHeight -IconRects $icons
    if (-not $finalOverlapIcon) {
        return @{ X = [int]$finalX; Y = [int]$finalY; Snapped = $true }
    }
    return @{ X = $CurrentX; Y = $CurrentY; Snapped = $false }
}
