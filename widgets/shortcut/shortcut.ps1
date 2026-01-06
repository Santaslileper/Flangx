# widgets/shortcut/shortcut.ps1
# Shortcut Link Widget - Multi-Instance Support
param([int]$X = -1, [int]$Y = -1, [string]$InstanceId = $null)

# Generate unique instance ID if not provided
if (-not $InstanceId) {
    $InstanceId = (Get-Date -Format "yyyyMMddHHmmssfff") + "_" + (Get-Random -Maximum 9999)
}

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$assetsDir = Join-Path $scriptDir "assets"
if (-not (Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null }

# Use instance-specific config file
$configFileName = "config_$InstanceId.json"
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
    Background = [System.Drawing.Color]::FromArgb(40, 40, 45)
    Foreground = [System.Drawing.Color]::White
    Indicator  = [System.Drawing.Color]::FromArgb(80, 255, 255, 255)
    IconBg     = [System.Drawing.Color]::FromArgb(60, 60, 65)
    HoverBg    = [System.Drawing.Color]::FromArgb(70, 70, 80)
}

# Create Widget Form - Larger default for list
$widgetName = "Shortcuts ($InstanceId)"
$form = New-StandardWidget -Name $widgetName -Width 250 -Height 360 -ConfigPath $configPath -Theme $theme

if ($X -ne -1 -and $Y -ne -1) {
    $form.StartPosition = "Manual"
    $form.Location = New-Object System.Drawing.Point($X, $Y)
}

# Store InstanceId in form tag for reference
$form.Tag = $InstanceId

# Header
$indicator = New-WidgetHeader -Form $form -Theme $theme

$form.Controls.Add($indicator)

# Content Panel (Flow Layout for List)
$panel = New-Object System.Windows.Forms.FlowLayoutPanel
$panel.Dock = "Fill"
$panel.BackColor = "Transparent"
$panel.AutoScroll = $true
$panel.FlowDirection = "TopDown"
$panel.WrapContents = $false
$panel.Padding = New-Object System.Windows.Forms.Padding(10)
$form.Controls.Add($panel)

# State: List of Shortcuts (instance-specific)
$script:Shortcuts = @()

# Load shortcut config
if (Test-Path $configPath) {
    try {
        $json = Get-Content $configPath -Raw | ConvertFrom-Json
        
        # Check if it has "Shortcuts" array
        if ($json.Shortcuts) {
            $script:Shortcuts = $json.Shortcuts
        }
        # Migration: Check for legacy single shortcut fields
        elseif ($json.ShortcutTarget) {
            $script:Shortcuts += @{
                Target    = $json.ShortcutTarget
                Arguments = $json.ShortcutArgs
                Label     = $json.ShortcutLabel
                IconPath  = $json.ShortcutIcon
            }
        }
    }
    catch {}
}

# Helper: Extract and save icon
function Save-IconFromExecutable {
    param([string]$ExePath)
    try {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath)
        $timestamp = Get-Date -Format "yyyyMMddHHmmssfff"
        $outputPath = Join-Path $assetsDir "${fileName}_${timestamp}.png"
        
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($ExePath)
        $bmp = $icon.ToBitmap()
        $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose(); $icon.Dispose()
        return $outputPath
    }
    catch { return $null }
}

# Helper: Save config
function Save-Config {
    if (-not $configPath) { return }
    
    $data = @{
        InstanceId = $InstanceId
        Shortcuts  = $script:Shortcuts
    }
    
    $data | ConvertTo-Json -Depth 4 | Set-Content $configPath
}

# Render Function
function Render-List {
    $panel.SuspendLayout()
    
    # Cleanup old controls
    while ($panel.Controls.Count -gt 0) {
        $c = $panel.Controls[0]
        $panel.Controls.Remove($c)
        $c.Dispose()
    }
    
    # Render Items
    for ($i = 0; $i -lt $script:Shortcuts.Count; $i++) {
        $idx = $i # Capture loop variable
        $sc = $script:Shortcuts[$idx]
        
        # Item Container
        $item = New-Object System.Windows.Forms.Panel
        $item.Width = 210
        $item.Height = 50
        $item.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 5)
        $item.BackColor = $theme.IconBg
        $item.Cursor = [System.Windows.Forms.Cursors]::Hand
        $item.Tag = $idx
        
        # Icon
        $img = New-Object System.Windows.Forms.PictureBox
        $img.Size = New-Object System.Drawing.Size(32, 32)
        $img.Location = New-Object System.Drawing.Point(10, 9)
        $img.SizeMode = "Zoom"
        $img.BackColor = "Transparent"
        $img.Tag = $idx
        
        if ($sc.IconPath -and (Test-Path $sc.IconPath)) {
            try {
                $fs = [System.IO.File]::OpenRead($sc.IconPath)
                $bitmap = [System.Drawing.Image]::FromStream($fs)
                $fs.Close()
                $img.Image = $bitmap
            }
            catch { $img.BackColor = $theme.Indicator } 
        }
        else {
            $img.BackColor = $theme.Indicator
        }
        $item.Controls.Add($img)
        
        # Text
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = if ($sc.Label) { $sc.Label } else { [System.IO.Path]::GetFileNameWithoutExtension($sc.Target) }
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $lbl.ForeColor = $theme.Foreground
        $lbl.AutoSize = $true
        $lbl.Location = New-Object System.Drawing.Point(50, 15)
        $lbl.BackColor = "Transparent"
        $lbl.Tag = $idx
        $item.Controls.Add($lbl)
        
        # Click Handler
        $click = { 
            param($s, $e)
            try {
                $ix = $this.Tag 
                $sObj = $script:Shortcuts[$ix]
                
                if ($e.Button -eq 'Right') { return }
                
                if ($e.Button -eq 'Left') {
                    if ($sObj.Arguments) { 
                        Start-Process -FilePath $sObj.Target -ArgumentList $sObj.Arguments 
                    }
                    else { 
                        Start-Process -FilePath $sObj.Target 
                    }
                }
            }
            catch { [System.Windows.Forms.MessageBox]::Show("Error launching: $_") }
        }.GetNewClosure()
        
        $item.Add_MouseClick($click)
        $img.Add_MouseClick($click)
        $lbl.Add_MouseClick($click)
        
        # Hover
        $item.Add_MouseEnter({ $this.BackColor = $theme.HoverBg }.GetNewClosure())
        $item.Add_MouseLeave({ $this.BackColor = $theme.IconBg }.GetNewClosure())
        
        # Context Menu for Item
        $ctx = New-Object System.Windows.Forms.ContextMenuStrip
        
        $del = $ctx.Items.Add("Remove")
        $del.Tag = $idx
        $del.Add_Click({
                $ix = $this.Tag
                $list = [System.Collections.ArrayList]@($script:Shortcuts)
                if ($ix -ge 0 -and $ix -lt $list.Count) {
                    $list.RemoveAt($ix)
                    $script:Shortcuts = $list.ToArray()
                    Save-Config
                    Render-List
                }
            }.GetNewClosure())
        
        $edit = $ctx.Items.Add("Edit Label...")
        $edit.Tag = $idx
        $edit.Add_Click({
                $ix = $this.Tag
                Add-Type -AssemblyName Microsoft.VisualBasic
                $curr = $script:Shortcuts[$ix].Label
                $new = [Microsoft.VisualBasic.Interaction]::InputBox("Label:", "Edit Label", $curr)
                if ($new -ne $null -and $new -ne "") {
                    $newObj = @{
                        Target    = $script:Shortcuts[$ix].Target
                        Label     = $new
                        IconPath  = $script:Shortcuts[$ix].IconPath
                        Arguments = $script:Shortcuts[$ix].Arguments
                    }
                    $script:Shortcuts[$ix] = $newObj
                    Save-Config
                    Render-List
                }
            }.GetNewClosure())
        
        $editArgs = $ctx.Items.Add("Edit Args...")
        $editArgs.Tag = $idx
        $editArgs.Add_Click({
                $ix = $this.Tag
                Add-Type -AssemblyName Microsoft.VisualBasic
                $curr = $script:Shortcuts[$ix].Arguments
                $new = [Microsoft.VisualBasic.Interaction]::InputBox("Args:", "Edit Arguments", $curr)
                if ($new -ne $null) {
                    $newObj = @{
                        Target    = $script:Shortcuts[$ix].Target
                        Label     = $script:Shortcuts[$ix].Label
                        IconPath  = $script:Shortcuts[$ix].IconPath
                        Arguments = $new
                    }
                    $script:Shortcuts[$ix] = $newObj
                    Save-Config
                }
            }.GetNewClosure())

        $item.ContextMenuStrip = $ctx
        $img.ContextMenuStrip = $ctx
        $lbl.ContextMenuStrip = $ctx

        $panel.Controls.Add($item)
    }
    
    # "Add New" Button
    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = "+ Add Shortcut"
    $addBtn.Width = 210
    $addBtn.Height = 40
    $addBtn.FlatStyle = "Flat"
    $addBtn.BackColor = $theme.Background
    $addBtn.ForeColor = $theme.Indicator
    $addBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $addBtn.Add_Click({
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Filter = "Exe|*.exe|All|*.*"
            if ($dlg.ShowDialog() -eq "OK") {
                $newItem = @{
                    Target    = $dlg.FileName
                    Label     = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
                    Arguments = ""
                    IconPath  = ""
                }
                # Icon
                if ($dlg.FileName -match '\.exe$') {
                    $p = Save-IconFromExecutable $dlg.FileName
                    if ($p) { $newItem.IconPath = $p }
                }
            
                $script:Shortcuts += $newItem
                Save-Config
                Render-List
            }
        })
    $panel.Controls.Add($addBtn)
    
    $panel.ResumeLayout()
}

Render-List

# Cleanup on close
$form.Add_FormClosing({
        # Dispose images
        foreach ($ctrl in $panel.Controls) {
            if ($ctrl -is [System.Windows.Forms.Panel]) {
                foreach ($subCtrl in $ctrl.Controls) {
                    if ($subCtrl -is [System.Windows.Forms.PictureBox] -and $subCtrl.Image) {
                        $subCtrl.Image.Dispose()
                    }
                }
            }
        }
    })

# Enable Drag of form via header
Enable-WidgetDrag -Controls @($form, $indicator) -Form $form -IndicatorPanel $indicator
Enable-WidgetResize -Form $form -IndicatorPanel $indicator

[System.Windows.Forms.Application]::Run($form)