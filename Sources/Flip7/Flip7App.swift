import AppKit
import Flip7Core
import SwiftUI

@main
struct Flip7App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(
        store: .applicationSupport("library.json"),
        sharing: HistorySync(outboxStore: .applicationSupport("outbox.json")),
        preferences: Preferences(),
        speech: SpeechRecorder()
    )

    var body: some Scene {
        Window("Flip 7", id: "main") {
            RootView(showsIntro: model.preferences.showsIntro)
                .environment(model)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neues Spiel") {
                    model.closeGame()
                    model.screen = .play
                }
                .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
