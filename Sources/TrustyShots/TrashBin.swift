import Foundation

/// Moves files to the macOS Trash and can put the latest batches back.
final class TrashBin {
    private struct Item {
        let original: URL
        let trashed: URL
    }

    private var batches: [[Item]] = []

    var canUndo: Bool { !batches.isEmpty }

    /// Returns how many files could not be moved.
    func trash(_ urls: [URL], undoable: Bool = true) -> Int {
        var items: [Item] = []
        for url in urls {
            var result: NSURL?
            guard (try? FileManager.default.trashItem(at: url, resultingItemURL: &result)) != nil else { continue }
            if let trashed = result as URL? { items.append(Item(original: url, trashed: trashed)) }
        }
        if undoable, !items.isEmpty { batches.append(items) }
        return urls.filter { FileManager.default.fileExists(atPath: $0.path) }.count
    }

    /// Restores the latest batch. Files that cannot be restored stay in the Trash.
    func undo() -> (restored: Int, failed: Int) {
        guard let batch = batches.popLast() else { return (0, 0) }
        let restored = batch.filter { item in
            // moveItem refuses to overwrite, so a newer file with that name is safe.
            (try? FileManager.default.moveItem(at: item.trashed, to: item.original)) != nil
        }.count
        return (restored, batch.count - restored)
    }
}
