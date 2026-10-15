import Flip7Core
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var recording = false
    @State private var confirmsClear = false
    @State private var sharedURL = ""
    @State private var sharedKey = ""
    @State private var rejectsInput = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Ribbon(text: "Einstellungen")
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        GroupLabel("Spiel")
                        speech
                        RowDivider()
                        game
                        RowDivider()
                        GroupLabel("Namen")
                        names
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        GroupLabel("Geteilte Historie")
                        sharing
                        RowDivider()
                        data
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Gesamte Historie löschen?", isPresented: $confirmsClear) {
            Button("Alles löschen", role: .destructive, action: model.clearHistory)
        } message: {
            Text("Alle abgeschlossenen Spiele und die Rangliste werden gelöscht. Ein laufendes Spiel bleibt erhalten.")
        }
        .onDisappear {
            recording = false
            model.cancelKeyCapture()
            let preferences = model.preferences
            preferences.targetScore = min(max(preferences.targetScore, Preferences.targetRange.lowerBound), Preferences.targetRange.upperBound)
        }
    }

    private var speech: some View {
        let preferences = model.preferences
        return SettingRow("Sprechtaste (halten)", caption: "Wirkt, solange das Flip-7-Fenster vorne ist. Erkennung läuft lokal auf dem Mac.") {
            Button(recording ? "Taste drücken …" : preferences.hotkey.label) {
                recording.toggle()
                if recording {
                    model.captureNextKey { hotkey in
                        preferences.hotkey = hotkey
                        recording = false
                    }
                } else {
                    model.cancelKeyCapture()
                }
            }
            .buttonStyle(ChunkyButtonStyle(fill: recording ? Theme.coral : Theme.yellow, size: 14))
        }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Die Spracherkennung achtet auf diese Namen. Nötig vor allem für Namen, die sie sonst falsch schreibt.")
                .settingCaption()
            if !model.preferences.names.isEmpty {
                FlowLayout(spacing: 10) {
                    ForEach(Array(model.preferences.names.enumerated()), id: \.element) { index, name in
                        PlayerChip(name: name.value, color: Theme.color(forPlayerAt: index)) {
                            withAnimation(.spring) { model.removeName(name) }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring, value: model.preferences.names)
            }
            HStack {
                ThemedField(placeholder: "z. B. Pratiksha, Omar", text: $newName, onSubmit: addName)
                Button("Hinzufügen", action: addName)
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 14))
                    .disabled(PlayerName(newName) == nil)
            }
        }
    }

    private var game: some View {
        @Bindable var preferences = model.preferences
        return VStack(alignment: .leading, spacing: 14) {
            SettingRow("Siegpunktzahl", caption: "Gilt ab dem nächsten neuen Spiel.") {
                HStack(spacing: 6) {
                    TextField("", value: $preferences.targetScore, format: .number)
                        .textFieldStyle(.plain)
                        .font(Theme.display(22))
                        .foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.navy.opacity(0.4), lineWidth: 2))
                    Stepper("", value: $preferences.targetScore, in: Preferences.targetRange, step: 10)
                        .labelsHidden()
                }
            }
            RowDivider()
            SettingRow("Sounds") {
                Toggle("", isOn: $preferences.soundsEnabled).themedSwitch()
            }
            RowDivider()
            SettingRow("Karten-Animation beim Start") {
                Toggle("", isOn: $preferences.showsIntro).themedSwitch()
            }
        }
    }

    @ViewBuilder
    private var sharing: some View {
        if let config = model.preferences.sharedHistory {
            VStack(alignment: .leading, spacing: 14) {
                SettingRow("Supabase", caption: config.url.host() ?? config.url.absoluteString) {
                    Button("Trennen") {
                        sharedURL = config.url.absoluteString
                        sharedKey = config.key
                        model.disconnectSharedHistory()
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.paper, size: 14))
                }
                RowDivider()
                HStack {
                    Text(statusText)
                        .font(Theme.rounded(13, .semibold))
                        .foregroundStyle(statusIsError ? Theme.coral : Theme.navy.opacity(0.6))
                    Spacer()
                    Button("Jetzt abgleichen", action: model.synchronize)
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 14))
                        .disabled(model.sharing.status == .syncing)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Alle Macs mit derselben Verbindung teilen Spiele und Rangliste. Laufende Partien bleiben lokal.")
                    .settingCaption()
                ThemedField(placeholder: "Project URL – https://….supabase.co", text: $sharedURL)
                ThemedField(placeholder: "Publishable / anon key", text: $sharedKey, monospaced: true)
                HStack {
                    if rejectsInput {
                        Text("URL muss mit https:// beginnen, Key darf nicht leer sein.")
                            .font(Theme.rounded(12, .semibold))
                            .foregroundStyle(Theme.coral)
                    }
                    Spacer()
                    Button("Verbinden") {
                        rejectsInput = !model.connectSharedHistory(url: sharedURL, key: sharedKey)
                    }
                    .buttonStyle(ChunkyButtonStyle(size: 14))
                    .disabled(sharedURL.isEmpty || sharedKey.isEmpty)
                }
            }
        }
    }

    private var data: some View {
        SettingRow(
            "Abgeschlossene Spiele: \(model.library.finished.count)",
            caption: model.sharing.isConnected ? "Bei geteilter Historie gesperrt. Einzelne Spiele lassen sich in der Historie löschen." : nil
        ) {
            Button("Historie löschen …") { confirmsClear = true }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.coral, size: 14))
                .disabled(model.sharing.isConnected || model.library.finished.isEmpty && model.library.resets.isEmpty)
        }
    }

    private func addName() {
        model.addName(newName)
        newName = ""
    }

    private var statusText: String {
        switch model.sharing.status {
        case .off: "Noch nicht abgeglichen"
        case .syncing: "Gleiche ab …"
        case .synced(let date): "Abgeglichen um \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message): message
        }
    }

    private var statusIsError: Bool {
        if case .failed = model.sharing.status { true } else { false }
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    let caption: String?
    @ViewBuilder let control: Control

    init(_ title: String, caption: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.caption = caption
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.rounded(16, .heavy)).foregroundStyle(Theme.navy)
                if let caption { Text(caption).settingCaption() }
            }
            Spacer(minLength: 12)
            control
        }
    }
}

private struct GroupLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.rounded(12, .heavy))
            .tracking(1)
            .foregroundStyle(Theme.navy.opacity(0.5))
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.navy.opacity(0.12)).frame(height: 2)
    }
}

private struct ThemedField: View {
    let placeholder: String
    @Binding var text: String
    var monospaced = false
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(monospaced ? .system(size: 14, weight: .medium, design: .monospaced) : Theme.rounded(16, .semibold))
            .foregroundStyle(Theme.navy)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.navy.opacity(focused ? 1 : 0.4), lineWidth: 2))
    }
}

private extension View {
    func settingCaption() -> some View {
        font(Theme.rounded(12, .medium))
            .foregroundStyle(Theme.navy.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    func themedSwitch() -> some View {
        toggleStyle(.switch).tint(Theme.teal).labelsHidden()
    }
}
