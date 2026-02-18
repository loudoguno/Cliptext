import AppKit

/// Polls NSPasteboard.general.changeCount to detect clipboard changes.
final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private var ignoreNextChange = false

    init(store: ClipboardStore) {
        self.store = store
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(interval: TimeInterval = 0.5) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        // Fire even when menus are open
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call before writing to the pasteboard ourselves to avoid self-capture.
    func temporarilyIgnoreNextChange() {
        ignoreNextChange = true
    }

    // MARK: - Private

    private func checkForChanges() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        guard let item = captureCurrentClipboard() else { return }
        store.push(item)
    }

    private func captureCurrentClipboard() -> ClipboardItem? {
        let now = Date()

        // File URLs (highest priority — Finder copies put both fileURL and string)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty,
           urls.allSatisfy({ $0.isFileURL }) {
            return ClipboardItem(timestamp: now, content: .fileURLs(urls))
        }

        // Images
        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData) {
            return ClipboardItem(timestamp: now, content: .image(image))
        }

        // Rich text (RTF with plain text fallback)
        if let rtfData = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil),
           let plainText = pasteboard.string(forType: .string) {
            return ClipboardItem(timestamp: now, content: .richText(attributed, plainText: plainText))
        }

        // Plain text
        if let text = pasteboard.string(forType: .string) {
            return ClipboardItem(timestamp: now, content: .text(text))
        }

        return nil
    }
}
