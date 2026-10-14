public struct Points: Hashable, Codable, Comparable, Sendable, ExpressibleByIntegerLiteral {
    public static let range = 0...999
    public static let bust: Points = 0

    public let value: Int

    public init?(_ value: Int) {
        guard Self.range.contains(value) else { return nil }
        self.value = value
    }

    public init(integerLiteral value: Int) {
        precondition(Self.range.contains(value), "Punkte außerhalb von \(Self.range)")
        self.value = value
    }

    public var isBust: Bool { value == 0 }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        guard let points = Points(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Ungültige Punkte \(raw)"))
        }
        self = points
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
