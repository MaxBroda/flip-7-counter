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
        @Bindable var preferences = model.preferences
        Form {
            Section("Sprache") {
                LabeledContent("Sprechtaste (halten)") {
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
                    .frame(minWidth: 120)
                }
                Text("Wirkt, solange das Flip-7-Fenster vorne ist. Erkennung läuft lokal auf dem Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Namen") {
                ForEach(preferences.names, id: \.self) { name in
                    LabeledContent(name.value) {
                        Button("Entfernen", systemImage: "minus.circle.fill") { model.removeName(name) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField("Name", text: $newName, prompt: Text("z. B. Pratiksha, Omar"))
                        .onSubmit(addName)
                    Button("Hinzufügen", action: addName)
                        .disabled(PlayerName(newName) == nil)
                }
                Text("Die Spracherkennung achtet auf diese Namen. Nötig vor allem für Namen, die sie sonst falsch schreibt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Spiel") {
                LabeledContent("Siegpunktzahl") {
                    HStack {
                        TextField("", value: $preferences.targetScore, format: .number)
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $preferences.targetScore, in: Preferences.targetRange, step: 10)
                            .labelsHidden()
                    }
                }
                Text("Gilt ab dem nächsten neuen Spiel.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Spielerei") {
                Toggle("Sounds", isOn: $preferences.soundsEnabled)
                Toggle("Karten-Animation beim Start", isOn: $preferences.showsIntro)
            }
            Section("Geteilte Historie") {
                if let config = preferences.sharedHistory {
                    LabeledContent("Supabase") {
                        Button("Trennen") {
                            sharedURL = config.url.absoluteString
                            sharedKey = config.key
                            model.disconnectSharedHistory()
                        }
                    }
                    Text(config.url.host() ?? config.url.absoluteString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(statusText).font(.caption).foregroundStyle(statusIsError ? .red : .secondary)
                        Spacer()
                        Button("Jetzt abgleichen", action: model.synchronize)
                            .controlSize(.small)
                            .disabled(model.sharing.status == .syncing)
                    }
                } else {
                    TextField("Project URL", text: $sharedURL, prompt: Text("https://….supabase.co"))
                    TextField("Publishable / anon key", text: $sharedKey)
                        .font(.body.monospaced())
                    HStack {
                        if rejectsInput {
                            Text("URL muss mit https:// beginnen, Key darf nicht leer sein.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                        Button("Verbinden") {
                            rejectsInput = !model.connectSharedHistory(url: sharedURL, key: sharedKey)
                        }
                        .disabled(sharedURL.isEmpty || sharedKey.isEmpty)
                    }
                    Text("Alle Macs mit derselben Verbindung teilen Spiele und Rangliste. Laufende Partien bleiben lokal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Daten") {
                LabeledContent("Abgeschlossene Spiele: \(model.library.finished.count)") {
                    Button("Historie löschen …", role: .destructive) { confirmsClear = true }
                        .disabled(model.sharing.isConnected || model.library.finished.isEmpty && model.library.resets.isEmpty)
                }
                if model.sharing.isConnected {
                    Text("Bei geteilter Historie gesperrt. Einzelne Spiele lassen sich in der Historie löschen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog("Gesamte Historie löschen?", isPresented: $confirmsClear) {
            Button("Alles löschen", role: .destructive, action: model.clearHistory)
        } message: {
            Text("Alle abgeschlossenen Spiele und die Rangliste werden gelöscht. Ein laufendes Spiel bleibt erhalten.")
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear {
            model.cancelKeyCapture()
            preferences.targetScore = min(max(preferences.targetScore, Preferences.targetRange.lowerBound), Preferences.targetRange.upperBound)
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
