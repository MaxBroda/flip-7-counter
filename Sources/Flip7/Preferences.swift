import AppKit
import Observation

struct Hotkey: Codable, Equatable {
    let keyCode: UInt16
    let label: String

    static let space = Hotkey(keyCode: 49, label: "Leertaste")

    init(keyCode: UInt16, label: String) {
        self.keyCode = keyCode
        self.label = label
    }

    init(event: NSEvent) {
        keyCode = event.keyCode
        label = Self.names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Taste \(event.keyCode)"
    }

    private static let names: [UInt16: String] = [
        49: "Leertaste", 36: "Return", 48: "Tab", 51: "Löschen", 53: "Esc", 76: "Enter",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

@Observable
final class Preferences {
    private let defaults: UserDefaults

    var hotkey: Hotkey { didSet { store(hotkey, for: "hotkey") } }
    var targetScore: Int { didSet { defaults.set(targetScore, forKey: "targetScore") } }
    var soundsEnabled: Bool { didSet { defaults.set(soundsEnabled, forKey: "soundsEnabled") } }
    var showsIntro: Bool { didSet { defaults.set(showsIntro, forKey: "showsIntro") } }

    static let targetRange = 50...1000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotkey = defaults.data(forKey: "hotkey").flatMap { try? JSONDecoder().decode(Hotkey.self, from: $0) } ?? .space
        targetScore = (defaults.object(forKey: "targetScore") as? Int) ?? 200
        soundsEnabled = (defaults.object(forKey: "soundsEnabled") as? Bool) ?? true
        showsIntro = (defaults.object(forKey: "showsIntro") as? Bool) ?? true
    }

    private func store(_ hotkey: Hotkey, for key: String) {
        defaults.set(try? JSONEncoder().encode(hotkey), forKey: key)
    }
}
