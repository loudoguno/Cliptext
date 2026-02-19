import AppKit
import Carbon.HIToolbox

/// Writes a ClipboardItem to the system pasteboard and simulates ⌘V.
enum PasteSimulator {

    /// Capture the app that currently owns keyboard focus.
    /// Call this BEFORE showing the menu, so we know where to paste.
    static func captureTargetApp() -> NSRunningApplication? {
        // First try: AX API — returns the real focused app even if it's an accessory app
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        if result == .success, let appElement = focusedApp {
            var pid: pid_t = 0
            if AXUIElementGetPid(appElement as! AXUIElement, &pid) == .success,
               pid != ProcessInfo.processInfo.processIdentifier {
                return NSRunningApplication(processIdentifier: pid)
            }
        }

        // Fallback: frontmost regular app
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            return frontApp
        }

        return nil
    }

    static func paste(_ item: ClipboardItem, targetApp: NSRunningApplication? = nil) {
        writeToClipboard(item)
        activateAndPaste(targetApp: targetApp)
    }

    static func pastePlainText(_ item: ClipboardItem, targetApp: NSRunningApplication? = nil) {
        guard let text = item.plainText else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        activateAndPaste(targetApp: targetApp)
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Private

    /// Re-activate the target app, then simulate ⌘V.
    private static func activateAndPaste(targetApp: NSRunningApplication?) {
        if let app = targetApp {
            app.activate()
        }
        // Give the app time to come to front before sending the keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulateCmdV()
        }
    }

    private static func writeToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.content {
        case .text(let string):
            pb.setString(string, forType: .string)

        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pb.setData(tiffData, forType: .tiff)
            }

        case .fileURLs(let urls):
            pb.writeObjects(urls as [NSURL])

        case .richText(let attributed, _):
            let range = NSRange(location: 0, length: attributed.length)
            if let rtfData = attributed.rtf(from: range) {
                pb.setData(rtfData, forType: .rtf)
            }
            pb.setString(attributed.string, forType: .string)
        }
    }

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
