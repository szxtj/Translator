import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    let onPreferredHeightChange: (CGFloat) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")

                Spacer()
            }

            Picker("Mode", selection: $viewModel.selectedMode) {
                ForEach(TranslationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            InputTextView(
                text: $viewModel.inputText,
                focusToken: viewModel.focusToken,
                isEditable: !viewModel.isLoading,
                onSubmit: {
                    viewModel.submit()
                },
                onEscape: onClose
            )
            .frame(height: inputHeight)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Translation")
                        .font(.headline)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ScrollView {
                    Text(viewModel.outputText.isEmpty ? "Translation result will appear here." : viewModel.outputText)
                        .foregroundStyle(viewModel.outputText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: resultHeight)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Enter to translate, Shift+Enter for newline, Esc to close.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Copy") {
                    viewModel.copyResult()
                }
                .keyboardShortcut("c")
                .disabled(viewModel.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 620)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .onAppear {
            reportPreferredHeight()
        }
        .onChange(of: viewModel.inputText) { _ in
            reportPreferredHeight()
        }
        .onChange(of: viewModel.outputText) { _ in
            reportPreferredHeight()
        }
        .onChange(of: viewModel.errorMessage) { _ in
            reportPreferredHeight()
        }
    }

    private var inputHeight: CGFloat {
        estimatedHeight(for: viewModel.inputText, min: 92, max: 180)
    }

    private var resultHeight: CGFloat {
        estimatedHeight(
            for: viewModel.outputText.isEmpty ? "Translation result will appear here." : viewModel.outputText,
            min: 84,
            max: 220
        )
    }

    private func estimatedHeight(for text: String, min minHeight: CGFloat, max maxHeight: CGFloat) -> CGFloat {
        let lineBreakCount = text.reduce(into: 1) { partialResult, character in
            if character == "\n" {
                partialResult += 1
            }
        }
        let wrappedLineEstimate = Swift.max(1, Int(ceil(Double(text.count) / 34.0)))
        let lineCount = Swift.max(lineBreakCount, wrappedLineEstimate)
        let contentHeight = CGFloat(lineCount) * 22 + 28
        return Swift.min(maxHeight, Swift.max(minHeight, contentHeight))
    }

    private func reportPreferredHeight() {
        let totalHeight = inputHeight + resultHeight + 122 + (viewModel.errorMessage == nil ? 0 : 22)
        onPreferredHeightChange(totalHeight)
    }
}
