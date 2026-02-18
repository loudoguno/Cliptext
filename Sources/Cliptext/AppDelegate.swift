import AppKit
import KeyboardShortcuts
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let showClipboardHistory = Self(
        "showClipboardHistory",
        default: .init(.v, modifiers: [.control, .option])
    )
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let store = ClipboardStore(capacity: 10)
    private lazy var monitor = ClipboardMonitor(store: store)

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkey()
        monitor.start()

        if !PasteSimulator.hasAccessibilityPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                PasteSimulator.requestAccessibilityPermission()
            }
        }

        // Register as a Services provider
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
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
    }

    private func showMenuAtCursor() {
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
        PasteSimulator.paste(item)
    }

    @objc private func pastePlainTextSelected(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        monitor.temporarilyIgnoreNextChange()
        PasteSimulator.pastePlainText(item)
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

    /// Called when user selects "Paste from Cliptext" in Services menu.
    @objc func pasteFromCliptext(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let menu = buildCurrentMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
