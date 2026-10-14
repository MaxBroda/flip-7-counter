import Flip7Core
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Ribbon(text: "Rangliste")
                if model.library.leaderboard.isEmpty {
                    Panel {
                        Text("Noch keine abgeschlossenen Spiele. Ab ins Getümmel!")
                            .font(Theme.rounded(15, .medium))
                            .foregroundStyle(Theme.navy.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Panel { Leaderboard(stats: model.library.leaderboard) }
                    Ribbon(text: "Spiele")
                    VStack(spacing: 14) {
                        ForEach(model.library.finished) { game in
                            GameCard(game: game)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct Leaderboard: View {
    @Environment(AppModel.self) private var model
    let stats: [PlayerStats]
    @State private var pending: PendingAction?

    private struct PendingAction: Identifiable {
        enum Kind { case reset, remove }
        let kind: Kind
        let name: PlayerName
        var id: String { "\(kind)-\(name.key)" }
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                ForEach(["", "Spieler", "Spiele", "Siege", "Quote", "Beste Runde", "Ø Runde", "Verzockt", ""], id: \.self) { title in
                    Text(title).font(Theme.rounded(12, .heavy)).foregroundStyle(Theme.navy.opacity(0.5))
                }
            }
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                GridRow {
                    Text(medal(index)).font(index < 3 ? .system(size: 20) : Theme.display(18)).foregroundStyle(Theme.navy)
                    Text(stat.name.value).font(Theme.rounded(16, .black))
                    Text("\(stat.gamesPlayed)")
                    Text("\(stat.wins)").font(Theme.display(18))
                    Text(stat.winRate.formatted(.percent.precision(.fractionLength(0))))
                    Text("\(stat.bestRound)")
                    Text(stat.averageRound.formatted(.number.precision(.fractionLength(1))))
                    Text(stat.bustRate.formatted(.percent.precision(.fractionLength(0)))).foregroundStyle(Theme.coral)
                    Menu {
                        Button("Statistik zurücksetzen …") { pending = PendingAction(kind: .reset, name: stat.name) }
                        Button("Aus Rangliste entfernen …", role: .destructive) { pending = PendingAction(kind: .remove, name: stat.name) }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.system(size: 17)).foregroundStyle(Theme.navy.opacity(0.6))
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .hoverLift(1.2)
                }
                .font(Theme.rounded(15, .bold))
                .foregroundStyle(Theme.navy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(item: $pending) { action in
            switch action.kind {
            case .reset:
                Alert(
                    title: Text("Statistik von \(action.name.value) zurücksetzen?"),
                    message: Text("Bisherige Spiele zählen nicht mehr für die Rangliste. Die Spiele selbst bleiben erhalten."),
                    primaryButton: .destructive(Text("Zurücksetzen")) { model.resetStats(of: action.name) },
                    secondaryButton: .cancel()
                )
            case .remove:
                Alert(
                    title: Text("\(action.name.value) entfernen?"),
                    message: Text("Verschwindet aus Rangliste und Vorschlägen, bis wieder mitgespielt wird. Die Spiele selbst bleiben erhalten."),
                    primaryButton: .destructive(Text("Entfernen")) { model.removePlayer(action.name) },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func medal(_ index: Int) -> String {
        ["🥇", "🥈", "🥉"].indices.contains(index) ? ["🥇", "🥈", "🥉"][index] : "\(index + 1)."
    }
}

private struct GameCard: View {
    @Environment(AppModel.self) private var model
    let game: Game
    @State private var expanded = false

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(duration: 0.35)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 14) {
                        Text("🏆").font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(winnerLine).font(Theme.rounded(17, .black)).foregroundStyle(Theme.navy)
                            Text(game.standings.dropFirst().map { "\($0.player.name.value) \($0.total)" }.joined(separator: " · "))
                                .font(Theme.rounded(13, .semibold))
                                .foregroundStyle(Theme.navy.opacity(0.6))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text((game.finishedAt ?? game.startedAt).formatted(date: .abbreviated, time: .shortened))
                            Text("\(game.rounds.count) Runden · Ziel \(game.target)")
                        }
                        .font(Theme.rounded(12, .semibold))
                        .foregroundStyle(Theme.navy.opacity(0.55))
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .foregroundStyle(Theme.navy)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if expanded {
                    ScoreTable(game: game, draft: nil, editable: false)
                        .frame(height: min(CGFloat(game.rounds.count) * 38 + 50, 420))
                        .transition(.opacity)
                }
            }
        }
        .hoverLift(1.01)
        .contextMenu {
            Button("Aus Historie löschen", role: .destructive) { model.deleteFromHistory(game.id) }
        }
    }

    private var winnerLine: String {
        guard case .finished(let winner) = game.status else { return "Unentschieden" }
        return "\(winner.name.value) gewinnt mit \(game.total(of: winner))"
    }
}
