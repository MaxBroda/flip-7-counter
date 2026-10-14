public struct Standing: Hashable, Sendable {
    public let place: Int
    public let player: Player
    public let total: Int
}

public enum GameStatus: Equatable, Sendable {
    case running
    case tieBreak(leaders: [Player])
    case finished(winner: Player)
}
