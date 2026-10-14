import Flip7Core
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Screen: Hashable {
        case play
        case history
    }

    var screen: Screen = .play
    private(set) var library: Library
    private(set) var game: Game?
    private(set) var draft = RoundDraft()
    private(set) var lineup: [PlayerName] = []
    private(set) var unrecognized: [String] = []
    var isCelebrating = false
    var alert: String?

    let preferences: Preferences
    let speech: SpeechRecorder
    private let store: LibraryStore
    private let sounds: SoundPlayer
    private let hotkeys: HotkeyMonitor

    init(store: LibraryStore, preferences: Preferences, speech: SpeechRecorder) {
        self.store = store
        self.preferences = preferences
        self.speech = speech
        self.sounds = SoundPlayer { preferences.soundsEnabled }
        self.hotkeys = HotkeyMonitor { preferences.hotkey }
        do {
            library = try store.load()
        } catch {
            library = Library()
            let backup = try? store.quarantine()
            alert = "Spielstände konnten nicht gelesen werden. Die alte Datei liegt unter \(backup?.path ?? "–")."
        }
        game = library.current
        if game == nil { lineup = lastLineup }
        hotkeys.onPress = { [weak self] in self?.beginListening() }
        hotkeys.onRelease = { [weak self] in self?.endListening() }
        hotkeys.yieldsToTextInput = { [weak self] in self?.game == nil }
        hotkeys.install()
    }

    var knownNames: [PlayerName] { library.knownNames }

    var suggestions: [PlayerName] { knownNames.filter { !lineup.contains($0) } }

    var lastLineup: [PlayerName] {
        library.games.max { $0.startedAt < $1.startedAt }?.players.map(\.name).filter(knownNames.contains) ?? []
    }

    func prepareSpeech() async {
        await speech.prepare()
    }

    func captureNextKey(_ handler: @escaping (Hotkey) -> Void) {
        hotkeys.capture = { handler(Hotkey(event: $0)) }
    }

    func cancelKeyCapture() {
        hotkeys.capture = nil
    }

    func addToLineup(_ text: String) {
        for name in text.split(separator: ",").compactMap({ PlayerName(String($0)) }) where !lineup.contains(name) {
            lineup.append(knownNames.first { $0 == name } ?? name)
        }
    }

    func removeFromLineup(_ name: PlayerName) {
        lineup.removeAll { $0 == name }
    }

    func startGame() {
        do {
            let game = try Game(names: lineup, target: preferences.targetScore)
            self.game = game
            draft = RoundDraft()
            unrecognized = []
            persist(game)
            sounds.play(.book)
        } catch GameError.duplicatePlayer(let name) {
            alert = "\(name) ist doppelt dabei."
        } catch {
            alert = "Mindestens \(Game.minimumPlayers) Spieler, bitte."
        }
    }

    func rematch() {
        guard let game else { return }
        lineup = game.players.map(\.name)
        isCelebrating = false
        startGame()
    }

    func closeGame() {
        isCelebrating = false
        game = nil
        lineup = lastLineup
        draft = RoundDraft()
        unrecognized = []
    }

    func abandonGame() {
        if let game { library.remove(game.id) }
        save()
        closeGame()
    }

    func setDraft(_ text: String, for player: Player) {
        let value = text.trimmingCharacters(in: .whitespaces)
        if value.isEmpty {
            draft.set(nil, for: player)
        } else if let points = Int(value).flatMap(Points.init) {
            draft.set(points, for: player)
        }
    }

    func bookRound() {
        guard var game, !game.isFinished else { return }
        let status = game.book(draft)
        self.game = game
        draft = RoundDraft()
        unrecognized = []
        persist(game)
        switch status {
        case .finished:
            sounds.play(.win)
            isCelebrating = true
        case .tieBreak:
            sounds.play(.tie)
        case .running:
            sounds.play(.book)
        }
    }

    func undoLastRound() {
        guard var game, !game.rounds.isEmpty else { return }
        game.undoLastRound()
        self.game = game
        isCelebrating = false
        persist(game)
        sounds.play(.undo)
    }

    func correct(_ round: Round, of player: Player, to points: Points) {
        guard var game else { return }
        let wasFinished = game.isFinished
        game.correct(round: round.id, player: player, to: points)
        self.game = game
        persist(game)
        if game.isFinished && !wasFinished {
            sounds.play(.win)
            isCelebrating = true
        }
    }

    func deleteFromHistory(_ id: Game.ID) {
        library.remove(id)
        save()
    }

    func resetStats(of name: PlayerName) {
        library.resetStats(of: name)
        save()
    }

    func removePlayer(_ name: PlayerName) {
        library.removePlayer(name)
        lineup.removeAll { $0 == name }
        save()
    }

    func clearHistory() {
        library.clearHistory()
        save()
    }

    func beginListening() {
        guard screen == .play, !isCelebrating, game?.isFinished != true else { return }
        sounds.play(.listenStart)
        Task { await speech.start(hints: speechHints) }
    }

    func endListening() {
        guard speech.isListening else {
            Task { _ = await speech.stop() }
            return
        }
        sounds.play(.listenEnd)
        Task {
            let text = await speech.stop()
            guard !text.isEmpty else { return }
            apply(transcript: text)
        }
    }

    private var speechHints: [String] {
        let names = game.map { $0.players.map(\.name) } ?? knownNames
        return names.map(\.value) + ["null", "verzockt"]
    }

    private func apply(transcript: String) {
        if let game {
            let announcement = AnnouncementParser(players: game.players).parseScores(transcript)
            draft.merge(announcement)
            unrecognized = announcement.unrecognized
        } else {
            let announcement = AnnouncementParser.parseLineup(transcript, known: lineup + knownNames)
            announcement.additions.forEach { addToLineup($0.value) }
            announcement.removals.forEach(removeFromLineup)
        }
    }

    private func persist(_ game: Game) {
        library.save(game)
        save()
    }

    private func save() {
        do {
            try store.save(library)
        } catch {
            alert = "Speichern fehlgeschlagen: \(error)"
        }
    }
}
