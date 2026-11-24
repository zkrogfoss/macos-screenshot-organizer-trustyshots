import AppKit
import ImageIO
import SwiftUI

enum Thumbnails {
    static let cache = NSCache<NSString, NSImage>()

    static func load(_ shot: Shot) async -> NSImage? {
        let key = "\(shot.url.path)|\(shot.date.timeIntervalSince1970)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 400,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(shot.url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let result = NSImage(cgImage: image, size: .zero)
        cache.setObject(result, forKey: key)
        return result
    }
}

// @State is a macro whose plugin is missing from the Command Line Tools, so hold the image here.
@MainActor
final class TileImage: ObservableObject {
    @Published var value: NSImage?
}

struct Tile: View {
    let shot: Shot
    @ObservedObject var store: Store
    @ObservedObject private var theme = ThemeStore.shared
    @StateObject private var image = TileImage()

    init(shot: Shot, store: Store) {
        self.shot = shot
        self.store = store
    }

    var body: some View {
        let number = store.selection.firstIndex(of: shot.url).map { $0 + 1 }
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.palette.tile)
            .frame(height: 96)
            .overlay {
                if let thumbnail = image.value {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit).padding(4)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.palette.accent,lineWidth: number == nil ? 0 : 3)
            }
            .overlay(alignment: .topTrailing) {
                if let number {
                    Text("\(number)").font(.caption.bold()).foregroundStyle(theme.palette.badgeText)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(theme.palette.accent, in: Circle()).padding(6)
                }
            }
            .overlay {
                DragArea(
                    urls: { store.dragURLs(from: shot.url) },
                    preview: { image.value },
                    onClick: { store.toggle(shot.url) },
                    onHover: { inside in
                        // Entering the next tile can arrive before leaving this one.
                        if inside { store.setHovered(shot.url) }
                        else if store.hovered == shot.url { store.setHovered(nil) }
                    })
            }
            .help(shot.url.lastPathComponent)
            .accessibilityLabel(shot.url.lastPathComponent)
            .task(id: shot) { image.value = await Thumbnails.load(shot) }
    }
}

// SwiftUI's onDrag carries one item, so AppKit is needed to drag several files.
struct DragArea: NSViewRepresentable {
    let urls: () -> [URL]
    let preview: () -> NSImage?
    let onClick: () -> Void
    let onHover: (Bool) -> Void

    func makeNSView(context: Context) -> DragView { DragView() }

    func updateNSView(_ view: DragView, context: Context) { view.area = self }
}

final class DragView: NSView, NSDraggingSource {
    var area: DragArea?
    private var start: NSPoint?

    // The panel may not be key yet, so the first click has to count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Dragging a tile must drag the file, not move the panel.
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // The app is never active, so tracking must not depend on that.
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { area?.onHover(true) }

    override func mouseExited(with event: NSEvent) { area?.onHover(false) }

    override func mouseDown(with event: NSEvent) { start = event.locationInWindow }

    override func mouseUp(with event: NSEvent) {
        if start != nil { area?.onClick() }
        start = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start, let area else { return }
        let here = event.locationInWindow
        guard hypot(here.x - start.x, here.y - start.y) > 4 else { return }
        self.start = nil
        let items = area.urls().enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(index) * 4
            let icon = index == 0 ? area.preview() : NSWorkspace.shared.icon(forFile: url.path)
            item.setDraggingFrame(NSRect(x: offset, y: offset, width: 80, height: 60), contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}
