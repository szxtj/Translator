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

    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        center(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        focusInput()
    }

    func hide() {
        panel?.orderOut(nil)
        viewModel.stopSpeech()
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
            onPreferredHeightChange: { [weak self, weak panel] height in
                guard let self, let panel else { return }
                let targetHeight = max(Layout.minHeight, height)
                if abs(panel.frame.height - targetHeight) > 0.5 {
                    self.resize(panel, toHeight: targetHeight)
                }
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        panel.contentViewController = NSHostingController(rootView: rootView)
        return panel
    }

    private func resize(_ panel: NSPanel, toHeight targetHeight: CGFloat) {
        let currentFrame = panel.frame
        let heightDiff = targetHeight - currentFrame.height
        let newOrigin = NSPoint(x: currentFrame.origin.x, y: currentFrame.origin.y - heightDiff)
        let newFrame = NSRect(origin: newOrigin, size: NSSize(width: currentFrame.width, height: targetHeight))
        panel.setFrame(newFrame, display: true, animate: false)
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
