import AppKit
import SwiftUI

struct InputTextView: NSViewRepresentable {
    @Binding var text: String

    let focusToken: Int
    let isEditable: Bool
    let onSubmit: () -> Void
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = TranslatorNSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.string = text
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.allowsUndo = true
        textView.onSubmit = onSubmit
        textView.onEscape = onEscape

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.isEditable = isEditable
        textView.onSubmit = onSubmit
        textView.onEscape = onEscape

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InputTextView
        weak var textView: TranslatorNSTextView?
        var lastFocusToken: Int = -1

        init(_ parent: InputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            parent.text = textView?.string ?? ""
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []

            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                if modifiers.contains(.command) {
                    textView.insertNewline(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            case #selector(NSResponder.insertLineBreak(_:)),
                 #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                textView.insertNewline(nil)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            default:
                return false
            }
        }
    }
}

final class TranslatorNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers.contains(.shift), event.keyCode == 36 {
            insertText("\n", replacementRange: selectedRange())
            return
        }

        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
