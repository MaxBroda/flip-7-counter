import Flip7Core
import SwiftUI

struct ScoreTable: View {
    @Environment(AppModel.self) private var model
    let game: Game
    let draft: RoundDraft?
    let editable: Bool

    var body: some View {
        GeometryReader { geometry in
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        headerCell("#")
                        ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                            headerCell(player.name.value, dot: Theme.color(forPlayerAt: index))
                        }
                    }
                    Divider().overlay(Theme.navy).gridCellUnsizedAxes(.horizontal)
                    ForEach(Array(game.rounds.enumerated()), id: \.element.id) { index, round in
                        GridRow {
                            roundLabel(index + 1)
                            ForEach(game.players) { player in
                                ScoreCell(
                                    points: round.points(for: player),
                                    total: game.total(of: player, afterRounds: index + 1),
                                    editable: editable
                                ) { model.correct(round, of: player, to: $0) }
                            }
                        }
                        .background(index.isMultiple(of: 2) ? Theme.mint.opacity(0.18) : .clear)
                    }
                    if let draft {
                        GridRow {
                            roundLabel(game.rounds.count + 1)
                            ForEach(game.players) { player in
                                DraftCell(points: draft.points(for: player), base: game.total(of: player), onSubmit: model.bookRound) {
                                    model.setDraft($0, for: player)
                                }
                            }
                        }
                        .background(Theme.yellow.opacity(0.3))
                        .id("draft")
                    }
                }
                .padding(.bottom, 4)
                .frame(minWidth: geometry.size.width, alignment: .leading)
            }
            .onChange(of: game.rounds.count) {
                NSApp.keyWindow?.makeFirstResponder(nil)
                withAnimation { proxy.scrollTo("draft", anchor: .bottom) }
            }
        }
        }
        .frame(minHeight: 120)
    }

    private func headerCell(_ text: String, dot: Color? = nil) -> some View {
        HStack(spacing: 6) {
            if let dot {
                Circle().fill(dot).frame(width: 10, height: 10).overlay(Circle().stroke(Theme.navy, lineWidth: 1.5))
            }
            Text(text)
                .font(Theme.rounded(14, .black))
                .foregroundStyle(Theme.navy)
                .lineLimit(1)
        }
            .frame(minWidth: 40)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    private func roundLabel(_ number: Int) -> some View {
        Text("\(number)")
            .font(Theme.rounded(13, .bold))
            .foregroundStyle(Theme.navy.opacity(0.45))
            .frame(width: 36)
            .padding(.vertical, 8)
    }
}

private struct ScoreCell: View {
    let points: Points
    let total: Int
    let editable: Bool
    let onCorrect: (Points) -> Void

    @State private var editing = false
    @State private var hovering = false
    @State private var text = ""

    var body: some View {
        Button {
            text = "\(points.value)"
            editing = editable
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if points.isBust {
                    Text("–").font(Theme.display(22)).foregroundStyle(Theme.coral)
                    Text("\(total)").font(Theme.rounded(12, .bold)).foregroundStyle(Theme.navy.opacity(0.4))
                } else {
                    Text("\(total)").font(Theme.display(22)).foregroundStyle(Theme.navy)
                    Text("+\(points.value)").font(Theme.rounded(12, .bold)).foregroundStyle(Theme.teal)
                }
            }
            .frame(minWidth: 90, maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.yellow.opacity(editable && hovering ? 0.35 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointerStyle(editable ? .link : nil)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .popover(isPresented: $editing) {
            VStack(spacing: 10) {
                Text("Punkte dieser Runde").font(Theme.rounded(13, .heavy)).foregroundStyle(Theme.navy)
                TextField("0", text: $text)
                    .font(Theme.display(26))
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
                    .onSubmit(save)
                HStack {
                    Button("Verzockt") { text = "0"; save() }
                    Button("Speichern", action: save).keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
    }

    private func save() {
        if let value = Int(text.trimmingCharacters(in: .whitespaces)).flatMap(Points.init) {
            onCorrect(value)
        }
        editing = false
    }
}

private struct DraftCell: View {
    let points: Points?
    let base: Int
    let onSubmit: () -> Void
    let onChange: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("+").font(Theme.rounded(14, .black)).foregroundStyle(Theme.navy.opacity(0.4))
            TextField("?", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.display(22))
                .foregroundStyle(points?.isBust == true ? Theme.coral : Theme.navy)
                .frame(width: 48)
                .focused($focused)
                .onChange(of: text) { onChange(text) }
                .onSubmit {
                    focused = false
                    onSubmit()
                }
            if let points {
                Text(points.isBust ? "–" : "→ \(base + points.value)")
                    .font(Theme.rounded(12, .bold))
                    .foregroundStyle(Theme.navy.opacity(0.5))
            }
        }
        .frame(minWidth: 90, maxWidth: .infinity)
        .padding(.vertical, 6)
        .onAppear { sync() }
        .onChange(of: points) { if Int(text) != points?.value { sync() } }
    }

    private func sync() {
        text = points.map { "\($0.value)" } ?? ""
    }
}
