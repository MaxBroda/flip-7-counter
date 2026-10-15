import Foundation

public enum SharedGame: Sendable {
    case present(Game)
    case deleted(Game.ID)

    public var id: Game.ID {
        switch self {
        case .present(let game): game.id
        case .deleted(let id): id
        }
    }
}

public struct SharedHistory: Sendable {
    public let games: [SharedGame]
    public let resets: [PlayerReset]

    public init(games: [SharedGame], resets: [PlayerReset]) {
        self.games = games
        self.resets = resets
    }
}

public struct OutgoingChanges: Sendable {
    public let games: [Game]
    public let deletions: [Game.ID]
    public let resets: [PlayerReset]

    public var isEmpty: Bool { games.isEmpty && deletions.isEmpty && resets.isEmpty }
}

/// Lokale Änderungen, die noch nicht in der geteilten Historie angekommen sind.
/// Jeder Eintrag trägt eine Revision, damit eine Änderung während des Hochladens nicht als erledigt gilt.
public struct SyncOutbox: Codable, Sendable, Equatable {
    private var revision = 0
    private var games: [Game.ID: Int] = [:]
    private var deletions: [Game.ID: Int] = [:]
    private var resets: [PlayerName: Int] = [:]

    public init() {}

    public func holds(_ id: Game.ID) -> Bool {
        games[id] != nil || deletions[id] != nil
    }

    public func holds(_ name: PlayerName) -> Bool {
        resets[name] != nil
    }

    public mutating func publish(_ game: Game.ID) {
        revision += 1
        deletions[game] = nil
        games[game] = revision
    }

    public mutating func delete(_ game: Game.ID) {
        revision += 1
        games[game] = nil
        deletions[game] = revision
    }

    public mutating func publishReset(of name: PlayerName) {
        revision += 1
        resets[name] = revision
    }

    /// Stellt alles in die Warteschlange, was lokal liegt, aber in der geteilten Historie fehlt.
    public mutating func adopt(_ library: Library, absentFrom shared: SharedHistory) {
        let sharedGames = Set(shared.games.map(\.id))
        let sharedResets = Set(shared.resets.map(\.name))
        for game in library.finished where !sharedGames.contains(game.id) && !holds(game.id) {
            publish(game.id)
        }
        for reset in library.resets where !sharedResets.contains(reset.name) && !holds(reset.name) {
            publishReset(of: reset.name)
        }
    }

    public func changes(in library: Library) -> OutgoingChanges {
        OutgoingChanges(
            games: library.games.filter { games[$0.id] != nil && $0.isFinished },
            deletions: Array(deletions.keys),
            resets: resets.keys.compactMap(library.reset(of:))
        )
    }

    public mutating func confirm(_ sent: SyncOutbox) {
        games = games.filter { sent.games[$0.key] != $0.value }
        deletions = deletions.filter { sent.deletions[$0.key] != $0.value }
        resets = resets.filter { sent.resets[$0.key] != $0.value }
    }
}
