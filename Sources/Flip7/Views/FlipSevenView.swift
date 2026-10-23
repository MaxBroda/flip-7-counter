import SwiftUI

struct FlipSevenView: View {
    let moment: FlipMoment
    let onFinish: () -> Void

    private static let numbers = [3, 12, 7, 1, 9, 5, 11]

    @State private var dealt = 0
    @State private var showsTitle = false

    var body: some View {
        ZStack {
            Theme.navy.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack(alignment: .bottom) {
                    ForEach(Array(Self.numbers.enumerated()), id: \.offset) { index, number in
                        NumberCard(number: number, color: Theme.fan[index])
                            .rotationEffect(.degrees(dealt > index ? -54 + Double(index) * 18 : 0), anchor: .bottom)
                            .offset(y: dealt > index ? 0 : 260)
                            .opacity(dealt > index ? 1 : 0)
                    }
                }
                .frame(height: 210, alignment: .bottom)
                VStack(spacing: 8) {
                    OutlinedText(text: "FLIP 7!", size: 76)
                        .scaleEffect(showsTitle ? 1 : 0.2)
                        .rotationEffect(.degrees(showsTitle ? -5 : -35))
                    Text("\(moment.names.formatted(.list(type: .and))) · +15 Bonus")
                        .font(Theme.rounded(20, .heavy))
                        .foregroundStyle(Theme.paper)
                }
                .opacity(showsTitle ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            for card in 1...Self.numbers.count {
                withAnimation(.spring(duration: 0.45, bounce: 0.35)) { dealt = card }
                try? await Task.sleep(for: .seconds(0.075))
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.55)) { showsTitle = true }
            try? await Task.sleep(for: .seconds(2.2))
            onFinish()
        }
    }
}

private struct NumberCard: View {
    let number: Int
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(color)
            .overlay {
                OutlinedText(text: "\(number)", size: 40, fill: Theme.paper, stroke: Theme.navy, outline: Theme.navy)
            }
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.navy, lineWidth: 4))
            .frame(width: 92, height: 136)
            .offset(y: -40)
    }
}
