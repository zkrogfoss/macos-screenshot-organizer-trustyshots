import AppKit
import SwiftUI

final class ShelfPanel: NSPanel {
    var onCopy: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onUndo: (() -> Void)?
    var onSpace: (() -> Void)?
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }

    // Handled before any button, or Space could press a focused one.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           event.modifierFlags.isDisjoint(with: [.command, .shift, .option, .control]) {
            switch event.keyCode {
            case 49:
                if !event.isARepeat { onSpace?() }
                return
            case 53:
                onEscape?()
                return
            default: break
            }
        }
        super.sendEvent(event)
    }

    // A menu bar app has no Edit menu, so these have to be handled here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers == .command else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case "c": onCopy?()
        case "a": onSelectAll?()
        case "z": onUndo?()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }
}

final class ClickThroughHost<Content: View>: NSHostingView<Content> {
    // The panel may not be key yet, so the first click has to count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
