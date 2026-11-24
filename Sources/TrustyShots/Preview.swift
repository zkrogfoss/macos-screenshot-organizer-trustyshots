import AppKit

/// Large view of one screenshot. Quick Look's own panel would take focus from the shelf.
@MainActor
final class Preview {
    private let imageView = NSImageView()
    private lazy var window = makeWindow()

    var isVisible: Bool { window.isVisible }

    func show(_ url: URL, on screen: NSScreen?) {
        guard let image = NSImage(contentsOf: url), let area = (screen ?? .main)?.visibleFrame,
              image.size.width > 0, image.size.height > 0 else { return hide() }
        let scale = min(area.width * 0.7 / image.size.width, area.height * 0.7 / image.size.height, 2)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        imageView.image = image
        window.setFrame(
            NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                   width: size.width, height: size.height),
            display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
        imageView.image = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: true)
        window.level = .popUpMenu
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        // It can cover the shelf, and clicks must still reach the tiles.
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        window.contentView = imageView
        return window
    }
}
