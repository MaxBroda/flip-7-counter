import AppKit
import Flip7Core
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

enum HistorySpace: String, CaseIterable {
    /// Wird über Supabase mit den anderen Macs abgeglichen, sobald eine Verbindung eingerichtet ist.
    case shared
    /// Bleibt auf diesem Mac, damit private Runden nicht die geteilte Rangliste füllen.
    case personal

    var title: String {
        switch self {
        case .shared: "Geteilt"
        case .personal: "Privat"
        }
    }

    var symbol: String {
        switch self {
        case .shared: "person.3.fill"
        case .personal: "house.fill"
        }
    }

    var fileName: String {
        switch self {
        case .shared: "library.json"
        case .personal: "library-private.json"
        }
    }
}

@Observable
final class Preferences {
    private let defaults: UserDefaults

    var hotkey: Hotkey { didSet { store(hotkey, for: "hotkey") } }
    var targetScore: Int { didSet { defaults.set(targetScore, forKey: "targetScore") } }
    var soundsEnabled: Bool { didSet { defaults.set(soundsEnabled, forKey: "soundsEnabled") } }
    var showsIntro: Bool { didSet { defaults.set(showsIntro, forKey: "showsIntro") } }
    /// Namen, die die Spracherkennung kennen soll, auch bevor jemand damit gespielt hat.
    var names: [PlayerName] { didSet { defaults.set(names.map(\.value), forKey: "names") } }
    var historySpace: HistorySpace { didSet { defaults.set(historySpace.rawValue, forKey: "historySpace") } }
    var sharedHistory: SupabaseConfig? { didSet { defaults.set(try? sharedHistory.map(JSONEncoder().encode), forKey: "sharedHistory") } }

    static let targetRange = 50...1000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotkey = defaults.data(forKey: "hotkey").flatMap { try? JSONDecoder().decode(Hotkey.self, from: $0) } ?? .space
        targetScore = (defaults.object(forKey: "targetScore") as? Int) ?? 200
        soundsEnabled = (defaults.object(forKey: "soundsEnabled") as? Bool) ?? true
        showsIntro = (defaults.object(forKey: "showsIntro") as? Bool) ?? true
        names = (defaults.stringArray(forKey: "names") ?? []).compactMap(PlayerName.init)
        historySpace = defaults.string(forKey: "historySpace").flatMap(HistorySpace.init) ?? .shared
        sharedHistory = defaults.data(forKey: "sharedHistory").flatMap { try? JSONDecoder().decode(SupabaseConfig.self, from: $0) }
    }

    private func store(_ hotkey: Hotkey, for key: String) {
        defaults.set(try? JSONEncoder().encode(hotkey), forKey: key)
    }
}
