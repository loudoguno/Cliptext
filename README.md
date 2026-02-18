# Cliptext

A lightweight, native macOS clipboard history manager that lives in your menu bar.

Cliptext monitors your clipboard and gives you instant access to your last 10 copied items through a snappy native context menu — triggered by a keyboard shortcut or a click on the menu bar icon.

## Features

- **Instant popup** — ⌃⌥V shows clipboard history at your cursor, just like a context menu
- **Menu bar icon** — click the clipboard icon for the same menu anchored to the menu bar
- **Smart type handling** — text, images (with thumbnails), files (with icons), and rich text
- **Pin items** — hold ⌥ and click to pin an item so it never falls off the list. Pinned items collect into a 📌 Pinned submenu
- **Paste as plain text** — hold ⇧ and click to strip formatting
- **Quick select** — press 1-9 while the menu is open to paste instantly
- **Auto-paste** — selecting an item writes it to the clipboard and simulates ⌘V into the frontmost app
- **Deduplication** — copying the same text twice won't create duplicate entries
- **Services menu** — appears as "Paste from Cliptext" in right-click > Services
- **Start at login** — toggle from the menu to launch automatically
- **Zero UI chrome** — no Dock icon, no windows, no task switcher entry

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission (for auto-paste via simulated ⌘V)

## Build

```bash
git clone https://github.com/loudoguno/Cliptext.git
cd Cliptext
./build.sh
```

This creates `build/Cliptext.app`.

## Install

```bash
# Build and copy to Applications
./build.sh
cp -r build/Cliptext.app /Applications/

# Or just run it directly
open build/Cliptext.app
```

On first launch, Cliptext will ask for Accessibility permission. Grant it in **System Settings > Privacy & Security > Accessibility**.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌃⌥V | Show clipboard history at cursor |
| 1-9 | Quick-select item (while menu is open) |
| ⌥ + click | Pin / unpin an item |
| ⇧ + click | Paste as plain text |
| q | Quit (while menu is open) |

## How It Works

Cliptext polls `NSPasteboard.general.changeCount` every 0.5 seconds (an integer comparison — negligible CPU). When a change is detected, it captures the clipboard contents and adds them to an in-memory ring buffer.

The menu is a native `NSMenu` rendered by the system compositor — identical in look and feel to macOS context menus.

## Architecture

```
Sources/Cliptext/
├── main.swift              — App entry point
├── AppDelegate.swift       — Status item, hotkey, menu, actions, Services provider
├── ClipboardMonitor.swift  — Timer-based polling of pasteboard changes
├── ClipboardItem.swift     — Data model with content type enum
├── ClipboardStore.swift    — Ring buffer with pin support
├── MenuBuilder.swift       — NSMenu construction with alternates
├── PasteSimulator.swift    — Pasteboard write + CGEvent ⌘V simulation
└── Info.plist              — LSUIElement, Services registration
```

## Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus — global hotkey registration without Accessibility permission

## License

MIT
