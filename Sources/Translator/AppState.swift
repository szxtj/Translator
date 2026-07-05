import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    let viewModel: TranslatorViewModel
    private var cancellables = Set<AnyCancellable>()
    private var _subtitleManager: Any?

    @available(macOS 26.4, *)
    var subtitleManager: SubtitleManager {
        if _subtitleManager == nil {
            let manager = SubtitleManager()
            _subtitleManager = manager
            manager.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
        return _subtitleManager as! SubtitleManager
    }

    private let panelController: PanelController
    private let shortcutManager: ShortcutManager

    init(service: TranslationServiceProtocol = TranslationService()) {
        self.viewModel = TranslatorViewModel(service: service)
        self.panelController = PanelController(viewModel: viewModel)
        self.shortcutManager = ShortcutManager()

        shortcutManager.registerToggleHandler { [weak self] in
            self?.togglePanel()
        }

        if #available(macOS 26.4, *) {
            _ = subtitleManager
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
