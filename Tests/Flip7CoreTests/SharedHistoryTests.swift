import Foundation
import Testing
@testable import Flip7Core

@Suite struct SharedHistoryTests {
    private func finishedGame(_ names: [String] = ["Max", "Oskar"], at date: Date = .now) throws -> Game {
        var game = try Game(names: names.compactMap(PlayerName.init), target: 10, startedAt: date)
        var draft = RoundDraft()
        draft.set(Points(20), for: game.players[0])
        game.book(draft, at: date)
        return game
    }

    @Test func mergeAddsAndDeletesSharedGames() throws {
        let kept = try finishedGame()
        let deleted = try finishedGame()
        let incoming = try finishedGame(["Mila", "Bruno"])
        var library = Library(games: [kept, deleted])
        library.merge(SharedHistory(games: [.present(kept), .deleted(deleted.id), .present(incoming)], resets: []), protecting: SyncOutbox())
        #expect(Set(library.games.map(\.id)) == [kept.id, incoming.id])
    }

    @Test func mergeLeavesReopenedAndPendingGamesAlone() throws {
        var reopened = try finishedGame()
        reopened.undoLastRound()
        let pending = try finishedGame()
        var outbox = SyncOutbox()
        outbox.delete(pending.id)
        var library = Library(games: [reopened])
        library.merge(SharedHistory(games: [.present(try finishedGame()), .deleted(reopened.id), .present(pending)], resets: []), protecting: outbox)
        #expect(library.games.contains { $0.id == reopened.id })
        #expect(!library.games.contains { $0.id == pending.id })
    }

    @Test func mergeKeepsNewerReset() throws {
        let max = PlayerName("Max")!
        var library = Library()
        library.resetStats(of: max, at: Date(timeIntervalSince1970: 200))
        let older = PlayerReset(name: max, kind: .removed, date: Date(timeIntervalSince1970: 100))
        library.merge(SharedHistory(games: [], resets: [older]), protecting: SyncOutbox())
        #expect(library.resets.map(\.kind) == [.zeroed])
        let newer = PlayerReset(name: max, kind: .removed, date: Date(timeIntervalSince1970: 300))
        library.merge(SharedHistory(games: [], resets: [newer]), protecting: SyncOutbox())
        #expect(library.resets.map(\.kind) == [.removed])
    }

    @Test func confirmKeepsChangesMadeWhileUploading() throws {
        let game = try finishedGame()
        let library = Library(games: [game])
        var outbox = SyncOutbox()
        outbox.publish(game.id)
        let sent = outbox
        outbox.publish(game.id)
        outbox.confirm(sent)
        #expect(outbox.changes(in: library).games.map(\.id) == [game.id])
        outbox.confirm(outbox)
        #expect(outbox.changes(in: library).isEmpty)
    }

    @Test func adoptQueuesOnlyWhatTheSharedHistoryLacks() throws {
        let shared = try finishedGame()
        let local = try finishedGame()
        var library = Library(games: [shared, local])
        library.resetStats(of: PlayerName("Max")!)
        var outbox = SyncOutbox()
        outbox.adopt(library, absentFrom: SharedHistory(games: [.present(shared)], resets: []))
        let changes = outbox.changes(in: library)
        #expect(changes.games.map(\.id) == [local.id])
        #expect(changes.resets.map(\.name.value) == ["Max"])
    }

    @Test func configKeepsOnlyTheOrigin() {
        let config = SupabaseConfig(url: " https://abc.supabase.co/rest/v1/ ", key: " key ")
        #expect(config?.url.absoluteString == "https://abc.supabase.co")
        #expect(config?.key == "key")
        #expect(SupabaseConfig(url: "http://abc.supabase.co", key: "key") == nil)
        #expect(SupabaseConfig(url: "https://abc.supabase.co", key: "  ") == nil)
    }
}
