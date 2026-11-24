import AppKit

/// macshot's Cmd+C copies without saving, so this saves those captures to the folder.
@MainActor
final class ClipboardSaver {
    var onError: ((String) -> Void)?

    private let folder: () -> URL
    private let defaultsKey = "saveMacshotCopies"
    private let macshotIDs: Set<String> = ["com.sw33tlie.macshot.offline", "com.sw33tlie.macshot.macshot"]
    private let board = NSPasteboard.general
    private var timer: Timer?
    private var changeCount = 0
    private var overlaySeen = Date.distantPast

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }

    init(folder: @escaping () -> URL) {
        self.folder = folder
        if isEnabled { start() }
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        timer?.invalidate()
        timer = nil
        if enabled { start() }
    }

    private func start() {
        // Whatever is on the clipboard already was not captured just now.
        changeCount = board.changeCount
        overlaySeen = .distantPast
        // macOS has no clipboard notification, so polling is the only way.
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    private func check() {
        if isOverlayOpen() { overlaySeen = Date() }
        guard board.changeCount != changeCount else { return }
        changeCount = board.changeCount
        // Copies from other apps must not be saved, so the overlay must have just been open.
        guard Date().timeIntervalSince(overlaySeen) < 3,
              let png = Self.capture(on: board) else { return }
        do {
            let folder = folder()
            // On a new Mac the folder may not exist yet.
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Self.save(png, in: folder, date: Date())
        } catch {
            onError?("Could not save capture: \(error.localizedDescription)")
        }
    }

    private func isOverlayOpen() -> Bool {
        let pids = Set(NSWorkspace.shared.runningApplications
            .filter { macshotIDs.contains($0.bundleIdentifier ?? "") }
            .map(\.processIdentifier))
        guard !pids.isEmpty,
              let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        else { return false }
        let screens = NSScreen.screens.map(\.frame.size)
        return windows.contains { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  // macshot may keep hidden overlays around for reuse.
                  (window[kCGWindowAlpha as String] as? Double ?? 0) > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return screens.contains { frame.width >= $0.width && frame.height >= $0.height }
        }
    }

    /// The image if the pasteboard holds only an image, as macshot writes it.
    nonisolated static func capture(on board: NSPasteboard) -> Data? {
        let types = board.types ?? []
        // Files come from Finder or our own Cmd+C; text and HTML come from other apps.
        let foreign: [NSPasteboard.PasteboardType] = [.fileURL, .string, .html, .URL]
        guard types.contains(.png), !types.contains(where: foreign.contains) else { return nil }
        return board.data(forType: .png)
    }

    nonisolated static func save(_ png: Data, in folder: URL, date: Date) throws {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd 'at' HH-mm-ss"
        let base = "Screenshot \(format.string(from: date))"
        for number in 1...50 {
            let name = number == 1 ? base : "\(base) \(number)"
            do {
                try png.write(to: folder.appendingPathComponent("\(name).png"), options: .withoutOverwriting)
                return
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}
