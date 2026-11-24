import AppKit
import SwiftUI

/// Area that moves the panel. The scroll view swallows AppKit's own background dragging.
struct WindowDrag: NSViewRepresentable {
    var onDoubleClick: (() -> Void)?

    func makeNSView(context: Context) -> WindowDragView { WindowDragView() }

    func updateNSView(_ view: WindowDragView, context: Context) { view.onDoubleClick = onDoubleClick }
}

final class WindowDragView: NSView {
    var onDoubleClick: (() -> Void)?

    // The panel may not be key yet, so the first click has to count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let onDoubleClick {
            onDoubleClick()
        } else {
            window?.performDrag(with: event)
        }
    }
}
