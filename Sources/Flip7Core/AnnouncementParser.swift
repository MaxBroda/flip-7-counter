import Foundation

public struct ScoreAnnouncement: Equatable, Sendable {
    public let scores: [UUID: Points]
    public let unrecognized: [String]
}

public struct AnnouncementParser {
    private static let fillers: Set<String> = [
        "und", "hat", "haben", "sich", "punkte", "punkt", "macht", "bekommt", "kriegt", "mit", "ist", "sind",
        "der", "die", "das", "bei", "auch", "plus", "runde", "also", "ah", "ahm", "ok", "okay", "dann", "spieler",
    ]

    private let players: [Player]
    private let matcher: NameMatcher<Player>

    public init(players: [Player]) {
        self.players = players
        self.matcher = NameMatcher(players, name: \.name)
    }

    public func parseScores(_ text: String) -> ScoreAnnouncement {
        let tokens = Self.tokenize(text)
        var scores: [UUID: Points] = [:]
        var pending: [Player] = []
        var unrecognized: [String] = []
        var index = 0
        while index < tokens.count {
            if let (value, consumed) = readNumber(tokens, at: index) {
                if let points = Points(value) {
                    pending.forEach { scores[$0.id] = points }
                } else {
                    unrecognized.append(tokens[index])
                }
                pending.removeAll()
                index += consumed
            } else if let (player, consumed) = readPlayer(tokens, at: index) {
                if !pending.contains(player) { pending.append(player) }
                index += consumed
            } else {
                if !Self.fillers.contains(tokens[index]) { unrecognized.append(tokens[index]) }
                index += 1
            }
        }
        return ScoreAnnouncement(scores: scores, unrecognized: unrecognized)
    }

    public static func parseNames(_ text: String, known: [PlayerName]) -> [PlayerName] {
        let matcher = NameMatcher(known) { $0 }
        var names: [PlayerName] = []
        for token in tokenize(text) where !fillers.contains(token) && GermanNumber.parse(token) == nil {
            guard let name = matcher.match(token) ?? PlayerName(token), !names.contains(name) else { continue }
            names.append(name)
        }
        return names
    }

    static func tokenize(_ text: String) -> [String] {
        PlayerName.normalize(text)
            .replacingOccurrences(of: #"(\d)([^\d\s])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: #"([^\d\s])(\d)"#, with: "$1 $2", options: .regularExpression)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func readNumber(_ tokens: [String], at index: Int) -> (Int, Int)? {
        guard let value = GermanNumber.parse(tokens[index]) else { return nil }
        if (1...9).contains(value), index + 2 < tokens.count, tokens[index + 1] == "und",
           let tens = GermanNumber.parse(tokens[index + 2]), GermanNumber.isTens(tens) {
            return (tens + value, 3)
        }
        return (value, 1)
    }

    private func readPlayer(_ tokens: [String], at index: Int) -> (Player, Int)? {
        if matcher.hasMultiWordNames, index + 1 < tokens.count,
           let player = players.first(where: { $0.name.key == "\(tokens[index]) \(tokens[index + 1])" }) {
            return (player, 2)
        }
        guard !Self.fillers.contains(tokens[index]), let player = matcher.match(tokens[index]) else { return nil }
        return (player, 1)
    }
}
