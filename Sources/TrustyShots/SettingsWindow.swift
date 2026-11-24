import AppKit

@MainActor
final class SettingsWindow: NSWindow {
    private let recorder: ShortcutRecorder
    private let themes = NSPopUpButton()

    private let saver: ClipboardSaver
    private let store: Store
    private let onChooseFolder: () -> Void
    private let folderButton = NSButton()
    private let saveCopies = NSButton(checkboxWithTitle: "Save macshot ⌘C captures", target: nil, action: nil)
    private let hideAfterCopy = NSButton(checkboxWithTitle: "Hide after copy", target: nil, action: nil)
    private let hideOutside = NSButton(
        checkboxWithTitle: "Hide when clicking outside", target: nil, action: nil)
    private let autoClean = NSButton(
        checkboxWithTitle: "Trash images older than \(Prefs.cleanAfterDays) days", target: nil, action: nil)
    private let startAtLogin = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)

    init(hotKey: HotKey, saver: ClipboardSaver, store: Store, chooseFolder: @escaping () -> Void) {
        recorder = ShortcutRecorder(hotKey: hotKey)
        self.saver = saver
        self.store = store
        onChooseFolder = chooseFolder
        super.init(contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
                   styleMask: [.titled, .closable], backing: .buffered, defer: true)
        title = "TrustyShots Settings"
        isReleasedWhenClosed = false
        // The panel floats, so a normal window would open behind it.
        level = .floating

        let label = NSTextField(labelWithString: "Toggle panel:")
        let row = NSStackView(views: [label, recorder])
        let hint = NSTextField(labelWithString: "Click, then press keys. Delete removes, Esc cancels.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        themes.addItems(withTitles: Theme.allCases.map(\.rawValue))
        themes.target = self
        themes.action = #selector(chooseTheme)
        let themeRow = NSStackView(views: [NSTextField(labelWithString: "Theme:"), themes])
        let actions: [(NSButton, Selector)] = [
            (folderButton, #selector(pickFolder)),
            (saveCopies, #selector(toggleSaveCopies)),
            (hideAfterCopy, #selector(toggleHideAfterCopy)),
            (hideOutside, #selector(toggleHideOutside)),
            (autoClean, #selector(toggleAutoClean)),
            (startAtLogin, #selector(toggleStartAtLogin)),
        ]
        for (button, action) in actions {
            button.target = self
            button.action = action
        }
        folderButton.bezelStyle = .rounded
        folderButton.lineBreakMode = .byTruncatingMiddle
        folderButton.widthAnchor.constraint(lessThanOrEqualToConstant: 240).isActive = true
        let folderRow = NSStackView(views: [NSTextField(labelWithString: "Folder:"), folderButton])
        let stack = NSStackView(views: [
            folderRow, themeRow, row, hint, saveCopies, hideAfterCopy, hideOutside, autoClean, startAtLogin,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentView = stack
        recorder.onMessage = { hint.stringValue = $0 }
    }

    @objc private func pickFolder() { onChooseFolder() }

    @objc private func toggleHideAfterCopy() { Prefs.hideAfterCopy = hideAfterCopy.state == .on }

    @objc private func toggleHideOutside() { Prefs.hideOnOutsideClick = hideOutside.state == .on }

    @objc private func toggleAutoClean() {
        // Cancelling the question leaves it off.
        autoClean.state = store.setAutoClean(autoClean.state == .on) ? .on : .off
    }

    @objc private func toggleSaveCopies() {
        saver.setEnabled(saveCopies.state == .on)
    }

    @objc private func toggleStartAtLogin() {
        do {
            try LoginItem.setEnabled(startAtLogin.state == .on)
        } catch {
            recorder.onMessage?("Start at login failed: \(error.localizedDescription)")
        }
        if LoginItem.needsApproval {
            recorder.onMessage?("Allow it in System Settings → Login Items.")
            LoginItem.openSystemSettings()
        }
        startAtLogin.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func chooseTheme() {
        guard let theme = themes.titleOfSelectedItem.flatMap(Theme.init(rawValue:)) else { return }
        ThemeStore.shared.choose(theme)
    }

    func refresh() {
        folderButton.title = (store.folder.path as NSString).abbreviatingWithTildeInPath
        saveCopies.state = saver.isEnabled ? .on : .off
        hideAfterCopy.state = Prefs.hideAfterCopy ? .on : .off
        hideOutside.state = Prefs.hideOnOutsideClick ? .on : .off
        autoClean.state = Prefs.autoClean ? .on : .off
        startAtLogin.state = LoginItem.isEnabled ? .on : .off
        themes.selectItem(withTitle: ThemeStore.shared.current.rawValue)
    }

    func show() {
        refresh()
        if !isVisible { center() }
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    override func resignKey() {
        super.resignKey()
        recorder.stop()
    }

    override func close() {
        recorder.stop()
        super.close()
    }
}

@MainActor
final class ShortcutRecorder: NSButton {
    var onMessage: ((String) -> Void)?
    private let hotKey: HotKey
    private var monitor: Any?

    init(hotKey: HotKey) {
        self.hotKey = hotKey
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(start)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        showShortcut()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func start() {
        guard monitor == nil else { return stop() }
        hotKey.pause()
        title = "Press keys…"
        // A monitor sees Cmd combinations before menus and buttons consume them.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.record(event) }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hotKey.resume()
        showShortcut()
    }

    private func record(_ event: NSEvent) {
        let plain = event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift])
        if plain, event.keyCode == 53 { return stop() }
        if plain, event.keyCode == 51 {
            _ = hotKey.set(nil)
            onMessage?("Shortcut removed.")
            return stop()
        }
        guard let shortcut = Shortcut(event: event) else {
            onMessage?("Include ⌘, ⌥ or ⌃.")
            return
        }
        onMessage?(hotKey.set(shortcut) ? "Saved." : "macOS refused that shortcut.")
        stop()
    }

    private func showShortcut() {
        title = hotKey.shortcut?.label ?? "Record shortcut"
    }
}
