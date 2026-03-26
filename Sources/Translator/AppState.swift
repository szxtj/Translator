import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let viewModel: TranslatorViewModel

    private let panelController: PanelController
    private let shortcutManager: ShortcutManager

    init(service: TranslationServiceProtocol = TranslationService()) {
        self.viewModel = TranslatorViewModel(service: service)
        self.panelController = PanelController(viewModel: viewModel)
        self.shortcutManager = ShortcutManager()

        shortcutManager.registerToggleHandler { [weak self] in
            self?.togglePanel()
        }
    }

    func openPanel() {
        panelController.show()
    }

    func togglePanel() {
        panelController.toggle()
    }

    func copyResult() {
        viewModel.copyResult()
    }
}
