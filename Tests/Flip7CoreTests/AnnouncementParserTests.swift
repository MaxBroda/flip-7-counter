import Testing
@testable import Flip7Core

@Suite struct AnnouncementParserTests {
    private let players = ["Max", "Paul", "Lisa", "Florian"].compactMap(PlayerName.init).map { Player(name: $0) }

    private func scores(_ text: String) -> [String: Int] {
        let result = AnnouncementParser(players: players).parseScores(text)
        return Dictionary(uniqueKeysWithValues: players.compactMap { player in
            result.scores[player.id].map { (player.name.value, $0.value) }
        })
    }

    @Test func digits() {
        #expect(scores("Max 5 Paul 0 Lisa 26") == ["Max": 5, "Paul": 0, "Lisa": 26])
    }

    @Test func numberWords() {
        #expect(scores("Max fünf, Paul null, Lisa sechsundzwanzig") == ["Max": 5, "Paul": 0, "Lisa": 26])
        #expect(scores("Lisa sechs und zwanzig") == ["Lisa": 26])
        #expect(scores("Florian hundertzwölf") == ["Florian": 112])
    }

    @Test func groupedNamesShareValue() {
        #expect(scores("Max 5 Paul und Lisa 26") == ["Max": 5, "Paul": 26, "Lisa": 26])
    }

    @Test func bustWords() {
        #expect(scores("Paul hat sich verzockt, Max 12") == ["Paul": 0, "Max": 12])
    }

    @Test func fuzzyNames() {
        #expect(scores("Flo 14 Liza 3") == ["Florian": 14, "Lisa": 3])
    }

    @Test func glued() {
        #expect(scores("Max5 Paul:12.") == ["Max": 5, "Paul": 12])
    }

    @Test func parsesNamesAndReusesKnownSpelling() {
        let known = ["Christian", "Florian"].compactMap(PlayerName.init)
        let names = AnnouncementParser.parseNames("martin, Max und Florjan Kristian", known: known)
        #expect(names.map(\.value) == ["Martin", "Max", "Florian", "Christian"])
    }
}
