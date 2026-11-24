import AppKit
import UniformTypeIdentifiers

struct Shot: Identifiable, Hashable {
    let url: URL
    let date: Date
    /// Moving an old file into the folder must not make it look expired.
    let arrived: Date
    var id: URL { url }
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var shots: [Shot] = []
    /// Kept in click order, which is the order images are copied.
    @Published private(set) var selection: [URL] = []
    @Published private(set) var status: String?
    @Published private(set) var folder = Prefs.folder

    var onHover: (() -> Void)?
    private(set) var hovered: URL?

    private let bin = TrashBin()
    private var watch: DispatchSourceFileSystemObject?
    private var hideStatus: Task<Void, Never>?
    private let limit = 60

    init() { reload() }

    // MARK: Folder

    func setFolder(_ url: URL) {
        Prefs.folder = url
        folder = url
        // Consent to cleaning was given for the previous folder only.
        Prefs.autoClean = false
        watch?.cancel()
        watch = nil
        reload()
    }

    func reload() {
        // The folder may not have existed the last time.
        if watch == nil { startWatching() }
        do {
            shots = Array(try scan().sorted { $0.date > $1.date }.prefix(limit))
        } catch {
            shots = []
            // A missing folder is the normal first-run state.
            if FileManager.default.fileExists(atPath: folder.path) { showError("Cannot read \(folder.path)") }
        }
        let visible = Set(shots.map(\.url))
        selection.removeAll { !visible.contains($0) }
        if let hovered, !visible.contains(hovered) { setHovered(nil) }
    }

    /// Every image in the folder, including those beyond the display limit.
    private func scan() throws -> [Shot] {
        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey, .addedToDirectoryDateKey, .contentTypeKey, .isRegularFileKey,
        ]
        let files = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles)
        return files.compactMap { url in
            guard let info = try? url.resourceValues(forKeys: keys),
                  info.isRegularFile == true,
                  info.contentType?.conforms(to: .image) == true else { return nil }
            let date = info.contentModificationDate ?? Date()
            return Shot(url: url, date: date, arrived: max(date, info.addedToDirectoryDate ?? date))
        }
    }

    private func startWatching() {
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            // The folder event can fire before the image is fully written.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watch = source
    }

    // MARK: Selection

    func toggle(_ url: URL) {
        if let index = selection.firstIndex(of: url) {
            selection.remove(at: index)
        } else {
            selection.append(url)
        }
    }

    func selectAll() { selection = shots.map(\.url) }

    func clearSelection() { selection = [] }

    func setHovered(_ url: URL?) {
        hovered = url
        onHover?()
    }

    /// Dragging a selected tile takes the whole selection; any other tile goes alone.
    func dragURLs(from url: URL) -> [URL] {
        selection.contains(url) ? selection : [url]
    }

    func copySelection() -> Bool {
        guard !selection.isEmpty else { return false }
        do {
            try Copier.copy(selection)
            showBriefly("Copied \(selection.count)")
            return true
        } catch {
            showError("Copy failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Trash

    func trashSelection() {
        guard !selection.isEmpty else { return }
        trash(selection)
    }

    func trashAll() {
        // Trash exactly the files counted in the question, not ones that arrive meanwhile.
        guard let urls = try? scan().map(\.url), !urls.isEmpty else { return }
        guard confirm(
            "Move all \(urls.count) images to the Trash?",
            "This includes images in \(folder.path) that are not shown in the panel.",
            action: "Move to Trash") else { return }
        trash(urls)
    }

    func undoTrash() {
        guard bin.canUndo else { return }
        let result = bin.undo()
        reload()
        if result.failed == 0 {
            showBriefly("Restored \(result.restored)")
        } else {
            showError("Could not restore \(result.failed). Look in the Trash.")
        }
    }

    private func trash(_ urls: [URL]) {
        let failed = bin.trash(urls)
        // The outbox may hold copies of these screenshots.
        Copier.empty()
        reload()
        if failed == 0 {
            showBriefly("Moved \(urls.count) to the Trash. ⌘Z restores.")
        } else {
            showError("Could not move \(failed) of \(urls.count) to the Trash")
        }
    }

    // MARK: Auto-clean

    /// Returns whether cleaning is on afterwards.
    func setAutoClean(_ enabled: Bool) -> Bool {
        if enabled {
            let count = expired().count
            let allowed = confirm(
                "Clean \(folder.path) automatically?",
                "Every image older than \(Prefs.cleanAfterDays) days goes to the Trash, "
                    + "not only screenshots. \(count) would go now.",
                action: "Turn On")
            guard allowed else { return false }
        }
        Prefs.autoClean = enabled
        cleanExpired()
        return enabled
    }

    func cleanExpired() {
        guard Prefs.autoClean else { return }
        let urls = expired()
        guard !urls.isEmpty else { return }
        // Not undoable, so Cmd+Z always means the user's own last delete.
        let failed = bin.trash(urls, undoable: false)
        reload()
        if failed > 0 { showError("Auto-clean could not move \(failed) to the Trash") }
    }

    private func expired() -> [URL] {
        let limit = Date().addingTimeInterval(-Double(Prefs.cleanAfterDays) * 86_400)
        return ((try? scan()) ?? []).filter { $0.arrived < limit }.map(\.url)
    }

    // MARK: Messages

    func showError(_ message: String) {
        // Errors stay visible, so an earlier timer must not clear them.
        hideStatus?.cancel()
        status = message
    }

    func dismissStatus() {
        hideStatus?.cancel()
        status = nil
    }

    private func showBriefly(_ message: String) {
        status = message
        hideStatus?.cancel()
        hideStatus = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            // A newer message cancels this timer and starts its own.
            guard !Task.isCancelled else { return }
            self?.status = nil
        }
    }

    private func confirm(_ title: String, _ detail: String, action: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        // Cancel comes first so that Return never moves anything.
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: action).hasDestructiveAction = true
        NSApp.activate()
        return alert.runModal() == .alertSecondButtonReturn
    }
}
