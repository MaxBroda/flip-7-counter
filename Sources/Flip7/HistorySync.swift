import Flip7Core
import Foundation
import Observation

@MainActor
@Observable
final class HistorySync {
    enum Status: Equatable {
        case off
        case syncing
        case synced(Date)
        case failed(String)
    }

    private(set) var status: Status = .off
    private(set) var outbox: SyncOutbox
    private var remote: SupabaseHistory?
    private let outboxStore: JSONFileStore<SyncOutbox>
    private var isRunning = false
    private var runsAgain = false

    init(outboxStore: JSONFileStore<SyncOutbox>) {
        self.outboxStore = outboxStore
        outbox = (try? outboxStore.load()) ?? SyncOutbox()
    }

    var isConnected: Bool { remote != nil }

    func connect(_ config: SupabaseConfig?) {
        remote = config.map { SupabaseHistory(config: $0) }
        status = .off
    }

    func publish(_ game: Game) {
        guard game.isFinished else { return }
        outbox.publish(game.id)
        saveOutbox()
    }

    func delete(_ id: Game.ID) {
        outbox.delete(id)
        saveOutbox()
    }

    func publishReset(of name: PlayerName) {
        outbox.publishReset(of: name)
        saveOutbox()
    }

    /// Lädt die Warteschlange hoch, holt den geteilten Stand und übergibt ihn an `merge`.
    /// Läuft schon ein Abgleich, wird er danach einmal wiederholt statt parallel gestartet.
    func run(library: () -> Library, merge: (SharedHistory) -> Void) async {
        guard let remote else { return }
        guard !isRunning else {
            runsAgain = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        status = .syncing
        var passes = 0
        repeat {
            runsAgain = false
            passes += 1
            let sent = outbox
            do {
                let changes = sent.changes(in: library())
                if !changes.isEmpty { try await remote.push(changes) }
                outbox.confirm(sent)
                let shared = try await remote.fetch()
                guard self.remote === remote else { return }
                merge(shared)
                outbox.adopt(library(), absentFrom: shared)
                runsAgain = runsAgain || !outbox.changes(in: library()).isEmpty
                saveOutbox()
                status = .synced(.now)
            } catch {
                saveOutbox()
                status = .failed(String(describing: error))
                return
            }
        } while runsAgain && passes < 3
    }

    private func saveOutbox() {
        try? outboxStore.save(outbox)
    }
}
