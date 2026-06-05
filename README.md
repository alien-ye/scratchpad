# Scratchpad

A lightweight, auto-hiding sidebar scratchpad for Windows — built entirely in PowerShell with WinForms.

![Windows](https://img.shields.io/badge/platform-Windows-blue?logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![License](https://img.shields.io/badge/license-MIT-green)

## Why

Sometimes you just need a place to dump text — a URL, a snippet, a quick thought. Scratchpad gives you two panes:

- **TMP** — throwaway tabs that vanish when you close the window
- **SAVED** — persistent tabs that auto-save every 10 seconds to disk

No install. No dependencies. One script.

## Features

| Feature | Details |
|---------|---------|
| Split pane | TMP (left) + SAVED (right) |
| Auto-hide sidebar | Slides to screen edge when idle, reappears on hover |
| Smooth animation | Easing-based slide transitions (no jarring jumps) |
| Multi-monitor aware | Docks to correct screen edge via `Screen.FromHandle` |
| Pin mode | Click ◉ or Ctrl+P to lock panel visible |
| Hover dwell | 150ms intentional hover required to reveal (no accidental triggers) |
| Drag aware | Auto-hide pauses while user drags/resizes window |
| Always on top | Stays visible over your IDE/browser |
| Minimize to taskbar | Standard window with minimize button |
| Auto-save | Saved tabs persist to `~/.scratchpad/saved/` every 10s |
| Dark theme | Easy on the eyes during long sessions |
| Tab management | Click `+` to add, double-click TMP tab to clear |
| Line ending normalization | Handles LF/CRLF on paste and file load |
| Double-buffered | Reduced flicker during animations |
| Zero config | No settings file, no registry, no admin rights |

## Quick Start

```powershell
# Clone and run
git clone https://github.com/alien-ye/scratchpad.git
cd scratchpad
powershell -ExecutionPolicy Bypass -File scratchpad-window.ps1
```

Or just download `scratchpad-window.ps1` and double-click it (if your execution policy allows).

## Create a Shortcut

1. Right-click desktop → New → Shortcut
2. Target: `powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\scratchpad-window.ps1"`
3. Optional: pin to taskbar or Start menu

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+P` | Pin / Unpin (disable auto-hide) |
| `Ctrl+S` | Save all persistent tabs |
| `Ctrl+W` | Delete current saved tab (and its file) |
| `Ctrl+A` | Select all text in current tab |
| `Ctrl+V` | Paste with automatic line ending normalization |

## Auto-Hide Behavior

The sidebar uses a state machine with three states:

```
┌──────────┐   mouse near edge (150ms dwell)   ┌──────────┐
│   Peek   │ ──────────────────────────────────▶│ Expanded │
│  (5px)   │◀────────────────────────────────── │  (full)  │
└──────────┘   mouse away + unfocused (120ms)   └──────────┘
                                                      │
                                                 Ctrl+P / ◉
                                                      ▼
                                                ┌──────────┐
                                                │  Pinned  │
                                                │ (locked) │
                                                └──────────┘
```

- **Expanded** — fully visible, snapped to right edge
- **Peek** — only 5px visible strip at screen edge
- **Pinned** — always visible, ignores auto-hide

## Architecture

```
┌─────────────────────────────────────────────┐
│  Layout Authority: animTimer (15ms)         │
│  Only component that writes $form.Left      │
├─────────────────────────────────────────────┤
│  State Machine: dockTimer (30ms)            │
│  Sets TargetX → starts animTimer            │
├─────────────────────────────────────────────┤
│  Input: mouse position, focus, drag state   │
│  Strict priority: Pinned > Focus > Hover    │
└─────────────────────────────────────────────┘
```

## Data Storage

```
~/.scratchpad/
└── saved/
    ├── Jun05.txt
    ├── Jun05a.txt
    └── Jun06.txt
```

- Saved tabs are plain `.txt` files named by date
- Adding a new saved tab when one already exists for today appends a suffix (a, b, c...)
- TMP tabs are never written to disk

## Customization

All visual settings live at the top of the script:

```powershell
# Colors
$bgDark       = [System.Drawing.Color]::FromArgb(30, 30, 30)
$bgEditor     = [System.Drawing.Color]::FromArgb(45, 45, 48)
$fgText       = [System.Drawing.Color]::FromArgb(220, 220, 220)

# Editor (in New-EditorTextBox)
$tb.Font = New-Object System.Drawing.Font("Cascadia Code, Consolas", 11)
$tb.WordWrap = $true

# Sidebar timing
HideDelayMax = 4    # ~120ms before auto-hide
HoverDwellMax = 5   # ~150ms hover to reveal
```

## Requirements

- Windows 7+ with .NET Framework 4.5+
- PowerShell 5.1 or later (pre-installed on Windows 10/11)
- No external modules or dependencies

## License

[MIT](LICENSE)
