import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let preview = Preview()
    private var item: NSStatusItem?
    private var cleanTimer: Timer?
    private var outsideClicks: Any?
    private let frameName = "ShelfPanel"
    private let defaultSize = NSSize(width: 420, height: 480)
    private lazy var panel = makePanel()
    private lazy var hotKey = HotKey { [weak self] in self?.togglePanel() }
    private lazy var saver = ClipboardSaver(folder: { [store] in store.folder })
    private lazy var settings = SettingsWindow(
        hotKey: hotKey, saver: saver, store: store, chooseFolder: { [weak self] in self?.chooseFolder() })

    func applicationDidFinishLaunching(_ notification: Notification) {
        ThemeStore.shared.applySaved()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.make()
        item.button?.target = self
        item.button?.action = #selector(iconClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
        // Lazy, so touch both now or they stay off until Settings opens.
        _ = hotKey
        saver.onError = { [store] in store.showError($0) }
        store.onHover = { [weak self] in self?.updatePreview() }
        store.cleanExpired()
        cleanTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.cleanExpired() }
        }
        watchOutsideClicks()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Copier.empty()
    }

    // MARK: Menu bar icon

    @objc private func iconClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "About TrustyShots", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…",action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Trash All…",action: #selector(trashAll), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "")
        // A permanent menu would also open on left click.
        item?.menu = menu
        item?.button?.performClick(nil)
        item?.menu = nil
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "Pick your shots. Paste them all.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                             .foregroundColor: NSColor.labelColor]),
        ])
    }

    @objc private func openSettings() { settings.show() }

    @objc private func trashAll() { store.trashAll() }

    private func chooseFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.canCreateDirectories = true
        picker.directoryURL = store.folder
        picker.message = "Choose the folder that holds your screenshots. Every image in it is shown."
        picker.prompt = "Choose"
        NSApp.activate()
        guard picker.runModal() == .OK, let url = picker.url else { return }
        store.setFolder(url)
        settings.refresh()
    }

    // MARK: Panel

    private func togglePanel() {
        if panel.isVisible {
            hidePanel()
            return
        }
        store.reload()
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.contains(
            NSPoint(x: panel.frame.midX, y: panel.frame.midY)) }
        // The saved place may be on a display that is gone.
        if !hasSavedFrame || !onScreen { placeUnderIcon() }
        keepBelowMenuBar()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() {
        preview.hide()
        store.setHovered(nil)
        store.dismissStatus()
        panel.orderOut(nil)
    }

    private func watchOutsideClicks() {
        // A global monitor sees only other apps' clicks, so Settings never hides the panel.
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.clickedOutside() }
        }
    }

    private func clickedOutside() {
        guard Prefs.hideOnOutsideClick, panel.isVisible else { return }
        // The icon toggles by itself; hiding here first would make it reopen the panel.
        if let icon = item?.button?.window?.frame, icon.contains(NSEvent.mouseLocation) { return }
        hidePanel()
    }

    private func copy() {
        guard store.copySelection(), Prefs.hideAfterCopy else { return }
        store.clearSelection()
        hidePanel()
    }

    private func togglePreview() {
        guard !preview.isVisible, let url = store.hovered ?? store.selection.last else { return preview.hide() }
        preview.show(url, on: panel.screen)
    }

    private func updatePreview() {
        guard preview.isVisible, let url = store.hovered else { return }
        preview.show(url, on: panel.screen)
    }

    private var hasSavedFrame: Bool {
        UserDefaults.standard.string(forKey: "NSWindow Frame \(frameName)") != nil
    }

    @objc private func resetPosition() {
        panel.setContentSize(defaultSize)
        placeUnderIcon()
    }

    private func placeUnderIcon() {
        let mouse = NSEvent.mouseLocation
        let icon = item?.button?.window
        // A hidden menu bar can leave the icon without a screen.
        guard let screen = icon?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let center = icon?.frame.midX ?? area.maxX
        let x = min(max(center - panel.frame.width / 2, area.minX + 12),
                    area.maxX - panel.frame.width - 12)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: topLimit(of: screen)))
        // Autosave would pin this place, but the default has to keep following the icon.
        NSWindow.removeFrame(usingName: frameName)
    }

    private func keepBelowMenuBar() {
        // A hidden panel has no screen of its own, so look it up by position.
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) else { return }
        let top = topLimit(of: screen)
        guard panel.frame.maxY > top else { return }
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
    }

    private func topLimit(of screen: NSScreen) -> CGFloat {
        // An auto-hiding menu bar is not excluded from visibleFrame, but still covers the panel.
        let bar = max(screen.frame.maxY - screen.visibleFrame.maxY,
                      NSStatusBar.system.thickness, screen.safeAreaInsets.top)
        return screen.frame.maxY - bar - 12
    }

    private func makePanel() -> NSPanel {
        let panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: defaultSize),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: true)
        panel.minSize = NSSize(width: 300, height: 260)
        // The rounded SwiftUI background replaces the window's own square one.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onCopy = { [weak self] in self?.copy() }
        panel.onSelectAll = { [store] in store.selectAll() }
        panel.onUndo = { [store] in store.undoTrash() }
        panel.onSpace = { [weak self] in self?.togglePreview() }
        panel.onEscape = { [weak self] in
            guard let self else { return }
            if preview.isVisible { preview.hide() } else { hidePanel() }
        }
        let host = ClickThroughHost(rootView: PanelView(
            store: store,
            chooseFolder: { [weak self] in self?.chooseFolder() },
            resetPosition: { [weak self] in self?.resetPosition() }))
        // Otherwise SwiftUI's ideal size can override the remembered one.
        host.sizingOptions = [.minSize]
        panel.contentView = host
        panel.setFrameUsingName(frameName)
        panel.setFrameAutosaveName(frameName)
        return panel
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
