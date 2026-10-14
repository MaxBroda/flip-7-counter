import Foundation

public enum GameError: Error, Equatable {
    case notEnoughPlayers
    case duplicatePlayer(PlayerName)
    case invalidTarget
}

public struct Game: Identifiable, Codable, Sendable {
    public static let minimumPlayers = 2

    public let id: UUID
    public let startedAt: Date
    public private(set) var finishedAt: Date?
    public let players: [Player]
    public let target: Int
    public private(set) var rounds: [Round] = []

    public init(names: [PlayerName], target: Int, id: UUID = UUID(), startedAt: Date = .now) throws {
        guard names.count >= Self.minimumPlayers else { throw GameError.notEnoughPlayers }
        guard target > 0 else { throw GameError.invalidTarget }
        var seen = Set<PlayerName>()
        for name in names where !seen.insert(name).inserted {
            throw GameError.duplicatePlayer(name)
        }
        self.id = id
        self.startedAt = startedAt
        self.players = names.map { Player(name: $0) }
        self.target = target
    }

    public var isFinished: Bool { finishedAt != nil }

    public func total(of player: Player, afterRounds count: Int? = nil) -> Int {
        rounds.prefix(count ?? rounds.count).reduce(0) { $0 + $1.points(for: player).value }
    }

    public var standings: [Standing] {
        let totals = players.map { ($0, total(of: $0)) }
        let sorted = totals.enumerated()
            .sorted { $0.element.1 != $1.element.1 ? $0.element.1 > $1.element.1 : $0.offset < $1.offset }
            .map(\.element)
        return sorted.enumerated().map { index, entry in
            let place = (sorted.firstIndex { $0.1 == entry.1 } ?? index) + 1
            return Standing(place: place, player: entry.0, total: entry.1)
        }
    }

    public var status: GameStatus {
        let standings = standings
        guard let best = standings.first, best.total >= target else { return .running }
        let leaders = standings.filter { $0.total == best.total }.map(\.player)
        return leaders.count > 1 ? .tieBreak(leaders: leaders) : .finished(winner: best.player)
    }

    public var leader: Player? {
        guard !rounds.isEmpty, let first = standings.first, first.total > 0 else { return nil }
        return standings.filter { $0.total == first.total }.count == 1 ? first.player : nil
    }

    @discardableResult
    public mutating func book(_ draft: RoundDraft, at date: Date = .now) -> GameStatus {
        precondition(!isFinished, "Abgeschlossenes Spiel kann keine Runden mehr aufnehmen")
        let scores = Dictionary(uniqueKeysWithValues: players.map { ($0.id, draft.points(for: $0) ?? .bust) })
        rounds.append(Round(scores: scores))
        return refreshCompletion(at: date)
    }

    public mutating func undoLastRound() {
        guard !rounds.isEmpty else { return }
        rounds.removeLast()
        refreshCompletion(at: .now)
    }

    public mutating func correct(round roundID: Round.ID, player: Player, to points: Points) {
        guard let index = rounds.firstIndex(where: { $0.id == roundID }) else { return }
        rounds[index].set(points, for: player)
        refreshCompletion(at: finishedAt ?? .now)
    }

    @discardableResult
    private mutating func refreshCompletion(at date: Date) -> GameStatus {
        let status = status
        if case .finished = status {
            finishedAt = finishedAt ?? date
        } else {
            finishedAt = nil
        }
        return status
    }
}
