import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showsIntro: Bool

    init(showsIntro: Bool) {
        _showsIntro = State(initialValue: showsIntro)
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            SpeckleBackground()
            VStack(spacing: 0) {
                TopBar()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if model.isCelebrating, let game = model.game, game.isFinished {
                VictoryView(game: game)
                    .transition(.opacity)
            }
            if showsIntro {
                IntroView(target: model.preferences.targetScore) {
                    withAnimation(.easeOut(duration: 0.45)) { showsIntro = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.isCelebrating)
        .task(id: showsIntro) {
            if !showsIntro { await model.prepareSpeech() }
        }
        .frame(minWidth: 900, minHeight: 640)
        .alert("Hoppla", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK") { model.alert = nil }
        } message: {
            Text(model.alert ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.screen {
        case .play:
            if let game = model.game {
                GameView(game: game)
            } else {
                NewGameView()
            }
        case .history:
            HistoryView()
        }
    }
}

private struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 4) {
                CardFan(cardSize: CGSize(width: 16, height: 25))
                Flip7Logo(size: 26)
            }
            Spacer()
            tab("Spiel", systemImage: "suit.spade.fill", screen: .play)
            tab("Historie", systemImage: "trophy.fill", screen: .history)
            SettingsLink {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.navy)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Theme.mint.opacity(0.55))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.navy).frame(height: 3) }
    }

    private func tab(_ title: String, systemImage: String, screen: AppModel.Screen) -> some View {
        let active = model.screen == screen
        return Button {
            withAnimation(.spring(duration: 0.3)) { model.screen = screen }
        } label: {
            Label(title, systemImage: systemImage)
                .font(Theme.display(17))
                .tracking(1)
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Pill().fill(active ? Theme.yellow : .clear))
                .overlay(Pill().strokeBorder(Theme.navy, lineWidth: active ? 2.5 : 0))
        }
        .buttonStyle(.plain)
    }
}
