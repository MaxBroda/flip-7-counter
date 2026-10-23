import Foundation

public struct PlayerStats: Identifiable, Hashable, Sendable {
    public var id: String { name.key }
    public let name: PlayerName
    public let gamesPlayed: Int
    public let wins: Int
    public let bestRound: Int
    public let highestWin: Int?
    public let averageRound: Double
    public let bustRate: Double
    public let flipSevens: Int

    public var winRate: Double { gamesPlayed == 0 ? 0 : Double(wins) / Double(gamesPlayed) }
}

public struct PlayerReset: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case zeroed
        case removed
    }

    public let name: PlayerName
    public let kind: Kind
    public let date: Date
}

public struct Library: Codable, Sendable {
    public private(set) var games: [Game] = []
    public private(set) var resets: [PlayerReset] = []

    public init(games: [Game] = []) {
        self.games = games
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        games = try container.decode([Game].self, forKey: .games)
        resets = try container.decodeIfPresent([PlayerReset].self, forKey: .resets) ?? []
    }

    public var current: Game? { games.last { !$0.isFinished } }

    public var finished: [Game] {
        games.filter(\.isFinished).sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
    }

    public var knownNames: [PlayerName] {
        var seen = Set<PlayerName>()
        return games.sorted { $0.startedAt > $1.startedAt }
            .flatMap { game in game.players.map(\.name).filter { !isHidden($0, in: game) } }
            .filter { seen.insert($0).inserted }
    }

    public mutating func save(_ game: Game) {
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index] = game
        } else {
            games.append(game)
        }
    }

    public mutating func remove(_ id: Game.ID) {
        games.removeAll { $0.id == id }
    }

    public mutating func resetStats(of name: PlayerName, at date: Date = .now) {
        record(PlayerReset(name: name, kind: .zeroed, date: date))
    }

    public mutating func removePlayer(_ name: PlayerName, at date: Date = .now) {
        record(PlayerReset(name: name, kind: .removed, date: date))
    }

    public mutating func clearHistory() {
        games.removeAll(where: \.isFinished)
        resets.removeAll()
    }

    public var leaderboard: [PlayerStats] {
        var rounds: [PlayerName: [Int]] = [:]
        var played: [PlayerName: Int] = [:]
        var wins: [PlayerName: Int] = [:]
        var highestWin: [PlayerName: Int] = [:]
        var flipSevens: [PlayerName: Int] = [:]
        for game in finished {
            for player in game.players where counts(game, for: player.name) {
                played[player.name, default: 0] += 1
                rounds[player.name, default: []] += game.rounds(playedBy: player).map { $0.points(for: player).value }
                flipSevens[player.name, default: 0] += game.rounds(playedBy: player).filter { $0.hasFlipSeven(player) }.count
            }
            if case .finished(let winner) = game.status, counts(game, for: winner.name) {
                wins[winner.name, default: 0] += 1
                highestWin[winner.name] = max(highestWin[winner.name] ?? 0, game.total(of: winner))
            }
        }
        for reset in resets where reset.kind == .zeroed && played[reset.name] == nil {
            played[reset.name] = 0
        }
        return played.map { name, count in
            let scores = rounds[name] ?? []
            return PlayerStats(
                name: name,
                gamesPlayed: count,
                wins: wins[name] ?? 0,
                bestRound: scores.max() ?? 0,
                highestWin: highestWin[name],
                averageRound: scores.isEmpty ? 0 : Double(scores.reduce(0, +)) / Double(scores.count),
                bustRate: scores.isEmpty ? 0 : Double(scores.filter { $0 == 0 }.count) / Double(scores.count),
                flipSevens: flipSevens[name] ?? 0
            )
        }
        .sorted {
            ($0.wins, $0.winRate, $0.averageRound, $1.name.key) > ($1.wins, $1.winRate, $1.averageRound, $0.name.key)
        }
    }

    func reset(of name: PlayerName) -> PlayerReset? {
        resets.last { $0.name == name }
    }

    private func counts(_ game: Game, for name: PlayerName) -> Bool {
        guard let reset = reset(of: name) else { return true }
        return (game.finishedAt ?? game.startedAt) > reset.date
    }

    private func isHidden(_ name: PlayerName, in game: Game) -> Bool {
        guard let reset = reset(of: name), reset.kind == .removed else { return false }
        return game.startedAt <= reset.date
    }

    public mutating func merge(_ shared: SharedHistory, protecting outbox: SyncOutbox) {
        for entry in shared.games where !outbox.holds(entry.id) {
            // Eine lokal wieder geöffnete Partie gehört dem Mac, an dem gerade gespielt wird.
            guard games.first(where: { $0.id == entry.id })?.isFinished != false else { continue }
            switch entry {
            case .present(let game) where game.isFinished: save(game)
            case .present: continue
            case .deleted(let id): remove(id)
            }
        }
        for reset in shared.resets where !outbox.holds(reset.name) {
            if let local = self.reset(of: reset.name), local.date >= reset.date { continue }
            record(reset)
        }
    }

    private mutating func record(_ reset: PlayerReset) {
        resets.removeAll { $0.name == reset.name }
        resets.append(reset)
    }
}

public enum FileStoreError: Error {
    case unreadable(underlying: Error)
    case unwritable(underlying: Error)
}

public final class JSONFileStore<Value: Codable> {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupport(_ name: String) -> JSONFileStore {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flip7Counter", isDirectory: true)
        return JSONFileStore(fileURL: folder.appendingPathComponent(name))
    }

    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            throw FileStoreError.unreadable(underlying: error)
        }
    }

    @discardableResult
    public func quarantine() throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let target = fileURL.deletingPathExtension().appendingPathExtension("broken-\(stamp).json")
        try FileManager.default.moveItem(at: fileURL, to: target)
        return target
    }

    public func save(_ value: Value) throws {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(value).write(to: fileURL, options: .atomic)
        } catch {
            throw FileStoreError.unwritable(underlying: error)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
