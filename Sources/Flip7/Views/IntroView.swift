import SwiftUI

struct IntroView: View {
    let target: Int
    let onFinish: () -> Void

    @State private var angle = 0.0
    @State private var scale = 0.3
    @State private var tagline = false

    var body: some View {
        ZStack {
            SpeckleBackground()
            VStack(spacing: 34) {
                FlippingCard(angle: angle, target: target)
                    .frame(width: 250, height: 350)
                    .scaleEffect(scale)
                Ribbon(text: "Wer knackt die \(target)?", size: 20)
                    .opacity(tagline ? 1 : 0)
                    .offset(y: tagline ? 0 : 20)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .task {
            withAnimation(.spring(duration: 0.7, bounce: 0.45)) { scale = 1 }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeInOut(duration: 1.1)) { angle = 540 }
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { tagline = true }
            try? await Task.sleep(for: .seconds(1.3))
            onFinish()
        }
    }
}

struct FlippingCard: View, Animatable {
    var angle: Double
    let target: Int

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var showsFront: Bool {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        return normalized >= 90 && normalized < 270
    }

    var body: some View {
        ZStack {
            if showsFront {
                CardFace().rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                CardBack()
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}

private struct CardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Theme.teal)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.yellow, lineWidth: 5)
                    .padding(14)
            }
            .overlay {
                VStack(spacing: 18) {
                    CardFan(cardSize: CGSize(width: 40, height: 62))
                    OutlinedText(text: "FLIP 7", size: 30)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.navy, lineWidth: 5))
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.navy).offset(x: 6, y: 8))
    }
}

private struct CardFace: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Theme.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.mint, lineWidth: 4)
                    .padding(12)
            }
            .overlay {
                VStack(spacing: 6) {
                    CardFan(cardSize: CGSize(width: 26, height: 40))
                    Flip7Logo(size: 54)
                }
                .offset(y: -6)
            }
            .overlay(alignment: .topLeading) { corner }
            .overlay(alignment: .bottomTrailing) { corner.rotationEffect(.degrees(180)) }
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.navy, lineWidth: 5))
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.navy).offset(x: 6, y: 8))
    }

    private var corner: some View {
        OutlinedText(text: "7", size: 26, fill: Theme.coral, stroke: Theme.paper)
            .padding(22)
    }
}
