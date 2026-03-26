import SwiftUI

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Translator", systemImage: "character.bubble") {
            Button("Open Translator") {
                appState.openPanel()
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("Copy Result") {
                    appState.copyResult()
                }
                .keyboardShortcut("c")
                .disabled(appState.viewModel.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
