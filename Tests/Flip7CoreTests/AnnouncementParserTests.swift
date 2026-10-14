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

    @Test func dictationSegments() {
        #expect(scores("Max, 100 Florian 19 Christian 40") == ["Max": 100, "Florian": 19])
        #expect(scores("Max 112, Paul null, Leser 26") == ["Max": 112, "Paul": 0, "Lisa": 26])
        #expect(scores("Max fünf, Paul und leiser, 26") == ["Max": 5, "Paul": 26, "Lisa": 26])
    }

    @Test func glued() {
        #expect(scores("Max5 Paul:12.") == ["Max": 5, "Paul": 12])
    }

    private func lineup(_ text: String, known: [String]) -> (add: [String], remove: [String]) {
        let result = AnnouncementParser.parseLineup(text, known: known.compactMap(PlayerName.init))
        return (result.additions.map(\.value), result.removals.map(\.value))
    }

    @Test func parsesNamesAndReusesKnownSpelling() {
        let result = lineup("Martin, max und Florjan kristian", known: ["Christian", "Florian", "Max"])
        #expect(result.add == ["Martin", "Max", "Florian", "Christian"])
        #expect(result.remove.isEmpty)
    }

    @Test(arguments: [
        "Jonathan und Christian hinzufügen, Lisa raus",
        "Jonathan und Christian hinzu. Lisa raus.",
        "Jonathan und Christian dazu, Lisa bitte rausnehmen",
        "Ich möchte Jonathan und Christian noch mit dazu nehmen und Lisa raus",
        "Bitte Jonathan und Christian neu rein, Lisa raus",
    ])
    func ignoresGermanFillerWords(sentence: String) {
        let result = lineup(sentence, known: ["Lisa", "Max"])
        #expect(result.add == ["Jonathan", "Christian"])
        #expect(result.remove == ["Lisa"])
    }

    @Test func rausRemovesOnlyTheNameBeforeIt() {
        let result = lineup("Christian und Martin Jonathan raus", known: ["Florian", "Jonathan", "Max"])
        #expect(result.add == ["Christian", "Martin"])
        #expect(result.remove == ["Jonathan"])
    }

    @Test func rausInTheMiddle() {
        let result = lineup("Christian, Jonatan raus, Martin", known: ["Jonathan"])
        #expect(result.add == ["Christian", "Martin"])
        #expect(result.remove == ["Jonathan"])
    }

    @Test func rausRemovesNamesJoinedWithUnd() {
        let result = lineup("Christian, Jonathan und Max raus", known: ["Jonathan", "Max"])
        #expect(result.add == ["Christian"])
        #expect(Set(result.remove) == ["Jonathan", "Max"])
    }
}

@Suite struct LineupRegressionTests {
    @Test func rausWorksWhenNameIsBothInLineupAndKnown() {
        let jonathan = PlayerName("Jonathan.")!
        let result = AnnouncementParser.parseLineup("Christian und Martin Jonathan raus", known: [jonathan, jonathan])
        #expect(result.removals == [jonathan])
    }

    @Test func playerNameDropsSurroundingPunctuation() {
        #expect(PlayerName("Jonathan.")?.value == "Jonathan")
        #expect(PlayerName(" „Max“, ")?.value == "Max")
        #expect(PlayerName("...") == nil)
    }
}
