# core/grid_logic.ps1
# Desktop grid calculation and slot-finding logic
# Pure functions - no UI dependencies

Add-Type -AssemblyName System.Windows.Forms

function global:Get-GridMetrics {
    <#
    .SYNOPSIS
        Calculates grid metrics from desktop icon positions
    .DESCRIPTION
        Analyzes icon positions to determine grid spacing and offsets
    #>
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
    
    # Calculate average icon size
    $avgW = ($IconRects | Measure-Object -Property Width -Average).Average
    $avgH = ($IconRects | Measure-Object -Property Height -Average).Average
    $metrics.AvgWidth = [Math]::Max(50, [int]$avgW)
    $metrics.AvgHeight = [Math]::Max(50, [int]$avgH)
    
    # Get system icon spacing
    $sysX = [System.Windows.Forms.SystemInformation]::IconHorizontalSpacing
    $sysY = [System.Windows.Forms.SystemInformation]::IconVerticalSpacing
    if ($sysX -le 0) { $sysX = $metrics.AvgWidth + 20 }
    if ($sysY -le 0) { $sysY = $metrics.AvgHeight + 20 }
    
    # Heuristic spacing detection from actual icons
    if ($IconRects.Count -gt 1) {
        $Xs = ($IconRects | Select-Object -ExpandProperty X | Sort-Object -Unique)
        $Ys = ($IconRects | Select-Object -ExpandProperty Y | Sort-Object -Unique)
        
        # Find most common X gaps
        $gapsX = @()
        for ($i = 0; $i -lt $Xs.Count - 1; $i++) { 
            $gap = $Xs[$i + 1] - $Xs[$i]
            if ($gap -gt 30) { $gapsX += $gap }
        }
        $commonX = $gapsX | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
        if ($commonX) { $metrics.StepX = [int]$commonX.Name }
        else { $metrics.StepX = $sysX }
        
        # Find most common Y gaps
        $gapsY = @()
        for ($i = 0; $i -lt $Ys.Count - 1; $i++) { 
            $gap = $Ys[$i + 1] - $Ys[$i]
            if ($gap -gt 30) { $gapsY += $gap }
        }
        $commonY = $gapsY | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
        if ($commonY) { $metrics.StepY = [int]$commonY.Name }
        else { $metrics.StepY = $sysY }
    }
    else {
        $metrics.StepX = $sysX
        $metrics.StepY = $sysY
    }
    
    # Calculate grid origin offset
    $metrics.OffsetX = ($IconRects | Measure-Object -Property X -Minimum).Minimum
    $metrics.OffsetY = ($IconRects | Measure-Object -Property Y -Minimum).Minimum
    
    # Normalize offsets to be within one step
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
        # Check intersection
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
    <#
    .SYNOPSIS
        Calculates the snap position for a widget given its current location
    .DESCRIPTION
        Finds the nearest valid grid cell that doesn't overlap an icon
    #>
    param(
        [int]$CurrentX,
        [int]$CurrentY,
        [int]$WidgetWidth,
        [int]$WidgetHeight
    )
    
    $icons = Get-DesktopIconRects
    $metrics = Get-GridMetrics -IconRects $icons
    
    # Grid properties
    $stepX = $metrics.StepX
    $stepY = $metrics.StepY
    $offsetX = $metrics.OffsetX
    $offsetY = $metrics.OffsetY
    
    # Calculate nearest grid column/row index (virtual)
    # We add half step to round to nearest
    $col = [Math]::Round(($CurrentX - $offsetX) / $stepX)
    $row = [Math]::Round(($CurrentY - $offsetY) / $stepY)
    
    # Calculate target pixel coordinates
    $targetX = $offsetX + ($col * $stepX)
    $targetY = $offsetY + ($row * $stepY)
    
    # Center widget relative to the grid cell 
    # (assuming grid lines represent top-left of generic item)
    # But usually we want to align to the icon grid.
    # If the widget is larger than 1 cell, we snap its Top-Left.
    
    # Check current target for overlap
    $isOverlapping = Test-IsOverlappingIcon -X $targetX -Y $targetY -Width $WidgetWidth -Height $WidgetHeight -IconRects $icons
    
    # ----------------------------------------------------
    # NEW: Widget-to-Widget Snap Logic
    # ----------------------------------------------------
    $peers = Get-OtherWidgetRects -ExcludePid $PID
    $snapThreshold = 20
    $peerSnapX = $null
    $peerSnapY = $null
    
    foreach ($peer in $peers) {
        # --- X Axis ---
        # Snap My-Left to Peer-Right (Outer)
        if ([Math]::Abs($CurrentX - ($peer.Right + 10)) -lt $snapThreshold) { $peerSnapX = $peer.Right + 10 } # 10px Gap
        # Snap My-Right to Peer-Left (Outer)
        elseif ([Math]::Abs(($CurrentX + $WidgetWidth) - ($peer.Left - 10)) -lt $snapThreshold) { $peerSnapX = ($peer.Left - 10) - $WidgetWidth }
        # Snap My-Left to Peer-Left (Align)
        elseif ([Math]::Abs($CurrentX - $peer.Left) -lt $snapThreshold) { $peerSnapX = $peer.Left }
        # Snap My-Right to Peer-Right (Align)
        elseif ([Math]::Abs(($CurrentX + $WidgetWidth) - $peer.Right) -lt $snapThreshold) { $peerSnapX = $peer.Right - $WidgetWidth }
        
        # --- Y Axis ---
        # Snap My-Top to Peer-Bottom (Outer)
        if ([Math]::Abs($CurrentY - ($peer.Bottom + 10)) -lt $snapThreshold) { $peerSnapY = $peer.Bottom + 10 }
        # Snap My-Bottom to Peer-Top (Outer)
        elseif ([Math]::Abs(($CurrentY + $WidgetHeight) - ($peer.Top - 10)) -lt $snapThreshold) { $peerSnapY = ($peer.Top - 10) - $WidgetHeight }
        # Snap My-Top to Peer-Top (Align)
        elseif ([Math]::Abs($CurrentY - $peer.Top) -lt $snapThreshold) { $peerSnapY = $peer.Top }
        # Snap My-Bottom to Peer-Bottom (Align)
        elseif ([Math]::Abs(($CurrentY + $WidgetHeight) - $peer.Bottom) -lt $snapThreshold) { $peerSnapY = $peer.Bottom - $WidgetHeight }
    }
    
    # Priority: Peer > Grid
    $finalX = if ($null -ne $peerSnapX) { $peerSnapX } else { $targetX }
    $finalY = if ($null -ne $peerSnapY) { $peerSnapY } else { $targetY }
    
    # Re-check overlap for the proposed final position
    $finalOverlap = Test-IsOverlappingIcon -X $finalX -Y $finalY -Width $WidgetWidth -Height $WidgetHeight -IconRects $icons
    
    if (-not $finalOverlap) {
        return @{ X = [int]$finalX; Y = [int]$finalY; Snapped = $true }
    }
    
    return @{ X = $CurrentX; Y = $CurrentY; Snapped = $false }
}
