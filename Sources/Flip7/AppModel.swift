import Flip7Core
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Screen: Hashable {
        case play
        case history
        case settings
    }

    var screen: Screen = .play {
        didSet { if screen == .history { synchronize() } }
    }
    private(set) var space: HistorySpace
    private var libraries: [HistorySpace: Library] = [:]
    private(set) var library: Library {
        get { libraries[space] ?? Library() }
        set { libraries[space] = newValue }
    }
    private(set) var game: Game?
    private(set) var draft = RoundDraft()
    private(set) var lineup: [PlayerName] = []
    private(set) var unrecognized: [String] = []
    var isCelebrating = false
    private(set) var flipMoment: FlipMoment?
    private var celebratesAfterFlip = false
    var alert: String?

    let preferences: Preferences
    let speech: SpeechRecorder
    let sharing: HistorySync
    private let stores: (HistorySpace) -> JSONFileStore<Library>
    private let sounds: SoundPlayer
    private let hotkeys: HotkeyMonitor

    init(stores: @escaping (HistorySpace) -> JSONFileStore<Library>, sharing: HistorySync, preferences: Preferences, speech: SpeechRecorder) {
        self.stores = stores
        self.space = preferences.historySpace
        self.sharing = sharing
        self.preferences = preferences
        self.speech = speech
        self.sounds = SoundPlayer { preferences.soundsEnabled }
        self.hotkeys = HotkeyMonitor { preferences.hotkey }
        for space in HistorySpace.allCases {
            let store = stores(space)
            do {
                libraries[space] = try store.load() ?? Library()
            } catch {
                libraries[space] = Library()
                let backup = try? store.quarantine()
                alert = "Spielstände konnten nicht gelesen werden. Die alte Datei liegt unter \(backup?.path ?? "–")."
            }
        }
        game = library.current
        if game == nil { lineup = lastLineup }
        hotkeys.onPress = { [weak self] in self?.beginListening() }
        hotkeys.onRelease = { [weak self] in self?.endListening() }
        hotkeys.yieldsToTextInput = { [weak self] in self?.game == nil || self?.screen != .play }
        hotkeys.install()
        sharing.connect(preferences.sharedHistory)
        synchronize()
    }

    var knownNames: [PlayerName] {
        library.knownNames + preferences.names.filter { !library.knownNames.contains($0) }
    }

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

    func addName(_ text: String) {
        for name in text.split(separator: ",").compactMap({ PlayerName(String($0)) }) where !preferences.names.contains(name) {
            preferences.names.append(name)
        }
    }

    func removeName(_ name: PlayerName) {
        preferences.names.removeAll { $0 == name }
    }

    func join(_ text: String) {
        guard var game, let typed = PlayerName(text) else { return }
        do {
            try game.join(knownNames.first { $0 == typed } ?? typed)
            self.game = game
            persist(game)
            sounds.play(.book)
        } catch GameError.duplicatePlayer(let name) {
            alert = "\(name) spielt schon mit."
        } catch {
            alert = "Das Spiel ist schon beendet."
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
        if let game {
            library.remove(game.id)
            share { $0.delete(game.id) }
        }
        save()
        closeGame()
        synchronize()
    }

    /// Ein laufendes Spiel wandert mit, damit man auch nach dem Start noch umschalten kann.
    /// Beendete Spiele bleiben, wo sie gezählt wurden.
    func switchSpace(to target: HistorySpace) {
        guard target != space else { return }
        let running = game.flatMap { $0.isFinished ? nil : $0 }
        if let running {
            library.remove(running.id)
            save()
        }
        space = target
        preferences.historySpace = target
        if let running {
            library.save(running)
            save()
        } else if game != nil {
            closeGame()
        }
        synchronize()
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
        let flippers = game.rounds.last.map { round in game.players.filter(round.hasFlipSeven) } ?? []
        if !flippers.isEmpty {
            celebratesAfterFlip = game.isFinished
            showFlipMoment(of: flippers)
            return
        }
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
        flipMoment = nil
        celebratesAfterFlip = false
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

    func markFlipSeven(_ isFlipSeven: Bool, in round: Round, of player: Player) {
        guard var game else { return }
        game.markFlipSeven(isFlipSeven, round: round.id, player: player)
        self.game = game
        persist(game)
        if isFlipSeven { showFlipMoment(of: [player]) }
    }

    func endFlipMoment() {
        flipMoment = nil
        guard celebratesAfterFlip else { return }
        celebratesAfterFlip = false
        sounds.play(.win)
        isCelebrating = true
    }

    private func showFlipMoment(of players: [Player]) {
        flipMoment = FlipMoment(names: players.map(\.name.value))
        sounds.play(.flipSeven)
    }

    func deleteFromHistory(_ id: Game.ID) {
        library.remove(id)
        share { $0.delete(id) }
        save()
        synchronize()
    }

    func resetStats(of name: PlayerName) {
        library.resetStats(of: name)
        share { $0.publishReset(of: name) }
        save()
        synchronize()
    }

    func removePlayer(_ name: PlayerName) {
        library.removePlayer(name)
        share { $0.publishReset(of: name) }
        lineup.removeAll { $0 == name }
        save()
        synchronize()
    }

    var locksClearHistory: Bool { space == .shared && sharing.isConnected }

    func clearHistory() {
        guard !locksClearHistory else { return }
        library.clearHistory()
        save()
    }

    /// - Returns: `false`, wenn URL oder Key unbrauchbar sind.
    @discardableResult
    func connectSharedHistory(url: String, key: String) -> Bool {
        guard let config = SupabaseConfig(url: url, key: key) else { return false }
        preferences.sharedHistory = config
        sharing.connect(config)
        synchronize()
        return true
    }

    func disconnectSharedHistory() {
        preferences.sharedHistory = nil
        sharing.connect(nil)
    }

    func synchronize() {
        guard space == .shared, sharing.isConnected else { return }
        Task {
            // Fest auf die geteilte Historie, falls während des Abgleichs umgeschaltet wird.
            await sharing.run(library: { libraries[.shared] ?? Library() }) { shared in
                libraries[.shared, default: Library()].merge(shared, protecting: sharing.outbox)
                save(.shared)
            }
        }
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
            let utterance = await speech.stop()
            guard !utterance.text.isEmpty else { return }
            apply(utterance)
        }
    }

    private var speechHints: [String] {
        guard let game else { return knownNames.map(\.value) }
        return game.players.map(\.name.value) + AnnouncementParser.scoreVocabulary
    }

    private func apply(_ utterance: Utterance) {
        if let game {
            let parser = AnnouncementParser(players: game.players)
            draft.merge(parser.parseScores(utterance.live))
            let announcement = parser.parseScores(utterance.text)
            draft.merge(announcement)
            unrecognized = announcement.unrecognized
        } else {
            let announcement = AnnouncementParser.parseLineup(utterance.text, known: lineup + knownNames)
            announcement.additions.forEach { addToLineup($0.value) }
            announcement.removals.forEach(removeFromLineup)
        }
    }

    private func persist(_ game: Game) {
        library.save(game)
        save()
        if game.isFinished {
            share { $0.publish(game) }
            synchronize()
        }
    }

    /// Nur die geteilte Historie geht an Supabase.
    private func share(_ change: (HistorySync) -> Void) {
        guard space == .shared else { return }
        change(sharing)
    }

    private func save() {
        save(space)
    }

    private func save(_ space: HistorySpace) {
        do {
            try stores(space).save(libraries[space] ?? Library())
        } catch {
            alert = "Speichern fehlgeschlagen: \(error)"
        }
    }
}

struct FlipMoment: Identifiable {
    let id = UUID()
    let names: [String]
}
