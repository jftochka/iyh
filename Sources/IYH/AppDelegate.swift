import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let layouts = KeyboardLayoutService()
    private lazy var replacement = TextReplacementService(layouts: layouts)
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem!
    private var statusMessageItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!
    private var layoutsMenu: NSMenu!
    private var resetWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()

        do {
            hotKey = try GlobalHotKey { [weak self] in
                self?.performConversion()
            }
        } catch {
            showFailure(error.localizedDescription)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.requestAccessibilityIfNeeded()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshAccessibilityStatus()
        refreshLayoutsMenu()
    }

    @objc private func performConversion() {
        do {
            let result = try replacement.convertFocusedText()
            showSuccess("\(result.sourceName) → \(result.targetName)")
        } catch {
            if case IYHError.accessibilityRequired = error {
                requestAccessibilityIfNeeded()
            }
            showFailure(error.localizedDescription)
        }
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [:])
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        if let button = statusItem.button {
            button.image = menuBarIcon()
            button.toolTip = "iyh — switch the text layout (⇧⌘1)"
        }

        let menu = NSMenu()
        menu.delegate = self

        let title = NSMenuItem(title: "iyh · layout switcher", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let about = NSMenuItem(title: "About iyh…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let convert = NSMenuItem(
            title: "Convert text",
            action: #selector(performConversion),
            keyEquivalent: "1"
        )
        convert.target = self
        convert.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(convert)

        statusMessageItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusMessageItem.isEnabled = false
        menu.addItem(statusMessageItem)
        menu.addItem(.separator())

        let layoutsItem = NSMenuItem(title: "Available layouts", action: nil, keyEquivalent: "")
        layoutsMenu = NSMenu()
        layoutsItem.submenu = layoutsMenu
        menu.addItem(layoutsItem)

        accessibilityItem = NSMenuItem(
            title: "Accessibility",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())

        let help = NSMenuItem(
            title: "Select text or place the cursor after a word",
            action: nil,
            keyEquivalent: ""
        )
        help.isEnabled = false
        menu.addItem(help)

        let quit = NSMenuItem(title: "Quit iyh", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshAccessibilityStatus()
        refreshLayoutsMenu()
    }

    private func menuBarIcon() -> NSImage {
        let size = NSSize(width: 24, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let text = NSString(string: "iyh")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 1
        )
        text.draw(at: point, withAttributes: attributes)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        accessibilityItem.title = trusted
            ? "Accessibility: Allowed"
            : "Allow Accessibility…"
        accessibilityItem.state = trusted ? .on : .off
    }

    private func refreshLayoutsMenu() {
        layoutsMenu.removeAllItems()
        let currentID = layouts.currentLayoutID()
        let available = layouts.availableLayouts()

        if available.isEmpty {
            let item = NSMenuItem(title: "No layouts found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            layoutsMenu.addItem(item)
            return
        }

        for layout in available {
            let item = NSMenuItem(title: layout.name, action: nil, keyEquivalent: "")
            item.state = layout.id == currentID ? .on : .off
            item.isEnabled = false
            layoutsMenu.addItem(item)
        }
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else {
            refreshAccessibilityStatus()
            return
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        refreshAccessibilityStatus()
    }

    private func showSuccess(_ message: String) {
        updateStatus(message: message, color: .systemGreen, beep: false)
    }

    private func showFailure(_ message: String) {
        updateStatus(message: message, color: .systemRed, beep: true)
    }

    private func updateStatus(message: String, color: NSColor, beep: Bool) {
        resetWorkItem?.cancel()
        statusMessageItem.title = message
        statusItem.button?.contentTintColor = color
        statusItem.button?.toolTip = message
        if beep {
            NSSound.beep()
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.statusMessageItem.title = "Ready · ⇧⌘1"
            self?.statusItem.button?.contentTintColor = nil
            self?.statusItem.button?.toolTip = "iyh — switch the text layout (⇧⌘1)"
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }
}
