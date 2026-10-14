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
        var game = try makeGame(["Max", "Paul", "Lisa"])
        game.book(draft(game, [10, 15, 8]))
        game.book(draft(game, [2, 25, nil]))
        #expect(game.players.map { game.total(of: $0) } == [12, 40, 8])
        #expect(game.total(of: game.players[0], afterRounds: 1) == 10)
        #expect(game.status == .running)
    }

    @Test func overshootRoundRanksByTotal() throws {
        var game = try makeGame(["Max", "Florian", "Christian"])
        game.book(draft(game, [187, 176, 165]))
        let status = game.book(draft(game, [14, 40, 0]))
        #expect(status == .finished(winner: game.players[1]))
        #expect(game.standings.map(\.player.name.value) == ["Florian", "Max", "Christian"])
        #expect(game.standings.map(\.total) == [216, 201, 165])
        #expect(game.isFinished)
    }

    @Test func tieOnTopRequiresAnotherRound() throws {
        var game = try makeGame(["Max", "Paul"])
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
        var game = try makeGame(["Max", "Paul"], target: 50)
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
        var game = try makeGame(["Max", "Paul"], target: 20)
        game.book(draft(game, [25, 0]))
        let stats = Library(games: [game]).leaderboard
        #expect(stats.first?.name.value == "Max")
        #expect(stats.first?.wins == 1)
        #expect(stats.last?.bustRate == 1)
    }
}
