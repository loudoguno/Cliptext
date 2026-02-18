import AppKit

/// Constructs an NSMenu from clipboard history with pin support and plain text paste.
enum MenuBuilder {

    static func buildMenu(
        from store: ClipboardStore,
        target: AnyObject,
        pasteAction: Selector,
        pastePlainAction: Selector,
        togglePinAction: Selector,
        removePinAction: Selector,
        clearAction: Selector,
        loginToggleAction: Selector,
        isLoginItemEnabled: Bool
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let unpinned = store.unpinnedItems
        let pinned = store.pinnedItems

        if unpinned.isEmpty && pinned.isEmpty {
            let empty = NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        // Unpinned items (recent history)
        for (index, item) in unpinned.enumerated() {
            addClipboardMenuItem(
                to: menu, item: item, index: index,
                target: target, pasteAction: pasteAction,
                pastePlainAction: pastePlainAction,
                togglePinAction: togglePinAction
            )
        }

        // Pinned section
        if !pinned.isEmpty {
            menu.addItem(NSMenuItem.separator())

            if pinned.count == 1 {
                // Single pinned item inline with pin emoji
                let item = pinned[0]
                let menuItem = NSMenuItem()
                menuItem.title = "\u{1f4cc} \(item.menuTitle)"
                menuItem.target = target
                menuItem.action = pasteAction
                menuItem.representedObject = item
                menuItem.isEnabled = true
                if let image = item.menuImage { menuItem.image = image }
                menu.addItem(menuItem)

                // ⌥ alternate: unpin
                let unpinItem = NSMenuItem()
                unpinItem.title = "Unpin: \(item.menuTitle)"
                unpinItem.target = target
                unpinItem.action = togglePinAction
                unpinItem.representedObject = item
                unpinItem.isEnabled = true
                unpinItem.isAlternate = true
                unpinItem.keyEquivalentModifierMask = [.option]
                menu.addItem(unpinItem)
            } else {
                // Multiple pinned items go into a submenu
                let pinnedSubmenu = NSMenu()
                for item in pinned {
                    let menuItem = NSMenuItem()
                    menuItem.title = "\u{1f4cc} \(item.menuTitle)"
                    menuItem.target = target
                    menuItem.action = pasteAction
                    menuItem.representedObject = item
                    menuItem.isEnabled = true
                    if let image = item.menuImage { menuItem.image = image }
                    pinnedSubmenu.addItem(menuItem)

                    // Unpin alternate
                    let unpinItem = NSMenuItem()
                    unpinItem.title = "Unpin: \(item.menuTitle)"
                    unpinItem.target = target
                    unpinItem.action = removePinAction
                    unpinItem.representedObject = item
                    unpinItem.isEnabled = true
                    unpinItem.isAlternate = true
                    unpinItem.keyEquivalentModifierMask = [.option]
                    pinnedSubmenu.addItem(unpinItem)
                }

                let pinnedHeader = NSMenuItem(title: "\u{1f4cc} Pinned", action: nil, keyEquivalent: "")
                pinnedHeader.submenu = pinnedSubmenu
                menu.addItem(pinnedHeader)
            }
        }

        // Utility section
        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(title: "Clear History", action: clearAction, keyEquivalent: "")
        clearItem.target = target
        menu.addItem(clearItem)

        let loginItem = NSMenuItem(title: "Start at Login", action: loginToggleAction, keyEquivalent: "")
        loginItem.target = target
        loginItem.state = isLoginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Cliptext", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Private

    private static func addClipboardMenuItem(
        to menu: NSMenu,
        item: ClipboardItem,
        index: Int,
        target: AnyObject,
        pasteAction: Selector,
        pastePlainAction: Selector,
        togglePinAction: Selector
    ) {
        // Primary action: paste
        let menuItem = NSMenuItem()
        menuItem.title = item.menuTitle
        menuItem.target = target
        menuItem.action = pasteAction
        menuItem.representedObject = item
        menuItem.isEnabled = true

        if index < 9 {
            menuItem.keyEquivalent = "\(index + 1)"
            menuItem.keyEquivalentModifierMask = []
        }

        if let image = item.menuImage {
            menuItem.image = image
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        menuItem.toolTip = formatter.localizedString(for: item.timestamp, relativeTo: Date())

        menu.addItem(menuItem)

        // ⌥ alternate: pin this item
        let pinItem = NSMenuItem()
        pinItem.title = "\u{1f4cc} Pin: \(item.menuTitle)"
        pinItem.target = target
        pinItem.action = togglePinAction
        pinItem.representedObject = item
        pinItem.isEnabled = true
        pinItem.isAlternate = true
        pinItem.keyEquivalentModifierMask = [.option]
        if index < 9 {
            pinItem.keyEquivalent = "\(index + 1)"
        }
        menu.addItem(pinItem)

        // ⇧ alternate: paste as plain text (only for text-bearing items)
        if item.plainText != nil {
            let plainItem = NSMenuItem()
            plainItem.title = "Paste Plain: \(item.menuTitle)"
            plainItem.target = target
            plainItem.action = pastePlainAction
            plainItem.representedObject = item
            plainItem.isEnabled = true
            plainItem.isAlternate = true
            plainItem.keyEquivalentModifierMask = [.shift]
            if index < 9 {
                plainItem.keyEquivalent = "\(index + 1)"
            }
            menu.addItem(plainItem)
        }
    }
}
