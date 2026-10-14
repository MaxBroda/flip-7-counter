import Foundation

public struct Player: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: PlayerName

    public init(name: PlayerName, id: UUID = UUID()) {
        self.id = id
        self.name = name
    }
}
