import Foundation

enum Prefs {
    static let cleanAfterDays = 14
    private static let defaults = UserDefaults.standard

    /// `-folder <path>` on the command line overrides the saved folder for one run.
    static var folder: URL {
        get {
            if let path = defaults.string(forKey: "folder") {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return defaultFolder
        }
        set { defaults.set(newValue.path, forKey: "folder") }
    }

    static var hideAfterCopy: Bool {
        get { defaults.bool(forKey: "hideAfterCopy") }
        set { defaults.set(newValue, forKey: "hideAfterCopy") }
    }

    static var hideOnOutsideClick: Bool {
        get { defaults.object(forKey: "hideOnOutsideClick") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hideOnOutsideClick") }
    }

    static var autoClean: Bool {
        get { defaults.bool(forKey: "autoClean") }
        set { defaults.set(newValue, forKey: "autoClean") }
    }

    private static var defaultFolder: URL {
        let home = NSHomeDirectory()
        let fallback = URL(fileURLWithPath: home + "/Screenshots", isDirectory: true)
        guard let saved = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else {
            return fallback
        }
        let path = (saved as NSString).expandingTildeInPath
        // Trash All acts on every image in the folder, so shared folders are never picked automatically.
        let shared = ["", "/Desktop", "/Documents", "/Downloads", "/Pictures"].map { home + $0 }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return shared.contains(url.standardizedFileURL.path) ? fallback : url
    }
}
