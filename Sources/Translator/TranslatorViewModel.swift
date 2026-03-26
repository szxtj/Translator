import AppKit
import Foundation

@MainActor
final class TranslatorViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var isLoading = false
    @Published var selectedMode: TranslationMode = .auto
    @Published var errorMessage: String?
    @Published private(set) var focusToken = 0

    private let service: TranslationServiceProtocol

    init(service: TranslationServiceProtocol) {
        self.service = service
    }

    func submit() {
        Task {
            await performTranslation()
        }
    }

    func performTranslation() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            outputText = try await service.translate(text: trimmedInput, mode: selectedMode)
        } catch {
            outputText = ""
            errorMessage = Self.message(for: error)
        }

        isLoading = false
    }

    func requestFocus() {
        focusToken += 1
    }

    func copyResult() {
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmedOutput, forType: .string)
    }

    private static func message(for error: Error) -> String {
        if let translationError = error as? TranslationServiceError {
            return translationError.errorDescription ?? "Translation failed."
        }

        return error.localizedDescription
    }
}
