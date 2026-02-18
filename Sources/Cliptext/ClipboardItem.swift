import AppKit

/// A single captured clipboard entry.
final class ClipboardItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let content: Content
    var isPinned = false

    enum Content {
        case text(String)
        case image(NSImage)
        case fileURLs([URL])
        case richText(NSAttributedString, plainText: String)
    }

    init(timestamp: Date, content: Content) {
        self.timestamp = timestamp
        self.content = content
    }

    /// Short display string for the menu item (max 60 chars).
    var menuTitle: String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            if trimmed.isEmpty { return "[Empty Text]" }
            return trimmed.count > 60 ? String(trimmed.prefix(57)) + "..." : trimmed

        case .image(let image):
            let w = Int(image.size.width)
            let h = Int(image.size.height)
            return "Image (\(w) \u{00d7} \(h))"

        case .fileURLs(let urls):
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"

        case .richText(_, let plainText):
            let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            if trimmed.isEmpty { return "[Rich Text]" }
            return trimmed.count > 60 ? String(trimmed.prefix(57)) + "..." : trimmed
        }
    }

    /// Plain text representation for "paste as plain text" feature.
    var plainText: String? {
        switch content {
        case .text(let string): return string
        case .richText(_, let plain): return plain
        default: return nil
        }
    }

    /// Optional thumbnail for the menu item.
    var menuImage: NSImage? {
        switch content {
        case .image(let image):
            return image.resizedProportionally(maxSide: 32)
        case .fileURLs(let urls):
            guard let first = urls.first else { return nil }
            return NSWorkspace.shared.icon(forFile: first.path)
                .resizedProportionally(maxSide: 16)
        default:
            return nil
        }
    }
}

// MARK: - NSImage Resize

extension NSImage {
    func resizedProportionally(maxSide: CGFloat) -> NSImage {
        let ratio = min(maxSide / size.width, maxSide / size.height, 1.0)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
