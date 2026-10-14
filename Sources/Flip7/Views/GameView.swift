import Flip7Core
import SwiftUI

struct GameView: View {
    @Environment(AppModel.self) private var model
    let game: Game
    @State private var confirmsAbandon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            StandingsStrip(game: game, draft: model.draft)
            Panel {
                ScoreTable(game: game, draft: game.isFinished ? nil : model.draft, editable: true)
            }
            controls
        }
        .padding(28)
        .confirmationDialog("Spiel wirklich abbrechen?", isPresented: $confirmsAbandon) {
            Button("Abbrechen und löschen", role: .destructive, action: model.abandonGame)
        } message: {
            Text("Das Spiel taucht nicht in der Historie auf.")
        }
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
            Text("Ziel \(game.target)")
                .font(Theme.display(18))
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Pill().fill(Theme.yellow))
                .overlay(Pill().strokeBorder(Theme.navy, lineWidth: 2))
            Menu {
                Button("Neues Spiel (dieses bleibt gespeichert)", action: model.closeGame)
                Button("Spiel abbrechen …", role: .destructive) { confirmsAbandon = true }
            } label: {
                Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.navy)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
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
        guard !model.draft.isEmpty, !missing.isEmpty else { return "\(key) halten: „Max 5, Paul 0, Lisa 26“" }
        return "Fehlt noch: \(missing.formatted(.list(type: .and))) – bekommt sonst –"
    }
}

private struct StandingsStrip: View {
    let game: Game
    let draft: RoundDraft

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                StandingCard(
                    player: player,
                    color: Theme.color(forPlayerAt: index),
                    total: game.total(of: player),
                    target: game.target,
                    pending: game.isFinished ? nil : draft.points(for: player),
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
            }
            Text("\(total)")
                .font(Theme.display(38))
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
        .animation(.spring(duration: 0.4, bounce: 0.4), value: total)
        .animation(.spring, value: pending)
        .animation(.spring, value: isLeader)
    }

    @ViewBuilder
    private var pendingBadge: some View {
        if let pending {
            Text(pending.isBust ? "verzockt" : "+\(pending.value)")
                .font(Theme.rounded(14, .black))
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
