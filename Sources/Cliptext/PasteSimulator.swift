import AppKit
import Carbon.HIToolbox

/// Writes a ClipboardItem to the system pasteboard and simulates ⌘V.
enum PasteSimulator {

    static func paste(_ item: ClipboardItem) {
        writeToClipboard(item)
        // Small delay lets the pasteboard settle before the simulated keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            simulateCmdV()
        }
    }

    /// Paste only the plain text representation, stripping all formatting.
    static func pastePlainText(_ item: ClipboardItem) {
        guard let text = item.plainText else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            simulateCmdV()
        }
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Private

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
