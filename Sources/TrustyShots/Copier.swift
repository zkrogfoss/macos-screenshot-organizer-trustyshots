import AppKit

enum Copier {
    /// Terminals get paths to copies, so only the chosen screenshots are exposed, under space-free names.
    static let outbox = URL(
        fileURLWithPath: NSHomeDirectory() + "/Library/Caches/io.github.zkrogfoss.trustyshots/outbox",
        isDirectory: true)

    /// Puts the original files on the pasteboard for apps, plus outbox paths as text for terminals.
    static func copy(_ urls: [URL], to board: NSPasteboard = .general, outbox: URL = outbox) throws {
        let copies = try fill(outbox, with: urls)
        board.clearContents()
        guard board.writeObjects(urls.map { $0 as NSURL }),
              board.setString(copies.map(\.path).joined(separator: "\n"), forType: .string)
        else { throw CocoaError(.fileWriteUnknown) }
    }

    static func empty(_ outbox: URL = outbox) {
        let files = FileManager.default
        // The folder itself stays, because Claude Code settings can refer to it.
        let contents = (try? files.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)) ?? []
        contents.forEach { try? files.removeItem(at: $0) }
    }

    private static func fill(_ outbox: URL, with urls: [URL]) throws -> [URL] {
        let files = FileManager.default
        // Only the latest selection may stay readable.
        empty(outbox)
        // The outbox holds screenshots, so other users get no access.
        try files.createDirectory(at: outbox, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        // A new batch name keeps Claude Code from confusing this set with an earlier one.
        let batch = UUID().uuidString.prefix(8)
        return try urls.enumerated().map { index, url in
            let copy = outbox.appendingPathComponent("\(batch)-\(index + 1).\(url.pathExtension)")
            try files.copyItem(at: url, to: copy)
            return copy
        }
    }
}
