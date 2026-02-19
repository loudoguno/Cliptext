# macOS Overlay Window Types: Technical Reference

Research into why Cliptext's paste simulation works for some floating/overlay apps but not others.

## The Core Distinction: Activating vs Non-Activating Panels

The decisive factor for whether `NSRunningApplication.activate()` + `CGEvent.post(⌘V)` works:

**Does the app become the system's frontmost application when its window is visible?**

| App | Activates on Show | CGEvent Paste Works |
|---|---|---|
| Slidepad | Yes | Yes |
| Sidenotes | Yes | Yes |
| Drafts Quick Capture | Yes (with main window) | Yes |
| Tot | Yes (via NSPopover) | Yes |
| **Raycast Notes** | **No (non-activating panel)** | **No** |
| Spotlight | No (non-activating panel) | No |
| Alfred | No (non-activating panel) | No |

## Window Level Stack

| Level | Value | Usage |
|---|---|---|
| `normal` | 0 | Standard app windows |
| `floating` | 3 | Palettes, always-on-top panels |
| `modalPanel` | 8 | Modal dialogs |
| `statusBar` | 25 | Menu bar extras |
| `popUpMenu` | 101 | Menus, popovers |

## NSWindow vs NSPanel

`NSPanel` (subclass of `NSWindow`) key differences:
- **`hidesOnDeactivate`**: Panels hide when app deactivates (by default)
- **Key without Main**: Panels become key window without becoming main window
- **`becomesKeyOnlyIfNeeded`**: Only steals key if user clicks a text field
- **Not in Window menu**: Panels are auxiliary

## The `.nonactivatingPanel` Style Mask

This is why Raycast Notes is different:

- Sets `kCGSPreventsActivationTagBit` on the window's internal WindowServer representation
- Clicking the panel calls `CPSStealKeyFocusReturningID` — a private CoreProcesses subsystem call
- WindowServer redirects key events to the panel **without marking the owning app as "active"**
- `NSWorkspace.shared.frontmostApplication` still points to the PREVIOUS app
- When focus leaves, `CPSReleaseKeyFocusWithID` restores the focus stack

This is how Spotlight, Raycast launcher, and Alfred work.

## Key Window vs Main Window vs Active Application

Three distinct concepts:
- **Active application (frontmost)**: Owns the menu bar. `CGEventPost` delivers to this app's key window.
- **Key window**: Receives keyboard events. May belong to a non-activating panel whose app is NOT active.
- **Main window**: App's primary document window. Panels become key without becoming main.

## Activation Policy

| Policy | Dock Icon | Cmd+Tab | Notes |
|---|---|---|---|
| `.regular` | Yes | Yes | Standard apps |
| `.accessory` | No | No | Menu bar apps, utilities |
| `.prohibited` | No | No | Background daemons |

## Why CGEvent Fails for Non-Activating Panels

When `CGEventPost(.cghidEventTap, event)` fires:
1. Event enters the HID stream
2. WindowServer routes to the **currently active application's** event queue
3. "Active" means `NSWorkspace.shared.frontmostApplication`
4. Non-activating panels receive key events via `CPSStealKeyFocus` — a completely separate pathway
5. CGEvent knows nothing about this separate pathway

## Per-App Analysis

### Raycast Notes
- **Window**: `NSPanel` with `.nonactivatingPanel` style mask
- **Level**: `.floating` (3)
- **Policy**: `.accessory` (dynamically `.regular` when Settings open)
- **Focus**: `CPSStealKeyFocus` — never becomes frontmost app
- **Architecture**: Native AppKit rendered via custom React reconciler (not Electron/WKWebView)
- **Why paste fails**: App designed to NOT be active. `activate()` fights the architecture. Even if briefly active, Raycast may intercept ⌘V at the NSApp level before it reaches the text field.

### Slidepad
- **Window**: `NSPanel` (activating)
- **Level**: `.floating` with `.fullScreenAuxiliary`
- **Policy**: `.accessory`
- **Focus**: **Activates the app** when shown — WKWebView needs app to be active
- **Why paste works**: `activate()` makes it frontmost normally, CGEvent delivers to key window

### Sidenotes
- **Window**: `NSPanel` (activating)
- **Level**: `.floating`
- **Policy**: `.accessory`
- **Focus**: Activates on show (text input needs reliable focus)
- **Why paste works**: Same as Slidepad — becomes frontmost normally

### Drafts Quick Capture
- **Window**: `NSWindow` (NOT NSPanel)
- **Level**: `.floating` or `.normal` with special ordering
- **Policy**: `.regular` — has Dock icon
- **Focus**: Fully activating (known bug: showing Quick Capture also reveals main window)
- **Why paste works**: Standard activation, standard CGEvent delivery
- **Note**: Developer confirmed decoupling would require rewriting as separate helper process

### Tot
- **Window**: `NSPopover` (or borderless `NSPanel` anchored to status item)
- **Level**: `.popUpMenu` (101) — above all standard windows
- **Policy**: `.accessory` (option to run as `.regular`)
- **Focus**: `NSPopover` activates the app when shown
- **Why paste works**: App activates normally on popover show

## Possible Solutions for Non-Activating Panels

### Option 1: Accessibility API (Best approach)
```swift
let axApp = AXUIElementCreateApplication(pid)
var focusedElement: AnyObject?
AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
// Perform paste action or set value directly
```
Works independently of frontmost status.

### Option 2: Direct Value Setting
```swift
AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, text as CFTypeRef)
```
Bypasses paste entirely. Downside: replaces all content, doesn't insert at cursor.

### Option 3: Accept the Limitation
Non-activating panels are architecturally designed to resist programmatic focus manipulation. For v1, document that Cliptext works with all regular and activating-panel apps, and note the non-activating panel limitation.

## Detection Heuristic

To check if a target app uses non-activating panels:
```swift
let before = NSWorkspace.shared.frontmostApplication
// ... invoke the target window ...
let after = NSWorkspace.shared.frontmostApplication
// If before == after, the window is non-activating
```

## Sources

- [The Curious Case of NSPanel's Nonactivating Style Mask Flag](https://philz.blog/nspanel-nonactivating-style-mask-flag/) — Deep dive on `kCGSPreventsActivationTagBit` and `CPSStealKeyFocus`
- [Make a floating panel in SwiftUI for macOS - Cindori](https://cindori.com/developer/floating-panel) — Complete FloatingPanel implementation
- [Multi Blog: Nailing the Activation Behavior of a Spotlight/Raycast-Like Command Palette](https://multi.app/blog/nailing-the-activation-behavior-of-a-spotlight-raycast-like-command-palette) — Technical analysis of non-activating panel activation
- [How the Raycast API and extensions work - Raycast Blog](https://www.raycast.com/blog/how-raycast-api-extensions-work) — Raycast's React-AppKit architecture
- [Apple: Cocoa Event Architecture](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html) — Official event routing documentation
- [Apple: How Panels Work](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/WinPanel/Concepts/UsingPanels.html) — NSPanel behavior
- [NSWindow Levels Order - James Fisher](https://jameshfisher.com/2020/08/03/what-is-the-order-of-nswindow-levels/) — Window level numeric hierarchy
- [Drafts Quick Capture Forum Thread](https://forums.getdrafts.com/t/quick-capture-shortcut-activating-main-window/9991) — Developer confirmation of architectural limitation
- [CGEventPostToPid limitations - Apple Developer Forums](https://developer.apple.com/forums/thread/724835) — Why postToPid fails for background apps
- [becomesKeyOnlyIfNeeded - Apple Docs](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded)
- [nonactivatingPanel - Apple Docs](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)
- [Daring Fireball: Tot Review](https://daringfireball.net/2020/02/tot) — Tot window behavior
