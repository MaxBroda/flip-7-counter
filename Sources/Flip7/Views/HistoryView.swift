import Flip7Core
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmation: Confirmation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    Ribbon(text: "Rangliste")
                    Label(model.space.title, systemImage: model.space.symbol)
                        .font(Theme.rounded(13, .heavy))
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Pill().fill(Theme.mint.opacity(0.6)))
                }
                if model.library.leaderboard.isEmpty {
                    Panel {
                        Text("Noch keine abgeschlossenen Spiele. Ab ins Getümmel!")
                            .font(Theme.rounded(15, .medium))
                            .foregroundStyle(Theme.navy.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Panel { Leaderboard(stats: model.library.leaderboard) { confirmation = $0 } }
                    Ribbon(text: "Spiele")
                    VStack(spacing: 14) {
                        ForEach(model.library.finished) { game in
                            GameCard(game: game) { confirmation = $0 }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .themedConfirmation($confirmation)
    }
}

private struct Leaderboard: View {
    @Environment(AppModel.self) private var model
    let stats: [PlayerStats]
    let confirm: (Confirmation) -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                ForEach(["", "Spieler", "Spiele", "Siege", "Quote", "Höchster Sieg", "Beste Runde", "Ø Runde", "Verzockt", ""], id: \.self) { title in
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
                    HighestWin(value: stat.highestWin, isRecord: stat.highestWin != nil && stat.highestWin == record)
                    Text("\(stat.bestRound)")
                    Text(stat.averageRound.formatted(.number.precision(.fractionLength(1))))
                    Text(stat.bustRate.formatted(.percent.precision(.fractionLength(0)))).foregroundStyle(Theme.coral)
                    PlayerMenu(name: stat.name, confirm: confirm)
                }
                .font(Theme.rounded(15, .bold))
                .foregroundStyle(Theme.navy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var record: Int? { stats.compactMap(\.highestWin).max() }

    private func medal(_ index: Int) -> String {
        ["🥇", "🥈", "🥉"].indices.contains(index) ? ["🥇", "🥈", "🥉"][index] : "\(index + 1)."
    }
}

private struct PlayerMenu: View {
    @Environment(AppModel.self) private var model
    let name: PlayerName
    let confirm: (Confirmation) -> Void
    @State private var showsMenu = false

    var body: some View {
        MoreButton { showsMenu = true }
            .popover(isPresented: $showsMenu, arrowEdge: .bottom) {
                MenuPopover {
                    MenuRow(title: "Statistik zurücksetzen …", detail: "Spiele bleiben erhalten", symbol: "arrow.counterclockwise.circle.fill") {
                        showsMenu = false
                        confirm(Confirmation(
                            title: "Statistik von \(name.value) zurücksetzen?",
                            message: "Bisherige Spiele zählen nicht mehr für die Rangliste. Die Spiele selbst bleiben erhalten.",
                            confirm: "Zurücksetzen"
                        ) { model.resetStats(of: name) })
                    }
                    MenuRow(title: "Aus Rangliste entfernen …", detail: "Bis wieder mitgespielt wird", symbol: "person.crop.circle.badge.xmark", tint: Theme.coral) {
                        showsMenu = false
                        confirm(Confirmation(
                            title: "\(name.value) entfernen?",
                            message: "Verschwindet aus Rangliste und Vorschlägen, bis wieder mitgespielt wird. Die Spiele selbst bleiben erhalten.",
                            confirm: "Entfernen"
                        ) { model.removePlayer(name) })
                    }
                }
            }
    }
}

private struct MoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis.circle").font(.system(size: 17)).foregroundStyle(Theme.navy.opacity(0.6))
        }
        .buttonStyle(.plain)
        .hoverLift(1.2)
    }
}

private struct HighestWin: View {
    let value: Int?
    let isRecord: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(value.map(String.init) ?? "–")
                .font(isRecord ? Theme.display(18) : Theme.rounded(15, .bold))
            if isRecord {
                Text("⭐️").font(.system(size: 13))
            }
        }
        .padding(.horizontal, isRecord ? 8 : 0)
        .padding(.vertical, isRecord ? 2 : 0)
        .background(Pill().fill(isRecord ? Theme.yellow : .clear))
    }
}

private struct GameCard: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let confirm: (Confirmation) -> Void
    @State private var expanded = false
    @State private var hoversTrash = false

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
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
                    Button {
                        confirm(Confirmation(
                            title: "Spiel löschen?",
                            message: "\(winnerLine). Das Spiel verschwindet aus Historie und Rangliste, \(deleteScope).",
                            confirm: "Löschen"
                        ) { model.deleteFromHistory(game.id) })
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(hoversTrash ? Theme.coral : Theme.navy)
                    }
                    .buttonStyle(.plain)
                    .onHover { hoversTrash = $0 }
                    .hoverLift(1.15)
                    .animation(.easeOut(duration: 0.15), value: hoversTrash)
                    .help("Aus Historie löschen")
                }
                if expanded {
                    ScoreTable(game: game, draft: nil, editable: false)
                        .frame(height: min(CGFloat(game.rounds.count) * 38 + 50, 420))
                        .transition(.opacity)
                }
            }
        }
        .hoverLift(1.01)
    }

    private var deleteScope: String {
        model.space == .shared && model.sharing.isConnected ? "auch auf den anderen Macs" : "nur auf diesem Mac"
    }

    private var winnerLine: String {
        guard case .finished(let winner) = game.status else { return "Unentschieden" }
        return "\(winner.name.value) gewinnt mit \(game.total(of: winner))"
    }
}
