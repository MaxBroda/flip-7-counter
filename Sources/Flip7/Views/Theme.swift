import SwiftUI

enum Theme {
    static let cream = Color(hex: 0xFCF6DE)
    static let paper = Color(hex: 0xFFFDF3)
    static let navy = Color(hex: 0x2E2F7F)
    static let teal = Color(hex: 0x45C2B6)
    static let mint = Color(hex: 0xA6DCD8)
    static let yellow = Color(hex: 0xFCDB4C)
    static let coral = Color(hex: 0xF0625A)
    static let pink = Color(hex: 0xEC4F6E)
    static let blue = Color(hex: 0x76A3DA)
    static let lime = Color(hex: 0xD6DD2C)
    static let orange = Color(hex: 0xF7A72A)
    static let purple = Color(hex: 0x9B5BB5)

    static let fan: [Color] = [teal, coral, blue, yellow, pink, paper, lime]
    static let panelInset: CGFloat = 18
    static let players: [Color] = [teal, coral, blue, orange, pink, purple, lime, yellow]

    static func color(forPlayerAt index: Int) -> Color {
        players[index % players.count]
    }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct OutlinedText: View {
    let text: String
    var size: CGFloat
    var fill: Color = Theme.yellow
    var stroke: Color = Theme.coral
    var outline: Color = Theme.navy

    var body: some View {
        let width = max(1.5, size / 22)
        let base = Text(text).font(Theme.display(size)).tracking(size / 30)
        ZStack {
            ForEach(0..<16, id: \.self) { step in
                base.foregroundStyle(outline).offset(offset(step, radius: width * 2.4, shift: width * 1.6))
            }
            ForEach(0..<16, id: \.self) { step in
                base.foregroundStyle(stroke).offset(offset(step, radius: width, shift: 0))
            }
            base.foregroundStyle(fill)
        }
        .drawingGroup()
    }

    private func offset(_ step: Int, radius: CGFloat, shift: CGFloat) -> CGSize {
        let angle = Double(step) / 16 * 2 * .pi
        return CGSize(width: cos(angle) * radius + shift, height: sin(angle) * radius + shift)
    }
}

struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.32
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Ribbon: View {
    let text: String
    var size: CGFloat = 22

    var body: some View {
        Text(text.uppercased())
            .font(Theme.display(size))
            .tracking(size / 7)
            .foregroundStyle(Theme.navy)
            .padding(.leading, size * 0.8)
            .padding(.trailing, size * 1.6)
            .padding(.vertical, size * 0.3)
            .background {
                ZStack {
                    RibbonShape().fill(Theme.teal).offset(x: 5, y: 5)
                    RibbonShape().fill(Theme.paper)
                    RibbonShape().stroke(Theme.navy, lineWidth: 3)
                }
            }
    }
}

struct CardFan: View {
    var cardSize = CGSize(width: 34, height: 52)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(Array(Theme.fan.enumerated()), id: \.offset) { index, color in
                RoundedRectangle(cornerRadius: cardSize.width * 0.18)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: cardSize.width * 0.18).stroke(Theme.navy, lineWidth: 2.5))
                    .frame(width: cardSize.width, height: cardSize.height)
                    .rotationEffect(.degrees(-75 + Double(index) * 20), anchor: .bottom)
            }
        }
        .frame(width: cardSize.height * 2, height: cardSize.height * 1.1, alignment: .bottom)
    }
}

struct Flip7Logo: View {
    var size: CGFloat = 60

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: size * 0.05) {
            OutlinedText(text: "FLIP", size: size)
            OutlinedText(text: "7", size: size * 1.45)
        }
        .rotationEffect(.degrees(-6))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Theme.yellow
    var size: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButton(label: configuration.label, isPressed: configuration.isPressed, fill: fill, size: size)
    }
}

private struct ChunkyButton<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let fill: Color
    let size: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    private var lift: CGFloat { isPressed ? 3 : (hovering && isEnabled ? -2 : 0) }

    var body: some View {
        label
            .font(Theme.display(size))
            .tracking(1.2)
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, size * 1.1)
            .padding(.vertical, size * 0.5)
            .background {
                RoundedRectangle(cornerRadius: 12).fill(Theme.navy).offset(y: 4)
                RoundedRectangle(cornerRadius: 12).fill(fill)
                    .brightness(hovering && isEnabled ? 0.04 : 0)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.navy, lineWidth: 2.5))
                    .offset(y: lift)
            }
            .offset(y: lift)
            .onHover { hovering = $0 }
            .pointerStyle(isEnabled ? .link : nil)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: lift)
    }
}

struct HoverLift: ViewModifier {
    var scale: CGFloat = 1.06
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .onHover { hovering = $0 }
            .pointerStyle(.link)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: hovering)
    }
}

extension View {
    func hoverLift(_ scale: CGFloat = 1.06) -> some View {
        modifier(HoverLift(scale: scale))
    }
}

struct Panel<Content: View>: View {
    var fill: Color = Theme.paper
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Theme.panelInset)
            .background {
                RoundedRectangle(cornerRadius: 18).fill(Theme.navy).offset(x: 4, y: 5)
                RoundedRectangle(cornerRadius: 18).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.navy, lineWidth: 2.5))
            }
    }
}

struct Avatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(Theme.display(size * 0.55))
            .foregroundStyle(Theme.navy)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
            .overlay(Circle().stroke(Theme.navy, lineWidth: max(2, size / 16)))
    }
}

struct SpeckleBackground: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 7)
            for _ in 0..<Int(size.width * size.height / 900) {
                let point = CGPoint(x: .random(in: 0...size.width, using: &generator), y: .random(in: 0...size.height, using: &generator))
                context.fill(Path(ellipseIn: CGRect(origin: point, size: CGSize(width: 2, height: 2))), with: .color(Theme.teal.opacity(0.18)))
            }
        }
        .background(Theme.cream)
        .ignoresSafeArea()
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

struct Pill: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2, style: .circular)
    }

    func inset(by amount: CGFloat) -> Pill {
        Pill(inset: inset + amount)
    }
}

/// Gleich breite Spalten, damit Spielstand-Karten und Tabellenspalten exakt übereinander liegen.
struct Columns: Layout {
    static let spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max().map { $0 * CGFloat(subviews.count) + gaps(subviews) } ?? 0
        let column = columnWidth(width, subviews)
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let column = columnWidth(bounds.width, subviews)
        for index in subviews.indices {
            let x = bounds.minX + CGFloat(index) * (column + Self.spacing)
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: column, height: bounds.height))
        }
    }

    private func gaps(_ subviews: Subviews) -> CGFloat {
        CGFloat(max(subviews.count - 1, 0)) * Self.spacing
    }

    private func columnWidth(_ width: CGFloat, _ subviews: Subviews) -> CGFloat {
        subviews.isEmpty ? 0 : max((width - gaps(subviews)) / CGFloat(subviews.count), 0)
    }
}

struct MenuRow: View {
    let title: String
    let detail: String
    let symbol: String
    var tint: Color = Theme.navy
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.rounded(14, .heavy)).foregroundStyle(tint)
                    Text(detail).font(Theme.rounded(11, .medium)).foregroundStyle(Theme.navy.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.yellow.opacity(hovering ? 0.4 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct MenuPopover<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
        .padding(8)
        .frame(width: 260)
        .presentationBackground(Theme.paper)
    }
}

struct Confirmation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirm: String
    var tint: Color = Theme.coral
    let action: () -> Void
}

private struct ThemedConfirmation: ViewModifier {
    @Binding var confirmation: Confirmation?

    func body(content: Content) -> some View {
        content.overlay {
            if let confirmation {
                ZStack {
                    Theme.navy.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { self.confirmation = nil }
                    Panel {
                        VStack(spacing: 14) {
                            Text(confirmation.title)
                                .font(Theme.display(24))
                                .foregroundStyle(Theme.navy)
                                .multilineTextAlignment(.center)
                            Text(confirmation.message)
                                .font(Theme.rounded(14, .medium))
                                .foregroundStyle(Theme.navy.opacity(0.7))
                                .multilineTextAlignment(.center)
                            HStack(spacing: 12) {
                                Button("Zurück") { self.confirmation = nil }
                                    .buttonStyle(ChunkyButtonStyle(fill: Theme.paper, size: 16))
                                    .keyboardShortcut(.cancelAction)
                                Button(confirmation.confirm) {
                                    self.confirmation = nil
                                    confirmation.action()
                                }
                                .buttonStyle(ChunkyButtonStyle(fill: confirmation.tint, size: 16))
                            }
                            .padding(.top, 4)
                        }
                        .padding(8)
                    }
                    .frame(maxWidth: 440)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: confirmation?.id)
    }
}

extension View {
    func themedConfirmation(_ confirmation: Binding<Confirmation?>) -> some View {
        modifier(ThemedConfirmation(confirmation: confirmation))
    }
}
