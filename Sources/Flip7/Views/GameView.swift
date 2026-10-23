import Flip7Core
import SwiftUI

struct GameView: View {
    @Environment(AppModel.self) private var model
    let game: Game
    @State private var confirmation: Confirmation?
    @State private var addsPlayer = false
    @State private var showsMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            StandingsStrip(game: game, draft: model.draft)
                .padding(.horizontal, Theme.panelInset)
            Panel {
                ScoreTable(game: game, draft: game.isFinished ? nil : model.draft, editable: true)
            }
            controls
        }
        .padding(28)
        .themedConfirmation($confirmation)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Ribbon(text: game.isFinished ? "Spiel beendet" : "Runde \(game.rounds.count + 1)")
            if case .tieBreak(let leaders) = game.status {
                Text("Gleichstand! Extrarunde für \(leaders.map(\.name.value).formatted(.list(type: .and)))")
                    .font(Theme.rounded(15, .heavy))
                    .foregroundStyle(Theme.paper)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Pill().fill(Theme.coral))
            }
            Spacer()
            if !game.isFinished {
                Button {
                    addsPlayer = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 22)).foregroundStyle(Theme.navy)
                }
                .buttonStyle(.plain)
                .hoverLift(1.15)
                .help("Spieler hinzufügen")
                .popover(isPresented: $addsPlayer, arrowEdge: .bottom) {
                    JoinPopover(game: game) { addsPlayer = false }
                }
            }
            Text("Ziel \(game.target)")
                .font(Theme.display(18))
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Pill().fill(Theme.yellow))
                .overlay(Pill().strokeBorder(Theme.navy, lineWidth: 2))
            Button {
                showsMenu = true
            } label: {
                Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.navy)
            }
            .buttonStyle(.plain)
            .hoverLift(1.15)
            .popover(isPresented: $showsMenu, arrowEdge: .bottom) {
                MenuPopover {
                    MenuRow(title: "Neues Spiel", detail: "Dieses bleibt gespeichert", symbol: "plus.circle.fill") {
                        showsMenu = false
                        model.closeGame()
                    }
                    MenuRow(title: "Spiel abbrechen …", detail: "Wird nicht gespeichert", symbol: "xmark.circle.fill", tint: Theme.coral) {
                        showsMenu = false
                        confirmation = Confirmation(
                            title: "Spiel wirklich abbrechen?",
                            message: "Das Spiel taucht nicht in der Historie auf.",
                            confirm: "Abbrechen und löschen",
                            action: model.abandonGame
                        )
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            VoiceHint(text: hint)
            if !model.unrecognized.isEmpty {
                Text("Nicht verstanden: \(model.unrecognized.joined(separator: " "))")
                    .font(Theme.rounded(12, .medium))
                    .foregroundStyle(Theme.coral)
                    .frame(maxWidth: 160)
            }
            Button {
                model.undoLastRound()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(ChunkyButtonStyle(fill: Theme.paper, size: 16))
            .keyboardShortcut("z", modifiers: .command)
            .disabled(game.rounds.isEmpty)
            if game.isFinished {
                Button("Siegerehrung") { model.isCelebrating = true }
                    .buttonStyle(ChunkyButtonStyle(size: 18))
            } else {
                Button("Runde buchen ↩", action: model.bookRound)
                    .buttonStyle(ChunkyButtonStyle(size: 18))
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var hint: String {
        let missing = model.draft.missing(in: game.players).map(\.name.value)
        let key = model.preferences.hotkey.label
        guard !model.draft.isEmpty, !missing.isEmpty else { return "\(key) halten: „Max 5, Oskar 0, Mila 26“" }
        return "Fehlt noch: \(missing.formatted(.list(type: .and))) – bekommt sonst –"
    }
}

private struct JoinPopover: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let onDone: () -> Void
    @State private var entry = ""

    private var suggestions: [PlayerName] {
        model.knownNames.filter { name in !game.players.contains { $0.name == name } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spieler hinzufügen").font(Theme.rounded(15, .heavy)).foregroundStyle(Theme.navy)
            Text("Steigt mit 0 Punkten ab Runde \(game.rounds.count + 1) ein.")
                .font(Theme.rounded(12, .medium))
                .foregroundStyle(Theme.navy.opacity(0.6))
            HStack {
                TextField("Name", text: $entry).onSubmit { add(entry) }
                Button("Hinzufügen") { add(entry) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(PlayerName(entry) == nil)
            }
            if !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { name in
                        SuggestionChip(name: name.value) { add(name.value) }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func add(_ name: String) {
        guard PlayerName(name) != nil else { return }
        model.join(name)
        onDone()
    }
}

private struct StandingsStrip: View {
    let game: Game
    let draft: RoundDraft

    var body: some View {
        Columns {
            ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                StandingCard(
                    player: player,
                    color: Theme.color(forPlayerAt: index),
                    total: game.total(of: player),
                    target: game.target,
                    pending: game.isFinished ? nil : draft.points(for: player),
                    isFlipSeven: draft.hasFlipSeven(player),
                    bustStreak: game.bustStreak(of: player),
                    isMissing: !draft.isEmpty && draft.points(for: player) == nil && !game.isFinished,
                    isLeader: game.leader == player
                )
            }
        }
    }
}

private struct StandingCard: View {
    let player: Player
    let color: Color
    let total: Int
    let target: Int
    let pending: Points?
    let isFlipSeven: Bool
    let bustStreak: Int
    let isMissing: Bool
    let isLeader: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Avatar(name: player.name.value, color: color, size: 24)
                Text(player.name.value)
                    .font(Theme.rounded(15, .heavy))
                    .foregroundStyle(Theme.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text("\(total)")
                .font(Theme.display(38))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.navy)
                .contentTransition(.numericText(value: Double(total)))
            ProgressBar(value: Double(total) / Double(target), color: color)
            pendingBadge
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16).fill(Theme.navy).offset(x: 3, y: 4)
            RoundedRectangle(cornerRadius: 16).fill(Theme.paper)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isMissing ? Theme.coral : Theme.navy, style: StrokeStyle(lineWidth: isMissing ? 3 : 2.5, dash: isMissing ? [7, 4] : []))
        }
        .overlay(alignment: .top) {
            if isLeader {
                Text("👑").font(.system(size: 24)).offset(y: -20).transition(.scale)
            }
        }
        .overlay(alignment: .topTrailing) {
            if bustStreak >= 3 {
                HStack(spacing: 2) {
                    Text("💀").font(.system(size: 16))
                    Text("\(bustStreak)×").font(Theme.rounded(12, .black)).foregroundStyle(Theme.paper)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Pill().fill(Theme.navy))
                .rotationEffect(.degrees(8))
                .offset(x: 8, y: -10)
                .help("\(bustStreak)× in Folge verzockt")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.4), value: total)
        .animation(.spring, value: pending)
        .animation(.spring, value: isLeader)
        .animation(.spring(duration: 0.4, bounce: 0.5), value: bustStreak)
    }

    @ViewBuilder
    private var pendingBadge: some View {
        if let pending {
            Text(pending.isBust ? "verzockt" : isFlipSeven ? "✨ +\(pending.value)" : "+\(pending.value)")
                .font(Theme.rounded(14, .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(pending.isBust ? Theme.paper : Theme.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Pill().fill(pending.isBust ? Theme.coral : Theme.yellow))
                .transition(.scale.combined(with: .opacity))
        } else {
            Text(isMissing ? "?" : " ")
                .font(Theme.rounded(14, .black))
                .foregroundStyle(Theme.coral)
                .padding(.vertical, 2)
        }
    }
}

private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Pill().fill(Theme.cream)
                Pill().fill(color).frame(width: proxy.size.width * min(max(value, 0), 1))
            }
            .overlay(Pill().strokeBorder(Theme.navy, lineWidth: 1.5))
        }
        .frame(height: 9)
    }
}
