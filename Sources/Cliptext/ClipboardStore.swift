import Foundation

/// Fixed-capacity in-memory store for clipboard history with pin support.
final class ClipboardStore {
    private var items: [ClipboardItem] = []
    private let capacity: Int

    init(capacity: Int = 10) {
        self.capacity = capacity
    }

    /// Add a new item to the front. Evicts oldest unpinned item if at capacity.
    func push(_ item: ClipboardItem) {
        if let latest = unpinnedItems.first, isDuplicate(latest, item) {
            return
        }
        items.insert(item, at: 0)
        trimToCapacity()
    }

    /// All items: unpinned (newest first), then pinned (newest first).
    var allItems: [ClipboardItem] { items }

    /// Unpinned items in order.
    var unpinnedItems: [ClipboardItem] { items.filter { !$0.isPinned } }

    /// Pinned items in order.
    var pinnedItems: [ClipboardItem] { items.filter { $0.isPinned } }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
    }

    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        // Only clear unpinned items; pinned items survive
        items.removeAll { !$0.isPinned }
    }

    // MARK: - Private

    private func trimToCapacity() {
        // Only evict unpinned items when over capacity
        while items.count > capacity {
            if let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) {
                items.remove(at: lastUnpinnedIndex)
            } else {
                break // All items are pinned, don't evict
            }
        }
    }

    private func isDuplicate(_ a: ClipboardItem, _ b: ClipboardItem) -> Bool {
        switch (a.content, b.content) {
        case (.text(let t1), .text(let t2)):
            return t1 == t2
        case (.fileURLs(let u1), .fileURLs(let u2)):
            return u1 == u2
        case (.richText(_, let p1), .richText(_, let p2)):
            return p1 == p2
        default:
            return false
        }
    }
}
