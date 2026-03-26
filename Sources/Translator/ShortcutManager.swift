@preconcurrency import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let toggleTranslatorWindow = Self(
        "toggleTranslatorWindow",
        default: .init(.space, modifiers: [.control])
    )
}

@MainActor
final class ShortcutManager {
    private let preferredShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.control])
    private let legacyShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])

    init() {
        migrateLegacyShortcutIfNeeded()
    }

    func registerToggleHandler(_ handler: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .toggleTranslatorWindow) {
            handler()
        }
    }

    private func migrateLegacyShortcutIfNeeded() {
        let currentShortcut = KeyboardShortcuts.getShortcut(for: .toggleTranslatorWindow)

        if currentShortcut == nil || currentShortcut == legacyShortcut {
            KeyboardShortcuts.setShortcut(preferredShortcut, for: .toggleTranslatorWindow)
        }
    }
}
