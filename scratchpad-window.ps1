Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scratchDir = "$env:USERPROFILE\.scratchpad"
$savedDir = "$scratchDir\saved"
if (!(Test-Path $scratchDir)) { New-Item -ItemType Directory -Path $scratchDir | Out-Null }
if (!(Test-Path $savedDir)) { New-Item -ItemType Directory -Path $savedDir | Out-Null }

# --- Colors (modern dark theme) ---
$bgDark       = [System.Drawing.Color]::FromArgb(30, 30, 30)
$bgPanel      = [System.Drawing.Color]::FromArgb(40, 40, 40)
$bgEditor     = [System.Drawing.Color]::FromArgb(45, 45, 48)
$fgText       = [System.Drawing.Color]::FromArgb(220, 220, 220)
$accentTmp    = [System.Drawing.Color]::FromArgb(255, 183, 77)   # warm amber
$accentSaved  = [System.Drawing.Color]::FromArgb(100, 181, 246)  # soft blue

# --- Factory: single place to configure all editor textboxes ---
function New-EditorTextBox {
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.Dock = "Fill"
    $tb.WordWrap = $true
    $tb.ScrollBars = "Vertical"
    $tb.Font = New-Object System.Drawing.Font("Cascadia Code, Consolas", 11)
    $tb.AcceptsTab = $true
    $tb.BackColor = $bgEditor
    $tb.ForeColor = $fgText
    $tb.BorderStyle = "None"
    # Intercept paste to normalize line endings (LF -> CRLF)
    $tb.Add_KeyDown({
        if ($_.Control -and $_.KeyCode -eq "V") {
            if ([System.Windows.Forms.Clipboard]::ContainsText()) {
                $text = [System.Windows.Forms.Clipboard]::GetText()
                $text = $text -replace "`r`n", "`n" -replace "`n", "`r`n"
                $this.SelectedText = $text
                $_.Handled = $true
                $_.SuppressKeyPress = $true
            }
        }
        if ($_.Control -and $_.KeyCode -eq "A") {
            $this.SelectAll()
            $_.Handled = $true
            $_.SuppressKeyPress = $true
        }
    })
    return $tb
}

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "  Scratchpad"
$form.Size = New-Object System.Drawing.Size(480, 520)
$form.MinimumSize = New-Object System.Drawing.Size(320, 280)
$form.TopMost = $true
$form.StartPosition = "Manual"
$form.Location = New-Object System.Drawing.Point(([System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.X + [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width - 500), 50)
$form.FormBorderStyle = "Sizable"
$form.MinimizeBox = $false
$form.MaximizeBox = $false
$form.ShowInTaskbar = $false
$form.Opacity = 0.97
$form.BackColor = $bgDark
$form.ForeColor = $fgText
$form.KeyPreview = $true
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
# Double-buffer to reduce flicker during animation
$form.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"NonPublic,Instance").SetValue($form, $true, $null)

# --- SplitContainer ---
$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = "Fill"
$split.Orientation = "Vertical"
$split.BackColor = $bgDark
$split.Panel1.BackColor = $bgPanel
$split.Panel2.BackColor = $bgPanel
$split.SplitterWidth = 3

# --- Labels ---
$lblTmp = New-Object System.Windows.Forms.Label
$lblTmp.Text = "  TMP  (lost on close)"
$lblTmp.Dock = "Top"
$lblTmp.Height = 26
$lblTmp.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$lblTmp.ForeColor = $accentTmp
$lblTmp.BackColor = $bgPanel
$lblTmp.TextAlign = "MiddleLeft"
$lblTmp.Padding = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)

$lblSaved = New-Object System.Windows.Forms.Label
$lblSaved.Text = "  SAVED"
$lblSaved.Dock = "Top"
$lblSaved.Height = 26
$lblSaved.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$lblSaved.ForeColor = $accentSaved
$lblSaved.BackColor = $bgPanel
$lblSaved.TextAlign = "MiddleLeft"
$lblSaved.Padding = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)

# --- TMP TabControl (left) ---
$tmpTabs = New-Object System.Windows.Forms.TabControl
$tmpTabs.Dock = "Fill"
$tmpTabs.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$tmpTabs.Padding = New-Object System.Drawing.Point(12, 4)

# Create 2 default tmp tabs
1..2 | ForEach-Object {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = " "
    $tab.BackColor = $bgEditor
    $tb = New-EditorTextBox
    $tab.Controls.Add($tb)
    $tmpTabs.TabPages.Add($tab)
}

# "+" for tmp
$tmpPlus = New-Object System.Windows.Forms.TabPage
$tmpPlus.Text = " + "
$tmpTabs.TabPages.Add($tmpPlus)

$script:tmpCount = 2
$tmpTabs.Add_SelectedIndexChanged({
    if ($tmpTabs.SelectedTab.Text -eq " + ") {
        $script:tmpCount++
        $tab = New-Object System.Windows.Forms.TabPage
        $tab.Text = " "
        $tab.BackColor = $bgEditor
        $tb = New-EditorTextBox
        $tab.Controls.Add($tb)
        $tmpTabs.TabPages.Remove($tmpPlus)
        $tmpTabs.TabPages.Add($tab)
        $tmpTabs.TabPages.Add($tmpPlus)
        $tmpTabs.SelectedTab = $tab
    }
})

$tmpTabs.Add_MouseDoubleClick({
    $current = $tmpTabs.SelectedTab
    if ($current -and $current.Text -ne " + ") {
        $current.Controls[0].Text = ""
    }
})

# --- SAVED TabControl (right) ---
$savedTabs = New-Object System.Windows.Forms.TabControl
$savedTabs.Dock = "Fill"
$savedTabs.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$savedTabs.Padding = New-Object System.Drawing.Point(12, 4)

$script:savedTextBoxes = @()

function Add-SavedTab($tabName, $filePath) {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = $tabName
    $tab.BackColor = $bgEditor
    $tb = New-EditorTextBox
    $tb.Tag = $filePath
    if (Test-Path $filePath) {
        $content = [System.IO.File]::ReadAllText($filePath)
        $tb.Text = $content -replace "`r`n", "`n" -replace "`n", "`r`n"
    }
    $tab.Controls.Add($tb)
    $savedTabs.TabPages.Add($tab)
    $script:savedTextBoxes += $tb
}

# Load saved tabs from directory
$existingFiles = Get-ChildItem $savedDir -Filter "*.txt" | Sort-Object Name
if ($existingFiles.Count -eq 0) {
    $initName = (Get-Date).ToString("MMMdd", [System.Globalization.CultureInfo]::InvariantCulture)
    Add-SavedTab $initName (Join-Path $savedDir "$initName.txt")
} else {
    foreach ($f in $existingFiles) {
        $tabName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        Add-SavedTab $tabName $f.FullName
    }
}

# "+" for saved
$savedPlus = New-Object System.Windows.Forms.TabPage
$savedPlus.Text = " + "
$savedTabs.TabPages.Add($savedPlus)

$savedTabs.Add_SelectedIndexChanged({
    if ($savedTabs.SelectedTab.Text -eq " + ") {
        $base = (Get-Date).ToString("MMMdd", [System.Globalization.CultureInfo]::InvariantCulture)
        $filePath = Join-Path $savedDir "$base.txt"
        $suffix = ""
        $i = 0
        while (Test-Path $filePath) {
            $i++
            $suffix = [char](96 + $i)
            $filePath = Join-Path $savedDir "$base$suffix.txt"
        }
        $tabName = "$base$suffix"
        Add-SavedTab $tabName $filePath
        $savedTabs.TabPages.Remove($savedPlus)
        $savedTabs.TabPages.Add($savedPlus)
        $savedTabs.SelectedIndex = $savedTabs.TabPages.Count - 2
    }
})

# --- Save function ---
$script:saveAll = {
    foreach ($tb in $script:savedTextBoxes) {
        [System.IO.File]::WriteAllText($tb.Tag, $tb.Text)
    }
}

# --- Auto-save (every 10 seconds) ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 10000
$timer.Add_Tick({ & $script:saveAll })
$timer.Start()

# --- Status bar for save feedback ---
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusBar.BackColor = $bgDark
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready"
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$statusBar.Items.Add($statusLabel) | Out-Null
$form.Controls.Add($statusBar)

# =========================
# SIDEBAR CORE STATE MODEL
# =========================
$script:sidebar = @{
    State        = "Expanded"   # Expanded / Peek / Pinned
    TargetX      = 0
    PeekWidth    = 5
    HideDelay    = 0
    HideDelayMax = 4            # ticks at 30ms = ~120ms before hide
    HoverDwell   = 0
    HoverDwellMax = 20          # ticks at 30ms = ~600ms dwell before open    IsDragging   = $false
}

# --- Single animation timer (created ONCE, never recreated) ---
$script:animTimer = New-Object System.Windows.Forms.Timer
$script:animTimer.Interval = 15
$script:animTimer.Add_Tick({
    try {
        $dx = $script:sidebar.TargetX - $form.Left
        if ([Math]::Abs($dx) -le 2) {
            $form.Left = $script:sidebar.TargetX
            $script:animTimer.Stop()
            return
        }
        $form.Left += [int]($dx * 0.22)
    } catch { }
})

# --- Drag detection (pause docking during user drag) ---
$form.Add_ResizeBegin({ $script:sidebar.IsDragging = $true })
$form.Add_ResizeEnd({ $script:sidebar.IsDragging = $false })
$form.Add_Move({
    # If animTimer is not running and state is Expanded/Pinned, user is dragging
    if (-not $script:animTimer.Enabled -and $script:sidebar.State -ne "Peek") {
        $script:sidebar.IsDragging = $true
    }
})
$form.Add_Activated({ $script:sidebar.IsDragging = $false })

# --- Sidebar behavior timer (30ms poll, strict priority logic) ---
$dockTimer = New-Object System.Windows.Forms.Timer
$dockTimer.Interval = 30

$dockTimer.Add_Tick({
    try {
        # Skip if pinned or user is dragging
        if ($script:sidebar.State -eq "Pinned") { return }
        if ($script:sidebar.IsDragging) { return }

        $screen = [System.Windows.Forms.Screen]::FromHandle($form.Handle)
        $wa = $screen.WorkingArea
        $mouse = [System.Windows.Forms.Cursor]::Position
        $edgeX = $wa.X + $wa.Width
        $expandedX = $edgeX - $form.Width
        $peekX = $edgeX - $script:sidebar.PeekWidth
        $safeZone = [System.Drawing.Rectangle]::Inflate($form.Bounds, 50, 30)
        $mouseInside = $safeZone.Contains($mouse)

        if ($script:sidebar.State -eq "Peek") {
            # Hover dwell: 2px hot zone + 600ms sustained hover to expand
            $distance = $edgeX - $mouse.X
            $intentToOpen = ($distance -lt 2) -and ($mouse.Y -ge $form.Top) -and ($mouse.Y -le ($form.Top + $form.Height))
            if ($intentToOpen) {
                $script:sidebar.HoverDwell++
                if ($script:sidebar.HoverDwell -ge $script:sidebar.HoverDwellMax) {
                    $script:sidebar.State = "Expanded"
                    $script:sidebar.TargetX = $expandedX
                    $script:sidebar.HoverDwell = 0
                    $script:sidebar.HideDelay = 0
                    $script:animTimer.Start()
                }
            } else {
                $script:sidebar.HoverDwell = 0
            }
        } else {
            # State = Expanded
            # PRIORITY 3: Mouse inside safe zone OR focused → stay
            if ($mouseInside -or $form.ContainsFocus) {
                $script:sidebar.HideDelay = 0
                return
            }
            # PRIORITY 4: Mouse outside → delay then peek
            $script:sidebar.HideDelay++
            if ($script:sidebar.HideDelay -ge $script:sidebar.HideDelayMax) {
                $script:sidebar.State = "Peek"
                $script:sidebar.TargetX = $peekX
                $script:sidebar.HideDelay = 0
                $script:animTimer.Start()
            }
        }
    } catch {
        # Silently ignore
    }
})

$dockTimer.Start()

# --- Keyboard shortcuts ---
$form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq "S") {
        & $script:saveAll
        $statusLabel.Text = "Saved at $((Get-Date).ToString('HH:mm:ss'))"
        $_.Handled = $true
        $_.SuppressKeyPress = $true
    }
    if ($_.Control -and $_.KeyCode -eq "W") {
        $current = $savedTabs.SelectedTab
        if ($current -and $current.Text -ne " + ") {
            $tb = $current.Controls[0]
            if (Test-Path $tb.Tag) { Remove-Item $tb.Tag -Force }
            $script:savedTextBoxes = $script:savedTextBoxes | Where-Object { $_ -ne $tb }
            $savedTabs.TabPages.Remove($current)
        }
        $_.Handled = $true
        $_.SuppressKeyPress = $true
    }
    if ($_.Control -and $_.KeyCode -eq "P") {
        & $script:togglePin
        $_.Handled = $true
        $_.SuppressKeyPress = $true
    }
})

# --- On close: save persistent, tmp is gone ---
$form.Add_FormClosing({
    $timer.Stop()
    & $script:saveAll
})

# --- Pin button (inline in status bar, next to window controls) ---
$pinBtn = New-Object System.Windows.Forms.ToolStripButton
$pinBtn.Text = [string][char]0x25C9  # ◉
$pinBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$pinBtn.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$pinBtn.Alignment = "Right"
$pinBtn.ToolTipText = "Pin / Unpin (Ctrl+P)"
$pinBtn.Add_Click({ & $script:togglePin })
$statusBar.Items.Add($pinBtn) | Out-Null

# Update togglePin to use ToolStripButton
$script:togglePin = {
    if ($script:sidebar.State -eq "Pinned") {
        $script:sidebar.State = "Expanded"
        $pinBtn.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
        $statusLabel.Text = "Auto-hide ON"
    } else {
        $screen = [System.Windows.Forms.Screen]::FromHandle($form.Handle)
        $script:sidebar.TargetX = $screen.WorkingArea.X + $screen.WorkingArea.Width - $form.Width
        $script:animTimer.Start()
        $script:sidebar.State = "Pinned"
        $pinBtn.ForeColor = $accentTmp
        $statusLabel.Text = "Pinned"
    }
}

# --- Layout ---
$split.Panel1.Controls.Add($tmpTabs)
$split.Panel1.Controls.Add($lblTmp)
$split.Panel2.Controls.Add($savedTabs)
$split.Panel2.Controls.Add($lblSaved)
$form.Add_Shown({
    $split.SplitterDistance = [int]($split.Width / 2)
})
$form.Controls.Add($split)
$form.ShowDialog()
