import AppKit
import SwiftUI

@MainActor
@available(macOS 26.4, *)
final class SubtitlePanelController {
    private var panel: NSPanel?
    private let manager: SubtitleManager
    private var hasExpanded = false

    init(manager: SubtitleManager) {
        self.manager = manager
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        hasExpanded = false
        panel = nil // Destroy panel reference to recreate it in the default small state next time
    }

    func expandWindow() {
        guard !hasExpanded, let panel = panel else { return }
        hasExpanded = true
        
        debugLog("[SubtitlePanelController] Active speech detected. Expanding window...")
        
        // Attempt to restore user's saved window position & size from UserDefaults
        if panel.setFrameUsingName("SubtitlePanelV3") {
            debugLog("[SubtitlePanelController] Restored user's customized window frame successfully.")
        } else {
            // Default expanded dimensions: 950x160 centered horizontally
            if let screenFrame = NSScreen.main?.visibleFrame {
                let newWidth: CGFloat = 950
                let newHeight: CGFloat = 160
                let x = screenFrame.midX - (newWidth / 2)
                let y = screenFrame.minY + 80
                
                let newFrame = NSRect(x: x, y: y, width: newWidth, height: newHeight)
                panel.setFrame(newFrame, display: true, animate: true)
            }
        }
        
        // Bind frame auto-save to native UserDefaults from now on
        panel.setFrameAutosaveName("SubtitlePanelV3")
    }

    private func makePanel() -> NSPanel {
        // Initial "waiting" size: compact 320x60 centered horizontally, slightly lower
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        // Hide standard window decorations
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Drag & Resize parameters
        panel.ignoresMouseEvents = false 
        panel.isMovableByWindowBackground = true 
        panel.minSize = NSSize(width: 400, height: 80) // Minimum resize dimensions when expanded

        // Position small widget horizontally centered, near bottom
        if let screenFrame = NSScreen.main?.visibleFrame {
            let x = screenFrame.midX - 160
            let y = screenFrame.minY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Use NSHostingView inside a custom NSView container rather than contentViewController.
        // This isolates SwiftUI preferred sizing constraints from the AppKit window frame layout engine.
        let hostingView = NSHostingView(rootView: SubtitleView(manager: manager))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let contentView = NSView()
        contentView.addSubview(hostingView)
        panel.contentView = contentView
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        return panel
    }
}
