import Foundation

public struct Round: Identifiable, Codable, Sendable {
    public let id: UUID
    private var scores: [UUID: Points]
    private var flipSevens: Set<UUID>

    init(scores: [UUID: Points], flipSevens: Set<UUID> = [], id: UUID = UUID()) {
        self.id = id
        self.scores = scores
        self.flipSevens = flipSevens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scores = try container.decode([UUID: Points].self, forKey: .scores)
        flipSevens = try container.decodeIfPresent(Set<UUID>.self, forKey: .flipSevens) ?? []
    }

    public func points(for player: Player) -> Points {
        scores[player.id] ?? .bust
    }

    public func hasFlipSeven(_ player: Player) -> Bool {
        flipSevens.contains(player.id)
    }

    mutating func set(_ points: Points, for player: Player) {
        scores[player.id] = points
        if points.isBust { flipSevens.remove(player.id) }
    }

    mutating func setFlipSeven(_ isFlipSeven: Bool, for player: Player) {
        if isFlipSeven, !points(for: player).isBust {
            flipSevens.insert(player.id)
        } else {
            flipSevens.remove(player.id)
        }
    }
}
