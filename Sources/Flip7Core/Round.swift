import Foundation

public struct Round: Identifiable, Codable, Sendable {
    public let id: UUID
    private var scores: [UUID: Points]

    init(scores: [UUID: Points], id: UUID = UUID()) {
        self.id = id
        self.scores = scores
    }

    public func points(for player: Player) -> Points {
        scores[player.id] ?? .bust
    }

    mutating func set(_ points: Points, for player: Player) {
        scores[player.id] = points
    }
}
