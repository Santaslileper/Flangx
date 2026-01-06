# core/widget_context_menu.ps1
# Context menu generation

function global:New-WidgetContextMenu {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Panel]$IndicatorPanel
    )
    
    $ctx = New-Object System.Windows.Forms.ContextMenuStrip
    $ctx.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $ctx.ForeColor = [System.Drawing.Color]::White
    $ctx.ShowImageMargin = $true 
    
    # 1. Lock/Unlock
    $itemLock = $ctx.Items.Add("Lock Position")
    $itemLock.Add_Click({
            $curr = $Form.Tag.IsLocked
            $Form.Tag.IsLocked = -not $curr
        
            $color = if ($Form.Tag.IsLocked) { [System.Drawing.Color]::Gray } else { [System.Drawing.Color]::Transparent }
            if ($IndicatorPanel) { $IndicatorPanel.BackColor = $color }
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    
    # 2. Snap to Grid
    $itemSnap = $ctx.Items.Add("Snap to Grid")
    $itemSnap.Add_Click({
            $curr = $Form.Tag.SnapToGrid
            $Form.Tag.SnapToGrid = -not $curr
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())

    # 3. Resize
    $menuResize = New-Object System.Windows.Forms.ToolStripMenuItem("Resize")
    $sizes = @(
        @{ Label = "1x1 (Small)"; W = 75; H = 75 }
        @{ Label = "1x2 (Tall)"; W = 75; H = 150 }
        @{ Label = "2x1 (Wide)"; W = 150; H = 75 }
        @{ Label = "2x2 (Medium)"; W = 150; H = 150 }
        @{ Label = "3x3 (Large)"; W = 225; H = 225 }
    )
    foreach ($s in $sizes) {
        $si = $menuResize.DropDownItems.Add($s.Label)
        $si.Tag = $s
        $si.Add_Click({
                param($currSender, $e)
                $sz = $currSender.Tag
                $Form.Size = New-Object System.Drawing.Size($sz.W, $sz.H)
                global:Save-WidgetState -Form $Form
            }.GetNewClosure())
    }
    $ctx.Items.Add($menuResize) | Out-Null
    
    # 4. Always on Top
    $itemTop = $ctx.Items.Add("Always on Top")
    $itemTop.Add_Click({
            $curr = $Form.TopMost
            $Form.TopMost = -not $curr
            $Form.Tag.TopMost = $Form.TopMost
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    
    $sep = $ctx.Items.Add("-")
    
    # Exit
    $itemExit = $ctx.Items.Add("Exit")
    $itemExit.Add_Click({ $Form.Close() })
    
    # Dynamic Visibility on Open
    $ctx.Add_Opening({
            $isLocked = $Form.Tag.IsLocked
        
            # Lock Item Text
            $itemLock.Text = if ($isLocked) { "Unlock Position" } else { "Lock Position" }
            $itemLock.Checked = $isLocked
        
            # Hide/Show others based on Lock state
            $itemSnap.Visible = -not $isLocked
            $itemTop.Visible = -not $isLocked
            $sep.Visible = $true
        
            # Launcher special "Manage" menu?
            # Check if there are other items (like Manage Widgets in Launcher)
            # We iterate generic items if we want, but usually specific visibility is safer
            foreach ($item in $ctx.Items) {
                if ($item.Text -eq "Manage Widgets") {
                    $item.Visible = -not $isLocked
                }
            }
        
            # Check marks
            $itemSnap.Checked = $Form.Tag.SnapToGrid
            $itemTop.Checked = $Form.TopMost
        }.GetNewClosure())
    
    # Apple Styling
    Apply-AppleMenuStyle -Menu $ctx

    return $ctx
}
