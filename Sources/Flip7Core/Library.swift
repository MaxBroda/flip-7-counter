import Foundation

public struct PlayerStats: Identifiable, Hashable, Sendable {
    public var id: String { name.key }
    public let name: PlayerName
    public let gamesPlayed: Int
    public let wins: Int
    public let bestRound: Int
    public let averageRound: Double
    public let bustRate: Double

    public var winRate: Double { gamesPlayed == 0 ? 0 : Double(wins) / Double(gamesPlayed) }
}

public struct Library: Codable, Sendable {
    public private(set) var games: [Game] = []

    public init(games: [Game] = []) {
        self.games = games
    }

    public var current: Game? { games.last { !$0.isFinished } }

    public var finished: [Game] {
        games.filter(\.isFinished).sorted { ($0.finishedAt ?? $0.startedAt) > ($1.finishedAt ?? $1.startedAt) }
    }

    public var knownNames: [PlayerName] {
        var seen = Set<PlayerName>()
        return games.sorted { $0.startedAt > $1.startedAt }
            .flatMap { $0.players.map(\.name) }
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

    public var leaderboard: [PlayerStats] {
        var rounds: [PlayerName: [Int]] = [:]
        var played: [PlayerName: Int] = [:]
        var wins: [PlayerName: Int] = [:]
        for game in finished {
            for player in game.players {
                played[player.name, default: 0] += 1
                rounds[player.name, default: []] += game.rounds.map { $0.points(for: player).value }
            }
            if case .finished(let winner) = game.status {
                wins[winner.name, default: 0] += 1
            }
        }
        return played.map { name, count in
            let scores = rounds[name] ?? []
            return PlayerStats(
                name: name,
                gamesPlayed: count,
                wins: wins[name] ?? 0,
                bestRound: scores.max() ?? 0,
                averageRound: scores.isEmpty ? 0 : Double(scores.reduce(0, +)) / Double(scores.count),
                bustRate: scores.isEmpty ? 0 : Double(scores.filter { $0 == 0 }.count) / Double(scores.count)
            )
        }
        .sorted {
            ($0.wins, $0.winRate, $0.averageRound, $1.name.key) > ($1.wins, $1.winRate, $1.averageRound, $0.name.key)
        }
    }
}

public enum LibraryStoreError: Error {
    case unreadable(underlying: Error)
    case unwritable(underlying: Error)
}

public final class LibraryStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationSupport() -> LibraryStore {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flip7Counter", isDirectory: true)
        return LibraryStore(fileURL: folder.appendingPathComponent("library.json"))
    }

    public func load() throws -> Library {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Library() }
        do {
            let data = try Data(contentsOf: fileURL)
            return try Self.decoder.decode(Library.self, from: data)
        } catch {
            throw LibraryStoreError.unreadable(underlying: error)
        }
    }

    @discardableResult
    public func quarantine() throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let target = fileURL.deletingPathExtension().appendingPathExtension("broken-\(stamp).json")
        try FileManager.default.moveItem(at: fileURL, to: target)
        return target
    }

    public func save(_ library: Library) throws {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(library).write(to: fileURL, options: .atomic)
        } catch {
            throw LibraryStoreError.unwritable(underlying: error)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
