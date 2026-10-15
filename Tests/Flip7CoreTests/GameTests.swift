import Foundation
import Testing
@testable import Flip7Core

@Suite struct GameTests {
    private func makeGame(_ names: [String], target: Int = 200) throws -> Game {
        try Game(names: names.compactMap(PlayerName.init), target: target)
    }

    private func draft(_ game: Game, _ points: [Int?]) -> RoundDraft {
        var draft = RoundDraft()
        for (player, value) in zip(game.players, points) {
            draft.set(value.flatMap(Points.init), for: player)
        }
        return draft
    }

    @Test func accumulatesAndTreatsMissingAsBust() throws {
        var game = try makeGame(["Max", "Oskar", "Mila"])
        game.book(draft(game, [10, 15, 8]))
        game.book(draft(game, [2, 25, nil]))
        #expect(game.players.map { game.total(of: $0) } == [12, 40, 8])
        #expect(game.total(of: game.players[0], afterRounds: 1) == 10)
        #expect(game.status == .running)
    }

    @Test func overshootRoundRanksByTotal() throws {
        var game = try makeGame(["Max", "Valentin", "Kasimir"])
        game.book(draft(game, [187, 176, 165]))
        let status = game.book(draft(game, [14, 40, 0]))
        #expect(status == .finished(winner: game.players[1]))
        #expect(game.standings.map(\.player.name.value) == ["Valentin", "Max", "Kasimir"])
        #expect(game.standings.map(\.total) == [216, 201, 165])
        #expect(game.isFinished)
    }

    @Test func tieOnTopRequiresAnotherRound() throws {
        var game = try makeGame(["Max", "Oskar"])
        let status = game.book(draft(game, [200, 200]))
        #expect(status == .tieBreak(leaders: game.players))
        #expect(!game.isFinished)
        game.book(draft(game, [5, 0]))
        #expect(game.status == .finished(winner: game.players[0]))
    }

    @Test func sharedPlacesForEqualTotals() throws {
        var game = try makeGame(["A", "B", "C"])
        game.book(draft(game, [50, 30, 30]))
        #expect(game.standings.map(\.place) == [1, 2, 2])
    }

    @Test func undoReopensFinishedGame() throws {
        var game = try makeGame(["Max", "Oskar"], target: 50)
        game.book(draft(game, [60, 10]))
        #expect(game.isFinished)
        game.undoLastRound()
        #expect(!game.isFinished)
        #expect(game.rounds.isEmpty)
    }

    @Test func rejectsDuplicateNames() {
        #expect(throws: GameError.duplicatePlayer(PlayerName("max")!)) {
            try makeGame(["Max", "max"])
        }
    }

    @Test func leaderboardCountsWins() throws {
        var game = try makeGame(["Max", "Oskar"], target: 20)
        game.book(draft(game, [25, 0]))
        let stats = Library(games: [game]).leaderboard
        #expect(stats.first?.name.value == "Max")
        #expect(stats.first?.wins == 1)
        #expect(stats.last?.bustRate == 1)
    }

    @Test func latecomerStartsAtZeroAndSkipsEarlierRounds() throws {
        var game = try makeGame(["Max", "Oskar"])
        game.book(draft(game, [10, 0]))
        try game.join(PlayerName("Omar")!)
        let omar = game.players[2]
        game.book(draft(game, [5, 5, 12]))
        #expect(game.total(of: omar) == 12)
        #expect(game.rounds(playedBy: omar).count == 1)
        #expect(!game.hasJoined(omar, by: 0))
        #expect(throws: GameError.duplicatePlayer(PlayerName("omar")!)) { try game.join(PlayerName("omar")!) }
    }

    @Test func latecomerStatsIgnoreRoundsBeforeJoining() throws {
        var game = try makeGame(["Max", "Oskar"], target: 30)
        game.book(draft(game, [10, 0]))
        try game.join(PlayerName("Omar")!)
        game.book(draft(game, [25, 5, 8]))
        let stats = try #require(Library(games: [game]).leaderboard.first { $0.name.value == "Omar" })
        #expect(stats.averageRound == 8)
        #expect(stats.bustRate == 0)
    }

    @Test func undoBeforeJoiningMovesEntryToCurrentRound() throws {
        var game = try makeGame(["Max", "Oskar"])
        game.book(draft(game, [10, 0]))
        try game.join(PlayerName("Omar")!)
        game.undoLastRound()
        #expect(game.players[2].joinedAfter == 0)
    }

    @Test func decodesPlayersWithoutJoinRound() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Max"}"#.data(using: .utf8)!
        #expect(try JSONDecoder().decode(Player.self, from: json).joinedAfter == 0)
    }
}

@Suite struct LibraryTests {
    private func finishedGame(_ names: [String], _ points: [Int], at date: Date) throws -> Game {
        var game = try Game(names: names.compactMap(PlayerName.init), target: 10, startedAt: date)
        var draft = RoundDraft()
        for (player, value) in zip(game.players, points) { draft.set(Points(value), for: player) }
        game.book(draft, at: date)
        return game
    }

    @Test func resetZeroesStatsButKeepsPlayer() throws {
        let max = PlayerName("Max")!
        var library = Library(games: [try finishedGame(["Max", "Oskar"], [20, 5], at: .distantPast)])
        library.resetStats(of: max)
        let stats = try #require(library.leaderboard.first { $0.name == max })
        #expect(stats.gamesPlayed == 0)
        #expect(stats.wins == 0)
        #expect(library.knownNames.contains(max))
    }

    @Test func removeHidesPlayerUntilNextGame() throws {
        let oskar = PlayerName("Oskar")!
        var library = Library(games: [try finishedGame(["Max", "Oskar"], [20, 5], at: .distantPast)])
        library.removePlayer(oskar)
        #expect(!library.leaderboard.contains { $0.name == oskar })
        #expect(!library.knownNames.contains(oskar))
        library.save(try finishedGame(["Oskar", "Max"], [30, 0], at: .now.addingTimeInterval(5)))
        #expect(library.leaderboard.first { $0.name == oskar }?.wins == 1)
        #expect(library.knownNames.contains(oskar))
    }

    @Test func highestWinTracksBestWinningTotal() throws {
        let library = Library(games: [
            try finishedGame(["Max", "Oskar"], [20, 5], at: .distantPast),
            try finishedGame(["Max", "Oskar"], [36, 12], at: .now),
            try finishedGame(["Max", "Oskar"], [3, 15], at: .now),
        ])
        let stats = Dictionary(uniqueKeysWithValues: library.leaderboard.map { ($0.name.value, $0) })
        #expect(stats["Max"]?.highestWin == 36)
        #expect(stats["Oskar"]?.highestWin == 15)
    }

    @Test func highestWinIsNilWithoutWins() throws {
        let library = Library(games: [try finishedGame(["Max", "Oskar"], [20, 5], at: .now)])
        #expect(library.leaderboard.first { $0.name.value == "Oskar" }?.highestWin == nil)
    }

    @Test func clearHistoryKeepsRunningGame() throws {
        let running = try Game(names: ["A", "B"].compactMap(PlayerName.init), target: 200)
        var library = Library(games: [try finishedGame(["Max", "Oskar"], [20, 5], at: .now), running])
        library.clearHistory()
        #expect(library.games.map(\.id) == [running.id])
        #expect(library.leaderboard.isEmpty)
    }

    @Test func decodesFilesWithoutResets() throws {
        let json = #"{"games":[]}"#.data(using: .utf8)!
        #expect(try JSONDecoder().decode(Library.self, from: json).resets.isEmpty)
    }
}
