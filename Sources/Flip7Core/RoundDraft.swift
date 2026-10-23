import Foundation

public struct RoundDraft: Sendable, Equatable {
    public private(set) var scores: [UUID: Points] = [:]
    public private(set) var flipSevens: Set<UUID> = []

    public init() {}

    public var isEmpty: Bool { scores.isEmpty }

    public func points(for player: Player) -> Points? {
        scores[player.id]
    }

    public func hasFlipSeven(_ player: Player) -> Bool {
        flipSevens.contains(player.id)
    }

    public mutating func set(_ points: Points?, for player: Player) {
        scores[player.id] = points
        if points?.isBust == true { flipSevens.remove(player.id) }
    }

    public mutating func merge(_ announcement: ScoreAnnouncement) {
        scores.merge(announcement.scores) { _, new in new }
        flipSevens.formUnion(announcement.flipSevens)
        flipSevens = flipSevens.filter { scores[$0]?.isBust != true }
    }

    public func missing(in players: [Player]) -> [Player] {
        players.filter { scores[$0.id] == nil }
    }
}
