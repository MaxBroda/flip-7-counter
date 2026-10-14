import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var recording = false
    @State private var confirmsClear = false

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
            Section("Daten") {
                LabeledContent("Abgeschlossene Spiele: \(model.library.finished.count)") {
                    Button("Historie löschen …", role: .destructive) { confirmsClear = true }
                        .disabled(model.library.finished.isEmpty && model.library.resets.isEmpty)
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
}
