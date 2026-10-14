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
        configuration.label
            .font(Theme.display(size))
            .tracking(1.2)
            .foregroundStyle(Theme.navy)
            .padding(.horizontal, size * 1.1)
            .padding(.vertical, size * 0.5)
            .background {
                RoundedRectangle(cornerRadius: 12).fill(Theme.navy).offset(y: configuration.isPressed ? 1 : 4)
                RoundedRectangle(cornerRadius: 12).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.navy, lineWidth: 2.5))
                    .offset(y: configuration.isPressed ? 3 : 0)
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

struct Panel<Content: View>: View {
    var fill: Color = Theme.paper
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
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
