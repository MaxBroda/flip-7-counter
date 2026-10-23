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
            if let moment = model.flipMoment {
                FlipSevenView(moment: moment, onFinish: model.endFlipMoment)
                    .id(moment.id)
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
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
        .animation(.easeInOut(duration: 0.3), value: model.flipMoment?.id)
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
        case .settings:
            SettingsView()
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
            SpaceToggle()
            Spacer()
            tab("Spiel", systemImage: "suit.spade.fill", screen: .play)
            tab("Historie", systemImage: "trophy.fill", screen: .history)
            tab("Einstellungen", systemImage: "gearshape.fill", screen: .settings)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Theme.mint.opacity(0.55))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.navy).frame(height: 3) }
    }

    private func tab(_ title: String, systemImage: String, screen: AppModel.Screen) -> some View {
        TabButton(title: title, systemImage: systemImage, isActive: model.screen == screen) {
            withAnimation(.spring(duration: 0.3)) { model.screen = screen }
        }
    }
}

private struct SpaceToggle: View {
    @Environment(AppModel.self) private var model
    @Namespace private var knob

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HistorySpace.allCases, id: \.self) { space in
                segment(space)
            }
        }
        .padding(3)
        .background(Pill().fill(Theme.paper))
        .overlay(Pill().strokeBorder(Theme.navy, lineWidth: 2))
        .animation(.spring(duration: 0.35, bounce: 0.35), value: model.space)
        .help("Wo die Spiele zählen. Privat bleibt auf diesem Mac und geht nie an Supabase.")
    }

    private func segment(_ space: HistorySpace) -> some View {
        let isActive = model.space == space
        return Button {
            model.switchSpace(to: space)
        } label: {
            Label(space.title, systemImage: space.symbol)
                .font(Theme.rounded(13, .heavy))
                .foregroundStyle(isActive ? Theme.paper : Theme.navy)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background {
                    if isActive {
                        Pill().fill(Theme.navy).matchedGeometryEffect(id: "knob", in: knob)
                    }
                }
                .contentShape(Pill())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

private struct TabButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.display(17))
                .tracking(1)
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Pill().fill(isActive ? Theme.yellow : hovering ? Theme.yellow.opacity(0.45) : .clear))
                .overlay(Pill().strokeBorder(Theme.navy, lineWidth: isActive ? 2.5 : hovering ? 1.5 : 0))
                .contentShape(Pill())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .hoverLift(1.04)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
