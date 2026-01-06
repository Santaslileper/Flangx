function global:New-WidgetContextMenu {
    param(
        [System.Windows.Forms.Form]$Form,
        [System.Windows.Forms.Panel]$IndicatorPanel
    )
    $ctx = New-Object System.Windows.Forms.ContextMenuStrip
    $ctx.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $ctx.ForeColor = [System.Drawing.Color]::White
    $ctx.ShowImageMargin = $true 
    $itemLock = $ctx.Items.Add("Lock Position")
    $itemLock.Add_Click({
            $curr = $Form.Tag.IsLocked
            $Form.Tag.IsLocked = -not $curr
            $color = if ($Form.Tag.IsLocked) { [System.Drawing.Color]::Gray } else { [System.Drawing.Color]::Transparent }
            if ($IndicatorPanel) { $IndicatorPanel.BackColor = $color }
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    $itemSnap = $ctx.Items.Add("Snap to Grid")
    $itemSnap.Add_Click({
            $curr = $Form.Tag.SnapToGrid
            $Form.Tag.SnapToGrid = -not $curr
            global:Save-WidgetState -Form $Form
        }.GetNewClosure())
    $menuResize = New-Object System.Windows.Forms.ToolStripMenuItem("Resize")
    $sizes = @(
        @{ Label = "1x1 (Small)"; W = 75; H = 75 }
        @{ Label = "2x1 (Wide)"; W = 150; H = 75 }
        @{ Label = "3x3 (Medium)"; W = 225; H = 225 }
        @{ Label = "3x4 (Large)"; W = 225; H = 300 }
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
    $itemTop = $ctx.Items.Add("Always on Top")
    $itemTop.Add_Click({
            $curr = $Form.TopMost
            $Form.TopMost = -not $curr
            $Form.Tag.TopMost = $Form.TopMost
            global:Save-WidgetState -Form $Form
            $itemTop.Checked = $Form.TopMost
        }.GetNewClosure())
    $sep = $ctx.Items.Add("-")
    $itemExit = $ctx.Items.Add("Exit")
    $itemExit.Add_Click({ $Form.Close() })
    $ctx.Add_Opening({
            $isLocked = $Form.Tag.IsLocked
            $itemLock.Text = if ($isLocked) { "Unlock Position" } else { "Lock Position" }
            $itemLock.Checked = $isLocked
            $itemSnap.Visible = -not $isLocked
            $itemTop.Visible = -not $isLocked
            $sep.Visible = $true
            foreach ($item in $ctx.Items) {
                if ($item.Text -eq "Manage Widgets") {
                    $item.Visible = -not $isLocked
                }
            }
            $itemSnap.Checked = $Form.Tag.SnapToGrid
            $itemTop.Checked = $Form.TopMost
        }.GetNewClosure())
    Apply-AppleMenuStyle -Menu $ctx
    return $ctx
}
