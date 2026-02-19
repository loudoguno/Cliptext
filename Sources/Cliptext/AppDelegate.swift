import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let showClipboardHistory = Self(
        "showClipboardHistory",
        default: .init(.v, modifiers: [.control, .option])
    )
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Static so the C function pointer callback can access it
    static var shared: AppDelegate!
    static var sharedEventTap: CFMachPort?

    private var statusItem: NSStatusItem!
    private let store = ClipboardStore(capacity: 10)
    private lazy var monitor = ClipboardMonitor(store: store)
    private var eventTapRetryTimer: Timer?

    /// The app that had focus before our menu opened.
    private var targetApp: NSRunningApplication?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupStatusItem()
        setupHotkey()
        monitor.start()

        if !PasteSimulator.hasAccessibilityPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                PasteSimulator.requestAccessibilityPermission()
            }
        }

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        eventTapRetryTimer?.invalidate()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Cliptext")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        targetApp = PasteSimulator.captureTargetApp()
        let menu = buildCurrentMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .showClipboardHistory) { [weak self] in
            self?.showMenuAtCursor()
        }
        attemptEventTapSetup()
    }

    private func attemptEventTapSetup() {
        if setupRightCommandV() {
            NSLog("Cliptext: Right ⌘+V event tap active")
            eventTapRetryTimer?.invalidate()
            eventTapRetryTimer = nil
        } else {
            NSLog("Cliptext: Event tap failed, retrying (grant Accessibility permission)")
            eventTapRetryTimer?.invalidate()
            eventTapRetryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                if self?.setupRightCommandV() == true {
                    NSLog("Cliptext: Right ⌘+V event tap active")
                    self?.eventTapRetryTimer?.invalidate()
                    self?.eventTapRetryTimer = nil
                }
            }
        }
    }

    @discardableResult
    private func setupRightCommandV() -> Bool {
        if AppDelegate.sharedEventTap != nil { return true }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = AppDelegate.sharedEventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == Int64(kVK_ANSI_V) else {
                return Unmanaged.passUnretained(event)
            }

            let flags = event.flags.rawValue
            let isRightCmd = flags & 0x10 != 0 // NX_DEVICERCMDKEYMASK

            guard isRightCmd else {
                return Unmanaged.passUnretained(event)
            }

            let otherMods: UInt64 = CGEventFlags.maskShift.rawValue
                | CGEventFlags.maskAlternate.rawValue
                | CGEventFlags.maskControl.rawValue
            if flags & otherMods != 0 {
                return Unmanaged.passUnretained(event)
            }

            DispatchQueue.main.async {
                AppDelegate.shared?.showMenuAtCursor()
            }
            return nil
        }

        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
            | 1 << CGEventType.flagsChanged.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: nil
        ) else {
            return false
        }

        AppDelegate.sharedEventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func showMenuAtCursor() {
        targetApp = PasteSimulator.captureTargetApp()
        let menu = buildCurrentMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Menu

    private func buildCurrentMenu() -> NSMenu {
        MenuBuilder.buildMenu(
            from: store,
            target: self,
            pasteAction: #selector(clipboardItemSelected(_:)),
            pastePlainAction: #selector(pastePlainTextSelected(_:)),
            togglePinAction: #selector(togglePinSelected(_:)),
            removePinAction: #selector(togglePinSelected(_:)),
            clearAction: #selector(clearHistory),
            loginToggleAction: #selector(toggleLoginItem),
            isLoginItemEnabled: isLoginItemEnabled
        )
    }

    // MARK: - Actions

    @objc private func clipboardItemSelected(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        monitor.temporarilyIgnoreNextChange()
        PasteSimulator.paste(item, targetApp: targetApp)
    }

    @objc private func pastePlainTextSelected(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        monitor.temporarilyIgnoreNextChange()
        PasteSimulator.pastePlainText(item, targetApp: targetApp)
    }

    @objc private func togglePinSelected(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        store.togglePin(item)
    }

    @objc private func clearHistory() {
        store.clear()
    }

    // MARK: - Login Item

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLoginItem() {
        do {
            if isLoginItemEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Cliptext: Failed to toggle login item: \(error)")
        }
    }

    // MARK: - Services Provider

    @objc func pasteFromCliptext(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        showMenuAtCursor()
    }
}
