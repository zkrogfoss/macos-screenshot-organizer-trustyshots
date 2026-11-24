import AppKit
import Carbon.HIToolbox

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let label: String

    /// Nil when the keys cannot be a global shortcut, such as a bare letter.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        // Shift alone would take over normal typing.
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        let parts: [(NSEvent.ModifierFlags, Int, String)] = [
            (.control, controlKey, "⌃"), (.option, optionKey, "⌥"),
            (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘"),
        ]
        let held = parts.filter { flags.contains($0.0) }
        let names: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "⌫",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        let key = names[event.keyCode]
            ?? event.characters(byApplyingModifiers: [])?.uppercased()
            ?? "Key \(event.keyCode)"
        keyCode = UInt32(event.keyCode)
        modifiers = held.reduce(0) { $0 | UInt32($1.1) }
        label = held.map(\.2).joined() + key
    }
}

@MainActor
final class HotKey {
    private(set) var shortcut: Shortcut?
    private var reference: EventHotKeyRef?
    private let onPress: () -> Void
    private let defaultsKey = "toggleShortcut"

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        installHandler()
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data),
           register(saved) {
            shortcut = saved
        }
    }

    /// Returns false, keeping the old shortcut, when macOS refuses the new one.
    func set(_ new: Shortcut?) -> Bool {
        let old = shortcut
        pause()
        if let new, !register(new) {
            if let old { _ = register(old) }
            return false
        }
        shortcut = new
        let data = new.flatMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        return true
    }

    /// Lets the recorder receive the current shortcut instead of triggering it.
    func pause() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
    }

    func resume() {
        if reference == nil, let shortcut { _ = register(shortcut) }
    }

    private func register(_ shortcut: Shortcut) -> Bool {
        let id = EventHotKeyID(signature: 0x5353_4F52, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
                                   GetApplicationEventTarget(), 0, &reference) == noErr
    }

    private func installHandler() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // The handler lives as long as the app, so the unretained pointer stays valid.
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(pointer).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.onPress() }
            return noErr
        }, 1, &type, pointer, nil)
    }
}
