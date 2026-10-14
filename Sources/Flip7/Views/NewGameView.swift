import Flip7Core
import SwiftUI

struct NewGameView: View {
    @Environment(AppModel.self) private var model
    @State private var entry = ""
    @FocusState private var entryFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Ribbon(text: "Neues Spiel")
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        lineup
                        entryRow
                        if !model.suggestions.isEmpty { suggestions }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VoiceHint(text: "\(model.preferences.hotkey.label) halten und Namen sagen – z. B. „Kasimir, Bruno, Mathilda raus“")
                HStack(spacing: 16) {
                    Button("Los geht's!", action: model.startGame)
                        .buttonStyle(ChunkyButtonStyle(size: 24))
                        .disabled(model.lineup.count < Game.minimumPlayers)
                        .opacity(model.lineup.count < Game.minimumPlayers ? 0.5 : 1)
                        .keyboardShortcut(.return, modifiers: .command)
                    Text("Ziel: \(model.preferences.targetScore) Punkte")
                        .font(Theme.rounded(15))
                        .foregroundStyle(Theme.navy.opacity(0.7))
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var lineup: some View {
        Group {
            if model.lineup.isEmpty {
                Text("Noch keine Spieler. Tippe Namen ein oder sag sie an.")
                    .font(Theme.rounded(15, .medium))
                    .foregroundStyle(Theme.navy.opacity(0.55))
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(Array(model.lineup.enumerated()), id: \.element) { index, name in
                        PlayerChip(name: name.value, color: Theme.color(forPlayerAt: index)) {
                            withAnimation(.spring) { model.removeFromLineup(name) }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring, value: model.lineup)
    }

    private var entryRow: some View {
        HStack {
            TextField("Name eingeben und ↩", text: $entry)
                .textFieldStyle(.plain)
                .font(Theme.rounded(17, .semibold))
                .foregroundStyle(Theme.navy)
                .focused($entryFocused)
                .onSubmit(add)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.navy.opacity(entryFocused ? 1 : 0.4), lineWidth: 2))
            Button("Hinzufügen", action: add)
                .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 14))
                .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bekannte Spieler")
                .font(Theme.rounded(12, .heavy))
                .foregroundStyle(Theme.navy.opacity(0.5))
            FlowLayout(spacing: 8) {
                ForEach(model.suggestions, id: \.self) { name in
                    SuggestionChip(name: name.value) {
                        withAnimation(.spring) { model.addToLineup(name.value) }
                    }
                }
            }
        }
    }

    private func add() {
        model.addToLineup(entry)
        entry = ""
        entryFocused = true
    }
}

private struct PlayerChip: View {
    let name: String
    let color: Color
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 8) {
                Avatar(name: name, color: color, size: 28)
                Text(name).font(Theme.rounded(17, .heavy)).foregroundStyle(Theme.navy)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(hovering ? Theme.coral : Theme.navy.opacity(0.55))
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .padding(.vertical, 6)
            .background(Pill().fill(color.opacity(hovering ? 0.45 : 0.25)))
            .overlay(Pill().strokeBorder(Theme.navy, lineWidth: 2))
            .contentShape(Pill())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .hoverLift()
        .accessibilityLabel("\(name) entfernen")
    }
}

private struct SuggestionChip: View {
    let name: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("+ \(name)")
                .font(Theme.rounded(14, hovering ? .heavy : .bold))
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Pill().fill(hovering ? Theme.mint : .clear))
                .overlay(
                    Pill().strokeBorder(Theme.navy.opacity(hovering ? 1 : 0.35), style: StrokeStyle(lineWidth: hovering ? 2 : 1.5, dash: hovering ? [] : [4, 3]))
                )
                .contentShape(Pill())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .hoverLift()
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

struct VoiceHint: View {
    @Environment(AppModel.self) private var model
    let text: String

    var body: some View {
        let speech = model.speech
        HStack(spacing: 14) {
            MicBadge(isListening: speech.isListening)
            VStack(alignment: .leading, spacing: 4) {
                if speech.isListening || !speech.transcript.isEmpty {
                    Text(speech.transcript.isEmpty ? "Ich höre zu …" : "„\(speech.transcript)“")
                        .font(Theme.rounded(17, .heavy))
                        .foregroundStyle(Theme.navy)
                        .contentTransition(.opacity)
                }
                if let problem = speech.problem {
                    Text(problem.message).font(Theme.rounded(13, .medium)).foregroundStyle(Theme.coral)
                } else {
                    Text(text).font(Theme.rounded(13, .medium)).foregroundStyle(Theme.navy.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(speech.isListening ? Theme.yellow.opacity(0.45) : Theme.mint.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.navy.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
        .contentShape(Rectangle())
        .pointerStyle(.link)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !speech.isListening { model.beginListening() } }
                .onEnded { _ in model.endListening() }
        )
        .animation(.spring(duration: 0.3), value: speech.isListening)
    }
}

struct MicBadge: View {
    let isListening: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isListening {
                Circle().fill(Theme.coral.opacity(0.35))
                    .frame(width: 54, height: 54)
                    .scaleEffect(pulse ? 1.25 : 0.85)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                    .onDisappear { pulse = false }
            }
            Circle().fill(isListening ? Theme.coral : Theme.paper)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Theme.navy, lineWidth: 2.5))
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isListening ? Theme.paper : Theme.navy)
        }
        .frame(width: 54, height: 54)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + size.width > width, !rows[rows.count - 1].indices.isEmpty {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
