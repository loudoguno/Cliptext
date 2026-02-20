# Project Handoff

**Project**: Cliptext
**Location**: ~/code/loudoguno/Cliptext
**Repo**: https://github.com/loudoguno/Cliptext
**Date**: 2026-02-19
**Milestone**: 001 - v1-working-app

---

## Goal
Lightweight native macOS clipboard history manager that lives in the menu bar. Shows last 10 items in a context menu popup, handles text/images/files/rich text, feels as snappy as the native macOS context menu.

## Current Progress

### Completed
- [x] Core clipboard monitoring (0.5s polling of NSPasteboard.changeCount)
- [x] Menu bar icon (SF Symbol "clipboard", template image)
- [x] ⌃⌥V hotkey via KeyboardShortcuts package
- [x] Right ⌘+V trigger via CGEventTap (distinguishes left/right Command)
- [x] NSMenu popup at cursor position (native context menu feel)
- [x] Text, image (32px thumbnail), file (Finder icon), rich text support
- [x] Pinned items — ⌥+click to pin, 📌 submenu when multiple pinned
- [x] Paste as plain text — ⇧+click strips formatting
- [x] Quick-select with number keys 1-9
- [x] Auto-paste via CGEvent ⌘V simulation
- [x] Focus-aware paste — captures target app via AX API before menu opens
- [x] Deduplication of consecutive identical copies
- [x] Start at login toggle (SMAppService)
- [x] Services menu registration ("Paste from Cliptext")
- [x] LSUIElement (no Dock icon, no Cmd+Tab)
- [x] Build script with auto TCC permission reset
- [x] README, LICENSE (MIT), pushed to GitHub
- [x] Added to cc-anon-presentation/projects.md
- [x] Research doc on macOS overlay window types (docs/macos-overlay-windows.md)

### Known Issues
- [ ] Paste doesn't work into non-activating panels (Raycast Notes, Spotlight, Alfred)
- [ ] Every rebuild invalidates Accessibility permission (unsigned binary)
- [ ] README doesn't document right ⌘+V shortcut yet

### Pending / Future
- [ ] AX API paste for non-activating panels (see docs/macos-overlay-windows.md)
- [ ] Code signing to avoid TCC resets on rebuild
- [ ] Persistent history across app restarts (opt-in)
- [ ] Search/filter in menu
- [ ] Transform paste (uppercase, lowercase, URL encode)
- [ ] Sensitive app exclusion (password managers)
- [ ] Settings window (SwiftUI) for history size, shortcut customization

## What Worked
- Pure AppKit NSMenu for the popup — instant, identical to native context menus
- KeyboardShortcuts SPM package — clean global hotkey without rolling own Carbon code
- CGEventTap with NX_DEVICERCMDKEYMASK (0x10) to distinguish right vs left Command
- AX API (`AXUIElementCreateSystemWide` + `kAXFocusedApplicationAttribute`) to capture focused app before menu opens — fixes paste into accessory apps like Slidepad
- SPM executable target + manual .app bundle creation from CLI (no Xcode GUI needed)

## What Didn't Work
- `CGEvent.postToPid()` — silently fails on modern macOS, unreliable for paste simulation
- `NSRunningApplication.activate()` + CGEvent for non-activating panels (Raycast Notes) — the panel uses `CPSStealKeyFocus` which is a separate WindowServer pathway from CGEvent routing
- TCC Accessibility permission persisting across rebuilds — unsigned binaries get a new hash each build, invalidating the permission entry

## Next Steps (in order)
1. Update README with right ⌘+V shortcut documentation
2. Investigate AX API approach for pasting into non-activating panels
3. Code sign the binary (ad-hoc signing at minimum) to stabilize TCC permissions during development
4. Consider persistent history (Codable + JSON in Application Support)

## Key Files
- `Sources/Cliptext/AppDelegate.swift` — Central orchestrator: status item, hotkeys, CGEventTap, menu, all actions
- `Sources/Cliptext/PasteSimulator.swift` — Clipboard write + focus capture + CGEvent ⌘V simulation
- `Sources/Cliptext/ClipboardMonitor.swift` — Timer polling NSPasteboard.changeCount
- `Sources/Cliptext/ClipboardItem.swift` — Data model (Content enum, menuTitle, menuImage)
- `Sources/Cliptext/ClipboardStore.swift` — Ring buffer with pin support
- `Sources/Cliptext/MenuBuilder.swift` — NSMenu construction with alternates for pin/plain-text
- `Sources/Cliptext/Info.plist` — LSUIElement, NSServices registration
- `docs/macos-overlay-windows.md` — Research on NSPanel types and CGEvent routing limitations
- `build.sh` — Build + bundle + TCC reset script

## Architecture
```
SPM executable (no Xcode project needed)
├── Package.swift (KeyboardShortcuts dependency)
├── Sources/Cliptext/ (7 Swift files + Info.plist)
├── build.sh → build/Cliptext.app (manual .app bundle)
└── docs/ (research, handoffs)
```

## Notes
- Old ClipHistory directory has been deleted, only Cliptext exists
- App was also added to `~/code/loudoguno/cc-anon-presentation/projects.md`
- The plan file is at `~/.claude/plans/shimmying-hopping-hollerith.md` (original design)
- Deployment target: macOS 13+ (Ventura)
- No App Sandbox (required for CGEvent paste simulation)
