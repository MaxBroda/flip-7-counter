import Testing
@testable import Flip7Core

@Suite struct AnnouncementParserTests {
    private let players = ["Max", "Oskar", "Mila", "Valentin"].compactMap(PlayerName.init).map { Player(name: $0) }

    private func scores(_ text: String) -> [String: Int] {
        let result = AnnouncementParser(players: players).parseScores(text)
        return Dictionary(uniqueKeysWithValues: players.compactMap { player in
            result.scores[player.id].map { (player.name.value, $0.value) }
        })
    }

    @Test func digits() {
        #expect(scores("Max 5 Oskar 0 Mila 26") == ["Max": 5, "Oskar": 0, "Mila": 26])
    }

    @Test func numberWords() {
        #expect(scores("Max fünf, Oskar null, Mila sechsundzwanzig") == ["Max": 5, "Oskar": 0, "Mila": 26])
        #expect(scores("Mila sechs und zwanzig") == ["Mila": 26])
        #expect(scores("Valentin hundertzwölf") == ["Valentin": 112])
    }

    @Test func groupedNamesShareValue() {
        #expect(scores("Max 5 Oskar und Mila 26") == ["Max": 5, "Oskar": 26, "Mila": 26])
    }

    @Test func bustWords() {
        #expect(scores("Oskar hat sich verzockt, Max 12") == ["Oskar": 0, "Max": 12])
    }

    @Test func fuzzyNames() {
        #expect(scores("Vale 14 Milla 3") == ["Valentin": 14, "Mila": 3])
    }

    @Test func missingNumberDoesNotSpillOver() {
        #expect(scores("Oskar Schatzi Max null Mila 22") == ["Max": 0, "Mila": 22])
        #expect(scores("Oskar, Mila, Max 17") == ["Max": 17])
    }

    @Test func gluedNameAndNumber() {
        #expect(scores("Max fünf | Valentin, zwölf | Oskarhundert") == ["Max": 5, "Valentin": 12, "Oskar": 100])
        #expect(scores("Mila achtundzwanzig, Max nein") == ["Mila": 28, "Max": 9])
    }

    @Test func dictationSegments() {
        #expect(scores("Max, 100 Valentin 19 Kasimir 40") == ["Max": 100, "Valentin": 19])
        #expect(scores("Max 112, Oskar null, Meler 26") == ["Max": 112, "Oskar": 0, "Mila": 26])
        #expect(scores("Max fünf, Oskar und Meiler, 26") == ["Max": 5, "Oskar": 26, "Mila": 26])
    }

    @Test func glued() {
        #expect(scores("Max5 Oskar:12.") == ["Max": 5, "Oskar": 12])
    }

    private func lineup(_ text: String, known: [String]) -> (add: [String], remove: [String]) {
        let result = AnnouncementParser.parseLineup(text, known: known.compactMap(PlayerName.init))
        return (result.additions.map(\.value), result.removals.map(\.value))
    }

    @Test func parsesNamesAndReusesKnownSpelling() {
        let result = lineup("Bruno, max und Walentin casimir", known: ["Kasimir", "Valentin", "Max"])
        #expect(result.add == ["Bruno", "Max", "Valentin", "Kasimir"])
        #expect(result.remove.isEmpty)
    }

    @Test(arguments: [
        "Mathilda und Kasimir hinzufügen, Mila raus",
        "Mathilda und Kasimir hinzu. Mila raus.",
        "Mathilda und Kasimir dazu, Mila bitte rausnehmen",
        "Ich möchte Mathilda und Kasimir noch mit dazu nehmen und Mila raus",
        "Bitte Mathilda und Kasimir neu rein, Mila raus",
    ])
    func ignoresGermanFillerWords(sentence: String) {
        let result = lineup(sentence, known: ["Mila", "Max"])
        #expect(result.add == ["Mathilda", "Kasimir"])
        #expect(result.remove == ["Mila"])
    }

    @Test func rausRemovesOnlyTheNameBeforeIt() {
        let result = lineup("Kasimir und Bruno Mathilda raus", known: ["Valentin", "Mathilda", "Max"])
        #expect(result.add == ["Kasimir", "Bruno"])
        #expect(result.remove == ["Mathilda"])
    }

    @Test func rausInTheMiddle() {
        let result = lineup("Kasimir, Matilda raus, Bruno", known: ["Mathilda"])
        #expect(result.add == ["Kasimir", "Bruno"])
        #expect(result.remove == ["Mathilda"])
    }

    @Test func rausRemovesNamesJoinedWithUnd() {
        let result = lineup("Kasimir, Mathilda und Max raus", known: ["Mathilda", "Max"])
        #expect(result.add == ["Kasimir"])
        #expect(Set(result.remove) == ["Mathilda", "Max"])
    }
}

@Suite struct LineupRegressionTests {
    @Test func rausWorksWhenNameIsBothInLineupAndKnown() {
        let mathilda = PlayerName("Mathilda.")!
        let result = AnnouncementParser.parseLineup("Kasimir und Bruno Mathilda raus", known: [mathilda, mathilda])
        #expect(result.removals == [mathilda])
    }

    @Test func playerNameDropsSurroundingPunctuation() {
        #expect(PlayerName("Mathilda.")?.value == "Mathilda")
        #expect(PlayerName(" „Max“, ")?.value == "Max")
        #expect(PlayerName("...") == nil)
    }
}
