import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private enum Layout {
        static let width: CGFloat = 620
        static let minHeight: CGFloat = 290
    }

    private let viewModel: TranslatorViewModel
    private var panel: SpotlightPanel?
    private var shouldCenterAfterNextResize = false

    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        shouldCenterAfterNextResize = true

        center(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        focusInput()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        guard let panel else {
            show()
            return
        }

        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func focusInput() {
        viewModel.requestFocus()
    }

    private func makePanel() -> SpotlightPanel {
        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.width, height: Layout.minHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.onEscape = { [weak self] in
            self?.hide()
        }

        let rootView = MainView(
            viewModel: viewModel,
            onPreferredHeightChange: { [weak panel] height in
                let targetHeight = max(Layout.minHeight, height)
                panel?.setContentSize(NSSize(width: Layout.width, height: targetHeight))
                if let panel, self.shouldCenterAfterNextResize {
                    self.center(panel)
                    self.shouldCenterAfterNextResize = false
                }
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        panel.contentViewController = NSHostingController(rootView: rootView)
        return panel
    }

    private func center(_ panel: NSPanel) {
        if let screenFrame = NSScreen.main?.visibleFrame ?? panel.screen?.visibleFrame {
            let origin = NSPoint(
                x: screenFrame.midX - panel.frame.width / 2,
                y: screenFrame.midY - panel.frame.height / 2
            )
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }
    }
}

final class SpotlightPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
