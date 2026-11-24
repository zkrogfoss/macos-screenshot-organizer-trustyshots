import AppKit
import SwiftUI

struct Palette {
    let background: Color
    let tile: Color
    let text: Color
    let accent: Color
    let badgeText: Color

    static let system = Palette(
        background: Color(nsColor: .windowBackgroundColor),
        tile: Color(nsColor: .quaternarySystemFill),
        text: .primary, accent: .accentColor, badgeText: .white)

    /// The accents are light, so the badge number uses the dark background.
    static func dark(_ background: UInt32, _ tile: UInt32, _ text: UInt32, _ accent: UInt32) -> Palette {
        Palette(background: Color(hex: background), tile: Color(hex: tile), text: Color(hex: text),
                accent: Color(hex: accent), badgeText: Color(hex: background))
    }
}

enum Theme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case nord = "Nord"
    case gruvbox = "Gruvbox"
    case dracula = "Dracula"
    case catppuccin = "Catppuccin"
    case tokyoNight = "Tokyo Night"
    case solarized = "Solarized"
    case oneDark = "One Dark"

    var palette: Palette {
        switch self {
        case .light, .dark: .system
        case .nord: .dark(0x2E3440, 0x3B4252, 0xECEFF4, 0x88C0D0)
        case .gruvbox: .dark(0x282828, 0x3C3836, 0xEBDBB2, 0xFABD2F)
        case .dracula: .dark(0x282A36, 0x44475A, 0xF8F8F2, 0xBD93F9)
        case .catppuccin: .dark(0x1E1E2E, 0x313244, 0xCDD6F4, 0xCBA6F7)
        case .tokyoNight: .dark(0x1A1B26, 0x292E42, 0xC0CAF5, 0x7AA2F7)
        case .solarized: .dark(0x002B36, 0x073642, 0x93A1A1, 0x268BD2)
        case .oneDark: .dark(0x282C34, 0x3E4451, 0xABB2BF, 0x61AFEF)
        }
    }
}

@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published private(set) var palette = Palette.system
    private let defaultsKey = "theme"

    private var saved: Theme? {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Theme.init(rawValue:))
    }

    /// Until one is chosen, the app follows macOS.
    var current: Theme {
        if let saved { return saved }
        let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .darkAqua ? .dark : .light
    }

    func applySaved() {
        if let saved { apply(saved) }
    }

    func choose(_ theme: Theme) {
        UserDefaults.standard.set(theme.rawValue, forKey: defaultsKey)
        apply(theme)
    }

    private func apply(_ theme: Theme) {
        NSApp.appearance = NSAppearance(named: theme == .light ? .aqua : .darkAqua)
        palette = theme.palette
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255,
                  green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
