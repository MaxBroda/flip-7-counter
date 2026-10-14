import Flip7Core
import SwiftUI

struct VictoryView: View {
    @Environment(AppModel.self) private var model
    let game: Game

    @State private var raised = 0
    @State private var showsTitle = false

    private var podium: [Standing] { Array(game.standings.prefix(3)) }
    private var others: [Standing] { Array(game.standings.dropFirst(3)) }

    var body: some View {
        ZStack {
            Theme.navy.opacity(0.93).ignoresSafeArea()
            Confetti().ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 24) {
                if let winner = podium.first {
                    VStack(spacing: 6) {
                        OutlinedText(text: "\(winner.player.name.value.uppercased()) GEWINNT!", size: 52)
                            .scaleEffect(showsTitle ? 1 : 0.2)
                            .rotationEffect(.degrees(showsTitle ? -4 : -30))
                            .opacity(showsTitle ? 1 : 0)
                        Text("mit \(winner.total) Punkten nach \(game.rounds.count) Runden")
                            .font(Theme.rounded(16, .heavy))
                            .foregroundStyle(Theme.paper)
                            .opacity(showsTitle ? 1 : 0)
                    }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach([1, 0, 2].filter { $0 < podium.count }, id: \.self) { slot in
                        PodiumStep(
                            standing: podium[slot],
                            color: color(of: podium[slot].player),
                            rank: slot + 1,
                            isRaised: raised > (2 - slot)
                        )
                    }
                }
                if !others.isEmpty {
                    HStack(spacing: 18) {
                        ForEach(others, id: \.player.id) { standing in
                            Text("\(standing.place). \(standing.player.name.value) · \(standing.total)")
                                .font(Theme.rounded(15, .heavy))
                                .foregroundStyle(Theme.paper)
                        }
                    }
                    .opacity(raised >= 3 ? 1 : 0)
                }
                HStack(spacing: 14) {
                    Button("Revanche!", action: model.rematch)
                        .buttonStyle(ChunkyButtonStyle(size: 20))
                        .keyboardShortcut(.defaultAction)
                    Button("Neues Spiel", action: model.closeGame)
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 20))
                    Button("Tabelle ansehen") { model.isCelebrating = false }
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.paper, size: 16))
                }
                .opacity(raised >= 3 ? 1 : 0)
            }
            .padding(30)
        }
        .task {
            for step in 1...3 {
                try? await Task.sleep(for: .seconds(step == 1 ? 0.25 : 0.45))
                withAnimation(.spring(duration: 0.7, bounce: 0.45)) { raised = step }
            }
            withAnimation(.spring(duration: 0.8, bounce: 0.55)) { showsTitle = true }
        }
    }

    private func color(of player: Player) -> Color {
        Theme.color(forPlayerAt: game.players.firstIndex(of: player) ?? 0)
    }
}

private struct PodiumStep: View {
    let standing: Standing
    let color: Color
    let rank: Int
    let isRaised: Bool

    @State private var bounce = false

    private var height: CGFloat { [190, 135, 95][rank - 1] }
    private var stepColor: Color { [Theme.yellow, Theme.blue, Theme.coral][rank - 1] }

    var body: some View {
        VStack(spacing: 8) {
            if rank == 1 {
                Text("👑")
                    .font(.system(size: 40))
                    .offset(y: bounce ? -8 : 0)
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: bounce)
                    .onAppear { bounce = true }
            }
            Avatar(name: standing.player.name.value, color: color, size: rank == 1 ? 70 : 56)
            Text(standing.player.name.value)
                .font(Theme.rounded(rank == 1 ? 22 : 18, .black))
                .foregroundStyle(Theme.paper)
            Text("\(standing.total)")
                .font(Theme.display(rank == 1 ? 26 : 20))
                .foregroundStyle(Theme.yellow)
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                    .fill(stepColor)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14).stroke(Theme.navy, lineWidth: 3))
                OutlinedText(text: "\(standing.place)", size: 46, fill: Theme.paper, stroke: Theme.navy)
                    .padding(.top, 14)
            }
            .frame(width: 150, height: isRaised ? height : 0, alignment: .top)
            .clipped()
        }
        .opacity(isRaised ? 1 : 0)
        .scaleEffect(isRaised ? 1 : 0.6, anchor: .bottom)
    }
}

struct Confetti: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let size: CGSize
        let color: Color
    }

    private let pieces: [Piece] = {
        var generator = SeededGenerator(seed: UInt64(Date.now.timeIntervalSince1970))
        let colors = Theme.fan + [Theme.orange]
        return (0..<140).map { _ in
            Piece(
                x: .random(in: 0...1, using: &generator),
                delay: .random(in: 0...2.5, using: &generator),
                speed: .random(in: 0.12...0.3, using: &generator),
                sway: .random(in: 10...40, using: &generator),
                spin: .random(in: 2...7, using: &generator),
                size: CGSize(width: .random(in: 7...13, using: &generator), height: .random(in: 10...18, using: &generator)),
                color: colors.randomElement(using: &generator)!
            )
        }
    }()

    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let progress = (t * piece.speed).truncatingRemainder(dividingBy: 1.15) - 0.1
                    let point = CGPoint(x: piece.x * size.width + sin(t * 2) * piece.sway, y: progress * size.height)
                    var layer = context
                    layer.translateBy(x: point.x, y: point.y)
                    layer.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2, width: piece.size.width, height: piece.size.height * abs(cos(t * piece.spin)))
                    layer.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color))
                }
            }
        }
    }
}
