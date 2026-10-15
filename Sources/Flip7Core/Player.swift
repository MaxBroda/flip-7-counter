import Foundation

public struct Player: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: PlayerName
    /// Anzahl der Runden, die schon gespielt waren, als der Spieler eingestiegen ist.
    public internal(set) var joinedAfter: Int

    public init(name: PlayerName, id: UUID = UUID(), joinedAfter: Int = 0) {
        self.id = id
        self.name = name
        self.joinedAfter = joinedAfter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(PlayerName.self, forKey: .name)
        joinedAfter = try container.decodeIfPresent(Int.self, forKey: .joinedAfter) ?? 0
    }
}
